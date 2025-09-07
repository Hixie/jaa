import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../widgets/widgets.dart';
import '../utils/colors.dart';
import '../utils/randomizer.dart';

enum FinalistKind { automatic, manual, override }

typedef AwardFinalistEntry = (
  /// The team with this entry.
  Team?,
  /// If the team was not assigned this award, this tells you the award that they _did_ get that is the reason why they didn't get this one.
  Award?,
  /// Rank that the team got for this award (or the other one if they didn't get this one).
  int, {
    /// Whether there are other teams who also have this rank for this award. (the $2 will always be null if this is true).
    bool tied,
    /// True if this was assigned by a human.
    FinalistKind kind,
  }
);

enum PitVisit { yes, no, maybe }

enum Show { all, ifNeeded, none }

enum SpreadTheWealth { allPlaces, winnerOnly, no }

enum AwardOrder { categories, rank }

bool? showToBool(Show value) {
  switch (value) {
    case Show.all:
      return true;
    case Show.ifNeeded:
      return null;
    case Show.none:
      return false;
  }
}

Show boolToShow(bool? value) {
  switch (value) {
    case true:
      return Show.all;
    case null:
      return Show.ifNeeded;
    case false:
      return Show.none;
  }
}

sealed class AutonominationRule {
  const AutonominationRule();

  static AutonominationRule? parseFromCSV(String rule) {
    if (rule == 'if last category') {
      return const AutonominateIfRemainingCategory();
    }
    return null;
  }

  bool shouldAutonominate(Team team, Award candidateAward, Iterable<Award> awards);

  String get name;

  String get description;

  String toCSV();
}

class AutonominateIfRemainingCategory extends AutonominationRule {
  const AutonominateIfRemainingCategory();

  @override
  bool shouldAutonominate(Team team, Award candidateAward, Iterable<Award> awards) {
    if (candidateAward.category == '') {
      return false;
    }
    if (candidateAward.needsPortfolio && !team.hasPortfolio) {
      return false;
    }
    final Set<String> allCategories = <String>{};
    final Set<String> nominatedCategories = <String>{};
    for (Award award in awards) {
      if (award.category != '') {
        allCategories.add(award.category);
        if (award != candidateAward && team.shortlistsView.containsKey(award)) {
          nominatedCategories.add(award.category);
        }
      }
    }
    if (!nominatedCategories.contains(candidateAward.category) && nominatedCategories.length == allCategories.length - 1) {
      return true;
    }
    return false;
  }

  @override
  String get name => 'Enabled'; // if we add other rules, change this name

  @override
  String get description => 'Teams will be autonominated to this award if they are nominated in every other category.';

  @override
  String toCSV() => 'if last category';
}

enum AwardKind { inspire, advancingInspire, advancingIndependent, nonAdvancing }

// change notifications are specifically for the color changing
class Award extends ChangeNotifier {
  Award({
    required this.name,
    required this.kind,
    required this.rank,
    required this.count,
    required this.category,
    required this.spreadTheWealth,
    required this.autonominationRule,
    required this.isPlacement,
    required this.needsPortfolio,
    required this.pitVisits,
    required this.isEventSpecific,
    required this.type,
    required Color color,
    required String comment,
    required this.competition,
  })  : _color = color,
        _comment = comment,
        assert(count > 0);

  final String name;
  final AwardKind kind;
  final int rank;
  final int count;
  final String category;
  final SpreadTheWealth spreadTheWealth;
  final AutonominationRule? autonominationRule;
  final bool isPlacement;
  final bool needsPortfolio;
  final PitVisit pitVisits;
  final bool isEventSpecific;
  final int type;
  final Competition competition;

  Color _color;
  Color get color => _color;

  void updateColor(Color color) {
    _color = color;
    notifyListeners();
  }

  String _comment;
  String get comment => _comment;

  void updateComment(String comment) {
    _comment = comment;
    notifyListeners();
  }

  bool get isInspire => kind == AwardKind.inspire;
  bool get isAdvancing => kind != AwardKind.nonAdvancing;

  String get description {
    StringBuffer buffer = StringBuffer();
    if (competition.applyFinalistsByAwardRanking && (spreadTheWealth != SpreadTheWealth.no)) {
      buffer.write('rank $rank ');
    }
    switch (kind) {
      case AwardKind.inspire:
        buffer.write('advancing award');
      case AwardKind.advancingInspire:
        buffer.write('advancing and Inspire-contributing award');
      case AwardKind.advancingIndependent:
        buffer.write('independent advancing award');
      case AwardKind.nonAdvancing:
        buffer.write('non-advancing award');
    }
    if (category.isNotEmpty) {
      buffer.write(' in the $category category');
    }
    if (needsPortfolio) {
      buffer.write(' that requires a portfolio');
    }
    return buffer.toString();
  }

  // predicate for List.where clauses
  static bool needsExtraPitVisitPredicate(Award award) {
    return award.pitVisits != PitVisit.yes && !award.isInspire;
  }

  // predicate for List.where clauses
  static bool isNotInspirePredicate(Award award) {
    return !award.isInspire;
  }

  // predicate for List.where clauses
  static bool isInspireQualifyingPredicate(Award award) {
    return !award.isInspire && award.isAdvancing;
  }

  static int categoryBasedComparator(Award a, Award b) {
    if (a.isInspire != b.isInspire) {
      return a.isInspire ? -1 : 1;
    }
    if (a.category != b.category) {
      if (a.category.isEmpty) {
        return 1;
      }
      if (b.category.isEmpty) {
        return -1;
      }
      return a.category.compareTo(b.category);
    }
    return a.rank.compareTo(b.rank);
  }

  static int rankBasedComparator(Award a, Award b) {
    return a.rank.compareTo(b.rank);
  }
}

// hidden is a substate of eligible
enum InspireStatus { eligible, ineligible, hidden, exhibition }

typedef TeamComparatorCallback = int Function(Team a, Team b);

class Team extends ChangeNotifier implements Comparable<Team> {
  Team({
    required int number,
    required String name,
    required String location,
    required bool hasPortfolio,
    required InspireStatus inspireStatus,
    int visited = 0,
  })  : _number = number,
        _name = name,
        _location = location,
        _hasPortfolio = hasPortfolio,
        _visited = visited,
        _inspireStatus = inspireStatus;

  int get number => _number;
  int _number;

  String get name => _name;
  String _name;

  String get location => _location;
  String _location;

  bool get hasPortfolio => _hasPortfolio;
  bool _hasPortfolio;

  late final UnmodifiableMapView<Award, ShortlistEntry> shortlistsView = UnmodifiableMapView(_shortlists);
  final Map<Award, ShortlistEntry> _shortlists = <Award, ShortlistEntry>{};

  late final Set<String> shortlistedAdvancingCategories = UnmodifiableSetView(_shortlistedAdvancingCategories);
  final Set<String> _shortlistedAdvancingCategories = <String>{};

  late final UnmodifiableMapView<Award, String> blurbsView = UnmodifiableMapView(_blurbs);
  final Map<Award, String> _blurbs = <Award, String>{};

  late final UnmodifiableMapView<Award, String> awardSubnamesView = UnmodifiableMapView(_awardSubnames);
  final Map<Award, String> _awardSubnames = <Award, String>{};

  // only meaningful when compared to teams with the same number of shortlistedAdvancingCategories
  int? get rankScore => _rankScore;
  int? _rankScore;

  int get rankedCount => _shortlists.values.where((ShortlistEntry entry) => entry.rank != null).length;

  InspireStatus get inspireStatus => _inspireStatus;
  InspireStatus _inspireStatus;

  int get visited => _visited;
  int _visited;

  String _visitingJudgesNotes = '';
  String get visitingJudgesNotes => _visitingJudgesNotes;
  set visitingJudgesNotes(String value) {
    if (value == _visitingJudgesNotes) {
      return;
    }
    _visitingJudgesNotes = value;
    notifyListeners();
  }

  @override
  int compareTo(Team other) {
    return number.compareTo(other.number);
  }

  void _addToShortlist(Award award, ShortlistEntry entry) {
    assert(!_shortlists.containsKey(award));
    _shortlists[award] = entry;
    entry.addListener(_recomputeShortlistedAdvancingCategories);
    _recomputeShortlistedAdvancingCategories();
    notifyListeners();
  }

  void _removeFromShortlist(Award award) {
    _shortlists[award]!.removeListener(_recomputeShortlistedAdvancingCategories);
    _shortlists.remove(award);
    _recomputeShortlistedAdvancingCategories();
    notifyListeners();
  }

  void _clearShortlists() {
    for (final ShortlistEntry entry in _shortlists.values) {
      entry.removeListener(_recomputeShortlistedAdvancingCategories);
    }
    _shortlists.clear();
    _shortlistedAdvancingCategories.clear();
    notifyListeners();
  }

  void _clearBlurbs() {
    _blurbs.clear();
    _awardSubnames.clear();
    notifyListeners();
  }

  void _recomputeShortlistedAdvancingCategories() {
    _shortlistedAdvancingCategories.clear();
    _rankScore = 0;
    for (final Award award in _shortlists.keys) {
      if (award.isAdvancing && !award.isInspire) {
        _shortlistedAdvancingCategories.add(award.category);
      }
    }
    for (String category in _shortlistedAdvancingCategories) {
      int? lowest = _bestRankFor(category);
      if (lowest == null) {
        _rankScore = null;
        return;
      }
      _rankScore = _rankScore! + lowest;
    }
  }

  int _countHyptheticalShortlistedAdvancingCategories({required Award without}) {
    Set<String> categories = {};
    for (final Award award in _shortlists.keys) {
      if (award != without && award.isAdvancing && !award.isInspire) {
        categories.add(award.category);
      }
    }
    return categories.length;
  }

  String bestRankFor(String category, String unrankedLabel, String unnominatedLabel) {
    if (!_shortlistedAdvancingCategories.contains(category)) {
      return unnominatedLabel;
    }
    return '${_bestRankFor(category) ?? unrankedLabel}';
  }

  int? _bestRankFor(String category) {
    int? result;
    for (final Award award in _shortlists.keys) {
      if (award.isAdvancing && !award.isInspire && award.category == category) {
        final int? candidate = _shortlists[award]!.rank;
        if (result == null || (candidate != null && candidate < result)) {
          result = candidate;
        }
      }
    }
    return result;
  }

  Iterable<Award> get shortlistedAwardsWithPitVisits => shortlistsView.keys.where((Award award) => award.pitVisits == PitVisit.yes);

  static int inspireCandidateComparator(Team a, Team b) {
    if (a.shortlistedAdvancingCategories.length != b.shortlistedAdvancingCategories.length) {
      return b.shortlistedAdvancingCategories.length - a.shortlistedAdvancingCategories.length;
    }
    if (a.rankScore == b.rankScore) {
      return a.number - b.number;
    }
    if (a.rankScore == null) {
      return 1;
    }
    if (b.rankScore == null) {
      return -1;
    }
    return a.rankScore! - b.rankScore!;
  }

  static int rankedCountComparator(Team a, Team b) {
    if (a.rankedCount == b.rankedCount) {
      return inspireCandidateComparator(a, b);
    }
    return b.rankedCount - a.rankedCount;
  }

  static int teamNumberComparator(Team a, Team b) {
    return a.number - b.number;
  }

  @override
  String toString() => '[$number $name]';
}

class ShortlistEntry extends ChangeNotifier {
  ShortlistEntry({
    String nominator = '',
    String comment = '',
    int? rank,
    required bool lateEntry,
  })  : _nominator = nominator,
        _comment = comment,
        _rank = rank,
        _lateEntry = lateEntry,
        _tied = false;

  String get nominator => _nominator;
  String _nominator;
  set nominator(String value) {
    if (_nominator != value) {
      _nominator = value;
      notifyListeners();
    }
  }

  String get comment => _comment;
  String _comment;
  set comment(String value) {
    if (_comment != value) {
      _comment = value;
      notifyListeners();
    }
  }

  int? get rank => _rank;
  int? _rank;
  // to update this use the Competition object

  bool get lateEntry => _lateEntry;
  bool _lateEntry;
  set lateEntry(bool value) {
    if (_lateEntry != value) {
      _lateEntry = value;
      notifyListeners();
    }
  }

  bool get tied => _tied;
  bool _tied;
  void _setTied(bool value) {
    if (_tied != value) {
      _tied = value;
      notifyListeners();
    }
  }
}

class Shortlist extends ChangeNotifier {
  final Map<Team, ShortlistEntry> _entries = <Team, ShortlistEntry>{};
  late final Map<Team, ShortlistEntry> entriesView = UnmodifiableMapView<Team, ShortlistEntry>(_entries);

  List<Set<Team>> asRankedList() {
    final List<Set<Team>> result = [];
    final Set<int> ranks = {};
    for (final ShortlistEntry entry in _entries.values) {
      if (entry.rank != null) {
        ranks.add(entry.rank!);
      }
    }
    final List<int> sortedRanks = ranks.toList()..sort();
    for (final int rank in sortedRanks) {
      Set<Team> teams = {};
      for (final Team team in _entries.keys) {
        if (_entries[team]!.rank == rank) {
          teams.add(team);
        }
      }
      result.add(teams);
    }
    return result;
  }

  void _clear() {
    _entries.clear();
  }

  void _add(Team team, ShortlistEntry entry) {
    assert(!_entries.containsKey(team));
    _entries[team] = entry;
    _checkForTies();
    notifyListeners();
  }

  void _remove(Team team) {
    assert(_entries.containsKey(team));
    _entries.remove(team);
    _checkForTies();
    notifyListeners();
  }

  bool _reentrant = false;
  void _checkForTies() {
    if (_reentrant) {
      return;
    }
    _reentrant = true;
    try {
      final Map<int?, bool> ranks = <int?, bool>{};
      for (final ShortlistEntry entry in _entries.values) {
        ranks[entry.rank] = ranks.containsKey(entry.rank);
      }
      for (final ShortlistEntry entry in _entries.values) {
        entry._setTied(ranks[entry.rank]!);
      }
    } finally {
      _reentrant = false;
    }
  }
}

class Competition extends ChangeNotifier {
  Competition({required this.autosaveDirectory, required this.exportDirectoryBuilder});

  final Directory autosaveDirectory;

  final ValueGetter<Future<Directory>> exportDirectoryBuilder;

  Future<Directory>? _exportDirectory;
  Future<Directory> get exportDirectory => _exportDirectory ?? exportDirectoryBuilder();

  final List<Team> _teams = <Team>[];
  final List<Award> _awards = <Award>[];
  final List<String> _categories = <String>[];
  final Map<Award, Shortlist> _shortlists = <Award, Shortlist>{};

  late final UnmodifiableListView<Team> teamsView = UnmodifiableListView<Team>(_teams);
  late final UnmodifiableListView<Award> awardsView = UnmodifiableListView<Award>(_awards);
  late final UnmodifiableMapView<Award, Shortlist> shortlistsView = UnmodifiableMapView<Award, Shortlist>(_shortlists);
  late final UnmodifiableListView<String> categories = UnmodifiableListView(_categories);

  int awardsWithKind(Set<AwardKind> kinds) {
    int count = 0;
    for (final Award award in _awards) {
      if (kinds.contains(award.kind)) {
        count += 1;
      }
    }
    return count;
  }

  final Map<Award, Map<int, Map<Team, FinalistKind>>> _overrides = {};

  String get eventName => _eventName;
  String _eventName = '';
  set eventName(String value) {
    if (value != _eventName) {
      _eventName = value;
      notifyListeners();
    }
  }

  int get expectedPitVisits => _expectedPitVisits;
  int _expectedPitVisits = 1;
  set expectedPitVisits(int value) {
    assert(value > 0);
    if (value != _expectedPitVisits) {
      _expectedPitVisits = value;
      notifyListeners();
    }
  }

  int get minimumInspireCategories {
    List<String> cachedCategories = categories;
    if (cachedCategories.isEmpty) {
      return 0;
    }
    if (cachedCategories.length == 1) {
      return 1;
    }
    return cachedCategories.length - 1;
  }

  void updateTeam(Team team, String name, String location) {
    team._name = name;
    team._location = location;
    notifyListeners();
  }

  void updatePortfolio(Team team, bool value) {
    team._hasPortfolio = value;
    notifyListeners();
  }

  void updateBlurb(Team team, Award award, String blurb) {
    if ((team._blurbs[award] ?? '') != blurb) {
      if (blurb.isEmpty) {
        team._blurbs.remove(award);
      } else {
        team._blurbs[award] = blurb;
      }
      team.notifyListeners();
      notifyListeners();
    }
  }

  void updateAwardSubname(Team team, Award award, String awardSubname) {
    if ((team._awardSubnames[award] ?? '') != awardSubname) {
      if (awardSubname.isEmpty) {
        team._awardSubnames.remove(award);
      } else {
        assert(!award.isPlacement);
        team._awardSubnames[award] = awardSubname;
      }
      team.notifyListeners();
      notifyListeners();
    }
  }

  void updateTeamVisited(Team team, {required int visited}) {
    team._visited = visited;
    notifyListeners();
  }

  void updateTeamInspireStatus(Team team, {required InspireStatus status}) {
    team._inspireStatus = status;
    notifyListeners();
  }

  void updateShortlistRank(Award award, Team team, int? rank) {
    ShortlistEntry entry = _shortlists[award]!._entries[team]!;
    if (entry.rank != rank) {
      entry._rank = rank;
      _shortlists[award]!._checkForTies();
      entry.notifyListeners();
      notifyListeners();
    }
  }

  Award? _inspireAward;
  Award? get inspireAward => _inspireAward;

  Map<int, Map<Team, Set<String>>> computeInspireCandidates() {
    final Map<int, Map<Team, Set<String>>> candidates = <int, Map<Team, Set<String>>>{};
    for (final Team team in teamsView) {
      final Set<String> categories = team.shortlistedAdvancingCategories;
      if (categories.isNotEmpty) {
        final Map<Team, Set<String>> group = candidates.putIfAbsent(categories.length, () => <Team, Set<String>>{});
        group[team] = categories;
      }
    }
    return candidates;
  }

  List<(Award, List<AwardFinalistEntry>)>? _cachedFinalists;

  List<(Award, List<AwardFinalistEntry>)> computeFinalists() {
    if (_cachedFinalists == null) {
      final Map<Award, List<Set<Team>>> awardCandidates = {};
      final Map<Award, List<AwardFinalistEntry>> finalists = {};
      for (final Award award in awardsView) {
        awardCandidates[award] = shortlistsView[award]?.asRankedList() ?? [];
        finalists[award] = [];
      }
      final List<List<Award>> awardTiers = [
        awardsView.where((Award award) => award.isInspire).toList(),
        awardsView.where((Award award) => !award.isInspire && award.spreadTheWealth != SpreadTheWealth.no && award.isAdvancing).toList(),
        awardsView.where((Award award) => !award.isInspire && award.spreadTheWealth != SpreadTheWealth.no && !award.isAdvancing).toList(),
        awardsView.where((Award award) => !award.isInspire && award.spreadTheWealth == SpreadTheWealth.no).toList(),
      ];
      assert((awardTiers[0].isEmpty && inspireAward == null) || awardTiers[0].single == inspireAward);
      final Map<Team, (Award, int)> placedTeams = {};
      for (List<Award> awards in awardTiers) {
        int rank = 1;
        bool stillPlacing = true;
        while (stillPlacing) {
          stillPlacing = false;
          for (final Award award in awards) {
            if (rank <= award.count) {
              bool placedTeam = false;
              Map<Team, FinalistKind>? overrides = _overrides[award]?[rank];
              if (overrides != null && overrides.isNotEmpty) {
                placedTeam = true;
                for (Team team in overrides.keys) {
                  finalists[award]!.add((team, null, rank, tied: overrides.length > 1, kind: overrides[team]!));
                }
              } else if (applyFinalistsByAwardRanking || award.isInspire) {
                final List<Set<Team>> candidatesList = awardCandidates[award]!;
                while (candidatesList.isNotEmpty && !placedTeam) {
                  final Set<Team> candidates = candidatesList.removeAt(0);
                  candidates.removeWhere((Team team) => (award.isInspire && team.inspireStatus == InspireStatus.ineligible) || team.inspireStatus == InspireStatus.exhibition);
                  final Set<Team> alreadyPlaced = award.spreadTheWealth != SpreadTheWealth.no ? placedTeams.keys.toSet() : {};
                  final Set<Team> ineligible = candidates.intersection(alreadyPlaced);
                  final Set<Team> winners = candidates.difference(ineligible);
                  if (ineligible.isNotEmpty) {
                    for (Team team in ineligible) {
                      final (Award oldAward, int oldRank) = placedTeams[team]!;
                      finalists[award]!.add((team, oldAward, oldRank, tied: false, kind: FinalistKind.automatic));
                    }
                  }
                  if (winners.isNotEmpty) {
                    placedTeam = true;
                    for (Team team in winners) {
                      finalists[award]!.add((team, null, rank, tied: winners.length > 1, kind: FinalistKind.automatic));
                      if (award.spreadTheWealth == SpreadTheWealth.allPlaces || (award.spreadTheWealth == SpreadTheWealth.winnerOnly && rank == 1)) {
                        placedTeams[team] = (award, rank);
                      }
                    }
                  }
                }
              }
              if (!placedTeam) {
                finalists[award]!.add((null, null, rank, tied: false, kind: FinalistKind.automatic));
              }
              if (rank < award.count) {
                stillPlacing = true;
              }
            }
          }
          rank += 1;
        }
      }
      List<(Award, List<AwardFinalistEntry>)> result = [];
      for (Award award in awardsView) {
        result.add((award, finalists[award]!));
      }
      _cachedFinalists = result;
    }
    return _cachedFinalists!;
  }

  void _addAward(Award award) {
    assert(award.rank == (_awards.isEmpty ? 1 : _awards.last.rank + 1));
    assert(!award.isEventSpecific || award.category == '');
    assert(!award.isEventSpecific || !award.isAdvancing);
    _awards.add(award);
    if (award.isInspire) {
      assert(award.isAdvancing);
      assert(_inspireAward == null);
      _inspireAward = award;
    }
    _shortlists[award] = Shortlist();
  }

  void addEventAward({
    required String name,
    required int count,
    required SpreadTheWealth spreadTheWealth,
    required bool isPlacement,
    required bool needsPortfolio,
    required PitVisit pitVisit,
  }) {
    final Award award = Award(
      name: name,
      kind: AwardKind.nonAdvancing,
      rank: _awards.isEmpty ? 1 : _awards.last.rank + 1,
      count: count,
      category: '',
      spreadTheWealth: spreadTheWealth,
      autonominationRule: null,
      isPlacement: isPlacement,
      needsPortfolio: needsPortfolio,
      pitVisits: pitVisit,
      isEventSpecific: true,
      type: 0,
      color: const Color(0xFFFFFFFF),
      comment: '',
      competition: this,
    );
    // event awards cannot affect Inspire logic:
    assert(award.category == '');
    assert(!award.isAdvancing);
    _addAward(award);
    notifyListeners();
  }

  bool canDelete(Award award) {
    assert(award.isEventSpecific);
    return _shortlists[award]!.entriesView.isEmpty;
  }

  void deleteEventAward(Award award) {
    assert(award.isEventSpecific);
    assert(canDelete(award));
    _awards.remove(award);
    _shortlists.remove(award);
    notifyListeners();
  }

  void addOverride(Award award, Team team, int rank, FinalistKind kind) {
    _overrides.putIfAbsent(award, () => <int, Map<Team, FinalistKind>>{}).putIfAbsent(rank, () => <Team, FinalistKind>{})[team] = kind;
    notifyListeners();
  }

  void removeOverride(Award award, Team team, int rank) {
    _overrides[award]![rank]!.remove(team);
    if (_overrides[award]![rank]!.isEmpty) {
      _overrides[award]!.remove(rank);
      if (_overrides[award]!.isEmpty) {
        _overrides.remove(award);
      }
    }
    notifyListeners();
  }

  int Function(Award a, Award b) get awardSorter {
    if (!applyFinalistsByAwardRanking) {
      return Award.categoryBasedComparator;
    }
    switch (_awardOrder) {
      case AwardOrder.categories: return Award.categoryBasedComparator;
      case AwardOrder.rank: return Award.rankBasedComparator;
    }
  }

  AwardOrder get awardOrder => AwardOrder.categories;
  AwardOrder _awardOrder = AwardOrder.categories;
  set awardOrder(AwardOrder value) {
    if (value != _awardOrder) {
      _awardOrder = value;
      notifyListeners();
    }
  }

  Show get showNominationComments => _showNominationComments;
  Show _showNominationComments = Show.none;
  set showNominationComments(Show value) {
    if (value != _showNominationComments) {
      _showNominationComments = value;
      notifyListeners();
    }
  }

  Show get showNominators => _showNominators;
  Show _showNominators = Show.none;
  set showNominators(Show value) {
    if (value != _showNominators) {
      _showNominators = value;
      notifyListeners();
    }
  }

  bool get expandInspireTable => _expandInspireTable;
  bool _expandInspireTable = false;
  set expandInspireTable(bool value) {
    if (value != _expandInspireTable) {
      _expandInspireTable = value;
      notifyListeners();
    }
  }

  bool get showWorkings => _showWorkings;
  bool _showWorkings = true;
  set showWorkings(bool value) {
    if (value != _showWorkings) {
      _showWorkings = value;
      notifyListeners();
    }
  }

  bool get pitVisitsIncludeAutovisitedTeams => _pitVisitsIncludeAutovisitedTeams;
  bool _pitVisitsIncludeAutovisitedTeams = true;
  set pitVisitsIncludeAutovisitedTeams(bool value) {
    if (value != _pitVisitsIncludeAutovisitedTeams) {
      _pitVisitsIncludeAutovisitedTeams = value;
      notifyListeners();
    }
  }

  bool get pitVisitsIncludeExhibitionTeams => _pitVisitsIncludeExhibitionTeams;
  bool _pitVisitsIncludeExhibitionTeams = true;
  set pitVisitsIncludeExhibitionTeams(bool value) {
    if (value != _pitVisitsIncludeExhibitionTeams) {
      _pitVisitsIncludeExhibitionTeams = value;
      notifyListeners();
    }
  }

  int get pitVisitsViewMinVisits => _pitVisitsViewMinVisits;
  int _pitVisitsViewMinVisits = 0;
  set pitVisitsViewMinVisits(int value) {
    if (value != _pitVisitsViewMinVisits) {
      _pitVisitsViewMinVisits = value;
      notifyListeners();
    }
  }

  int get pitVisitsViewMaxVisits => _pitVisitsViewMaxVisits ?? expectedPitVisits;
  int? _pitVisitsViewMaxVisits;
  set pitVisitsViewMaxVisits(int value) {
    if (value != pitVisitsViewMaxVisits) { // comparing to getter, not raw value
      if (value == expectedPitVisits) {
        _pitVisitsViewMaxVisits = null;
      } else {
        _pitVisitsViewMaxVisits = value;
      }
      notifyListeners();
    }
  }

  bool get hideInspireHiddenTeams => _hideInspireHiddenTeams;
  bool _hideInspireHiddenTeams = false;
  set hideInspireHiddenTeams(bool value) {
    if (value != _hideInspireHiddenTeams) {
      _hideInspireHiddenTeams = value;
      notifyListeners();
    }
  }

  bool get applyFinalistsByAwardRanking => _applyFinalistsByAwardRanking;
  bool _applyFinalistsByAwardRanking = false;
  set applyFinalistsByAwardRanking(bool value) {
    if (value != _applyFinalistsByAwardRanking) {
      _applyFinalistsByAwardRanking = value;
      notifyListeners();
    }
  }

  TeamComparatorCallback get inspireSortOrder => _inspireSortOrder;
  TeamComparatorCallback _inspireSortOrder = Team.teamNumberComparator;
  set inspireSortOrder(TeamComparatorCallback value) {
    if (value != _inspireSortOrder) {
      _inspireSortOrder = value;
      notifyListeners();
    }
  }

  TeamComparatorCallback get finalistsSortOrder => _finalistsSortOrder;
  TeamComparatorCallback _finalistsSortOrder = Team.teamNumberComparator;
  set finalistsSortOrder(TeamComparatorCallback value) {
    if (value != _finalistsSortOrder) {
      _finalistsSortOrder = value;
      notifyListeners();
    }
  }

  // IMPORT/EXPORT

  static bool _parseBool(Object? cell) {
    if (cell is int) {
      return cell != 0;
    }
    if (cell is double) {
      return cell != 0.0;
    }
    switch (cell) {
      case true:
      case 'y':
      case 'yes':
      case 'true':
        return true;
    }
    return false;
  }

  static bool? _parseTristate(Object? cell, String thirdState) {
    if (cell == thirdState) {
      return null;
    }
    return _parseBool(cell);
  }

  static AwardKind _parseAwardKind(String cell) {
    switch (cell) {
      case 'Inspire': return AwardKind.inspire;
      case 'Advancing': return AwardKind.advancingInspire;
      case 'Non-Advancing': return AwardKind.nonAdvancing;
      case 'Independent Advancing': return AwardKind.advancingIndependent;
      default:
        throw FormatException('Unknown value for "Advancing" column: "$cell". Must be one of "Inspire", "Advancing" (which means Inspire Contributor), "Non-Advancing", or "Independent Advancing".');
    }
  }

  static String _serializeAwardKind(AwardKind value) {
    switch (value) {
      case AwardKind.inspire: return 'Inspire';
      case AwardKind.advancingInspire: return 'Advancing';
      case AwardKind.nonAdvancing: return 'Non-Advancing';
      case AwardKind.advancingIndependent: return 'Independent Advancing';
    }
  }

  static InspireStatus _parseInspireStatus(Object? cell) {
    if (cell is int) {
      return cell != 0 ? InspireStatus.eligible : InspireStatus.ineligible;
    }
    if (cell is double) {
      return cell != 0.0 ? InspireStatus.eligible : InspireStatus.ineligible;
    }
    switch (cell) {
      case 'eligible':
        return InspireStatus.eligible;
      case 'ineligible':
        return InspireStatus.ineligible;
      case 'hidden':
        return InspireStatus.hidden;
      case 'exhibition':
        return InspireStatus.exhibition;
    }
    return InspireStatus.eligible;
  }

  static String _serializeInspireStatus(InspireStatus value) {
    switch (value) {
      case InspireStatus.eligible:
        return 'eligible';
      case InspireStatus.ineligible:
        return 'ineligible';
      case InspireStatus.hidden:
        return 'hidden';
      case InspireStatus.exhibition:
        return 'exhibition';
    }
  }

  static Show _parseShow(Object? cell) {
    switch (cell) {
      case 'all':
        return Show.all;
      case 'if any':
        return Show.ifNeeded;
      case 'none':
        return Show.none;
    }
    return Show.none;
  }

  static String _serializeShow(Show value) {
    switch (value) {
      case Show.all:
        return 'all';
      case Show.ifNeeded:
        return 'if any';
      case Show.none:
        return 'none';
    }
  }

  static int _parseType(bool isInspire, String name, int? type) {
    if (isInspire) {
      // This is the first advancing award. It must be the inspire award.
      if (type != null && type != 11) {
        throw FormatException('First advancing award (named "$name") must be the Inspire award, with type 11.');
      }
      return 11;
    }
    if (type != null) {
      if (type == 11) {
        // If we get here we know isInspire is false, so it can't be the first advancing award.
        throw FormatException('Only the first advancing award can be type 11; award "$name" must have a different type.');
      }
      return type;
    }
    switch (name) {
      case 'Think':
        return 9;
      case 'Connect':
        return 8;
      case 'Innovate':
        return 7;
      case 'Control':
        return 4;
      case 'Motivate':
        return 5;
      case 'Design':
        return 6;
      case 'Judges':
        return 1;
      default:
        return 0; // Unknown award. // The FTC API server doesn't list any awards with this code; hopefully they never add one.
    }
  }

  static FinalistKind _parseFinalistKind(Object? cell) {
    switch (cell) {
      case 'automatic':
        return FinalistKind.automatic;
      case 'override':
        return FinalistKind.override;
      case 'manual':
        return FinalistKind.manual;
    }
    throw FormatException('Unknown value for finalist kind: "$cell". Must be one of "automatic", "override", or "manual".');
  }

  static String _serializeFinalistKind(FinalistKind value) {
    switch (value) {
      case FinalistKind.automatic:
        return 'automatic';
      case FinalistKind.override:
        return 'override';
      case FinalistKind.manual:
        return 'manual';
    }
  }

  static TeamComparatorCallback _parseSortOrder(String cell) {
     switch (cell) {
       case 'rank score': return Team.inspireCandidateComparator;
       case 'rank count': return Team.rankedCountComparator;
       case 'team number': return Team.teamNumberComparator;
     }
     throw FormatException('Unknown sort order name: "$cell". Must be one of "rank score", "rank count", or "team number".');
  }

  static String _serializeSortOrder(TeamComparatorCallback value) {
    switch (value) {
      case Team.inspireCandidateComparator: return 'rank score';
      case Team.rankedCountComparator: return 'rank count';
      case Team.teamNumberComparator: return 'team number';
    }
    throw StateError('Unexpected sort order comparator function.');
  }


  // Data model

  void _clearTeams() {
    _teams.clear();
    for (final Shortlist shortlist in _shortlists.values) {
      shortlist._clear();
    }
    for (final Team team in _teams) {
      team._clearShortlists();
      team._clearBlurbs();
    }
    _overrides.clear();
    notifyListeners();
  }

  Future<void> importTeams(List<int> csvFile, {bool expectTeams = true}) async {
    _clearTeams();
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (expectTeams ? csvData.length <= 1 : csvData.isEmpty) {
      throw const FormatException('File does not contain any teams.');
    }
    try {
      int rowNumber = 2;
      for (List<dynamic> row in csvData.skip(1)) {
        if (row.length < 4) {
          throw FormatException('Teams file row $rowNumber has only ${row.length} cells but needs at least 4.');
        }
        if (row[0] is! int || (row[0] < 0)) {
          throw FormatException('Parse error in teams file row $rowNumber column 1: "${row[0]}" is not a valid team number.');
        }
        final InspireStatus inspireStatus = _parseInspireStatus(row[3]);
        final bool hasPortfolio = row.length > 4 ? _parseBool(row[4]) : true;
        final Team team = Team(
          number: row[0] as int,
          name: '${row[1]}',
          location: '${row[2]}',
          hasPortfolio: hasPortfolio,
          inspireStatus: inspireStatus,
        );
        _teams.add(team);
        rowNumber += 1;
      }
      _teams.sort();
    } catch (e) {
      _clearTeams();
      rethrow;
    }
    notifyListeners();
  }

  String teamsToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Team number', // numeric
      'Team name', // string
      'Team location', // string
      'Eligible for Inspire award', // 'eligible', 'ineligible', 'hidden', 'exhibition'
      'Team has portfolio', // 'y' or 'n'
    ]);
    for (final Team team in _teams) {
      data.add(['${team.number}', team.name, team.location, _serializeInspireStatus(team.inspireStatus), team.hasPortfolio ? 'y' : 'n']);
    }
    return const ListToCsvConverter().convert(data);
  }

  void _clearAwards() {
    _awards.clear();
    _inspireAward = null;
    _shortlists.clear();
    _categories.clear();
    for (final Team team in _teams) {
      team._clearShortlists();
      team._clearBlurbs();
    }
    _overrides.clear();
    notifyListeners();
  }

  Future<void> importAwards(List<int> csvFile, {bool expectAwards = true}) async {
    _clearAwards();
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (expectAwards ? csvData.length <= 1 : csvData.isEmpty) {
      throw const FormatException('File does not contain any awards.');
    }
    try {
      int rank = 1; // also the row number
      bool seenInspire = false;
      final Set<String> names = <String>{};
      for (List<dynamic> row in csvData.skip(1)) {
        if (row.length < 8) {
          throw FormatException('Awards file row $rank has only ${row.length} cells but needs at least 8.');
        }
        final String name = '${row[0]}';
        if (name.isEmpty) {
          throw FormatException('Parse error in awards file row $rank column 1: Award has no name.');
        }
        if (names.contains(name)) {
          throw FormatException('Parse error in awards file row $rank column 1: There is already an award named "$name".');
        }
        names.add(name);
        AwardKind kind = _parseAwardKind('${row[1]}');
        if (!seenInspire && kind == AwardKind.advancingInspire) {
          kind = AwardKind.inspire;
        }
        final bool isInspire = kind == AwardKind.inspire;
        if (isInspire && seenInspire) {
          throw FormatException('Parse error in awards file row $rank column 2: There is an advancing award before the Inspire award.');
        }
        seenInspire = seenInspire || isInspire;
        if (row[2] is! int || (row[2] < 0)) {
          throw FormatException('Parse error in awards file row $rank column 3: "${row[2]}" is not a valid award count.');
        }
        final int count = row[2] as int;
        final String category = '${row[3]}';
        if (kind == AwardKind.advancingInspire && category.isEmpty) {
          throw FormatException('Parse error in awards file row $rank column 4: "${row[0]}" is an Inspire Advancing award but has no specified category.');
        }
        final SpreadTheWealth spreadTheWealth = switch (row[4]) {
          'all places' => SpreadTheWealth.allPlaces,
          'winner only' => SpreadTheWealth.winnerOnly,
          'no' => SpreadTheWealth.no,
          _ => throw FormatException(
              'Parse error in awards file row $rank column 5: '
              '"${row[4]}" is not a valid "Spread The Wealth" value; '
              'valid values are "no", "all places", and "winner only".',
            ),
        };
        final bool isPlacement = _parseBool(row[5]);
        final PitVisit pitVisit = switch (_parseTristate(row[6], 'maybe')) {
          null => PitVisit.maybe,
          true => PitVisit.yes,
          false => PitVisit.no,
        };
        final String colorAsString = '${row[7]}';
        final Color color;
        if (colors.containsKey(colorAsString)) {
          color = colors[colorAsString]!;
        } else {
          if (!colorAsString.startsWith('#') || colorAsString.length != 7) {
            throw FormatException('Parse error in awards file row $rank column 8: "$colorAsString" is not a valid color (e.g. "#FFFF00" or "yellow").');
          }
          int? colorAsInt = int.tryParse(colorAsString.substring(1), radix: 16);
          if (colorAsInt == null) {
            throw FormatException('Parse error in awards file row $rank column 8: "$colorAsString" is not a valid color (e.g. "#00FFFF" or "teal").');
          }
          color = Color(0xFF000000 | colorAsInt);
        }
        final bool isEventSpecific = row.length > 8 ? _parseBool(row[8]) : false;
        final AutonominationRule? autonominationRule = row.length > 9 ? AutonominationRule.parseFromCSV(row[9]) : null;
        if (isInspire && autonominationRule != null) {
          throw FormatException(
            'Parse error in awards file row $rank column 10: the first Advancing award is the Inspire award and cannot have an autonomination rule as teams are not nominated for the Inspire award.',
          );
        }
        final String comment = row.length > 10 ? row[10] : '';
        final int type = _parseType(isInspire, name, row.length > 11 ? row[11] : null);
        final bool needsPortfolio = _parseBool(row.length > 12 ? row[12] : null);
        final Award award = Award(
          name: name,
          kind: kind,
          rank: rank,
          count: count,
          category: category,
          spreadTheWealth: spreadTheWealth,
          autonominationRule: autonominationRule,
          isPlacement: isPlacement,
          needsPortfolio: needsPortfolio,
          pitVisits: pitVisit,
          isEventSpecific: isEventSpecific,
          type: type,
          color: color,
          comment: comment,
          competition: this,
        );
        _addAward(award);
        rank += 1;
      }
      if (!seenInspire && expectAwards) {
        throw const FormatException('Parse error in awards file: None of the awards are advancing awards.');
      }
      _categories
        ..addAll(awardsView.where(Award.isInspireQualifyingPredicate).map((Award award) => award.category).toSet())
        ..sort();
    } catch (e) {
      _clearAwards();
      rethrow;
    }
    notifyListeners();
  }

  String awardsToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Award name', // string
      'Award type', // 'Inspire', 'Advancing', 'Non-Advancing', 'Independent Advancing'
      'Award count', // numeric
      'Award category', // string
      'Spread the wealth', // 'y' or 'n'
      'Placement', // 'y' or 'n'
      'Pit visits', // 'y', 'n', 'maybe'
      'Color', // #XXXXXX
      'Event-Specific', // 'y', 'n'
      'Autonomination rule', // empty or 'if last category',
      'Comment', // string
      'FTC Award ID', // integer, see http://ftc-api.firstinspires.org/v2.0/2024/awards/list
      'Needs portfolio', // 'y' or 'n'
    ]);
    for (final Award award in _awards) {
      data.add([
        award.name,
        _serializeAwardKind(award.kind),
        award.count,
        award.category,
        switch (award.spreadTheWealth) {
          SpreadTheWealth.allPlaces => 'all places',
          SpreadTheWealth.winnerOnly => 'winner only',
          SpreadTheWealth.no => 'no',
        },
        award.isPlacement ? 'y' : 'n',
        switch (award.pitVisits) {
          PitVisit.yes => 'y',
          PitVisit.no => 'n',
          PitVisit.maybe => 'maybe'
        },
        '#${(award.color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}', // ignore: deprecated_member_use
        award.isEventSpecific ? 'y' : 'n',
        award.autonominationRule?.toCSV() ?? '',
        award.comment,
        award.type,
        award.needsPortfolio ? 'y' : 'n',
      ]);
    }
    return const ListToCsvConverter().convert(data);
  }

  Future<void> importPitVisitNotes(List<int> csvFile) async {
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.isEmpty) {
      throw const FormatException('Pit visit notes are corrupted.');
    }
    Map<int, Team> teamMap = {
      for (final Team team in _teams) team.number: team,
    };
    for (List<dynamic> row in csvData.skip(1)) {
      if (row.length < 3) {
        throw const FormatException('Pit visits notes file contains a row with less than three cells.');
      }
      if (row[0] is! int || (row[0] < 0)) {
        throw FormatException('Parse error in pit visits notes file: "${row[0]}" is not a valid team number.');
      }
      if (!teamMap.containsKey(row[0] as int)) {
        throw FormatException('Parse error in pit visits notes file: team "${row[0]}" not recognised.');
      }
      Team team = teamMap[row[0] as int]!;
      int value = row[1] is int
          ? row[1]
          : row[1] == 'y'
              ? 1
              : int.tryParse('{row[1]}', radix: 10) ?? 0;
      if (value < 0) {
        throw FormatException('Parse error in pit visits notes file: "${row[1]}" is not a valid number of pit visits.');
      }
      team._visited = value;
      team.visitingJudgesNotes = row[2];
    }
    notifyListeners();
  }

  String pitVisitNotesToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Team number', // numeric
      'Visited?', // numeric, or 'y' or 'n'
      'Assigned judging team', // string
      'Pit visit nominations', // comma-separated string (ambiguous if any awards have commas in their name)
    ]);
    for (final Team team in _teams) {
      data.add([
        team.number,
        team.visited == 1
            ? 'y'
            : team.visited == 0
                ? 'n'
                : team.visited,
        team.visitingJudgesNotes,
        team.shortlistedAwardsWithPitVisits.map((Award award) => award.name).join(', '),
      ]);
    }
    return const ListToCsvConverter().convert(data);
  }

  bool awardIsAutonominated(Award award, Team team) {
    return award.autonominationRule?.shouldAutonominate(team, award, awardsView) ?? false;
  }

  void _checkTeamForAutonominations(Team team, bool lateEntry) {
    for (Award award in _awards) {
      if (!team.shortlistsView.containsKey(award) && awardIsAutonominated(award, team)) {
        addToShortlist(award, team, ShortlistEntry(nominator: 'Autonominated', lateEntry: lateEntry));
        // addToShortlist will call us re-entrantly, so end this iteration now.
        return;
      }
    }
  }

  void addToShortlist(Award award, Team team, ShortlistEntry entry) {
    _shortlists[award]!._add(team, entry);
    team._addToShortlist(award, entry);
    _checkTeamForAutonominations(team, entry.lateEntry);
    notifyListeners();
  }

  bool removingFromShortlistWillRemoveInspireRank(Award award, Team team) {
    assert(_shortlists[award]!.entriesView.containsKey(team));
    return inspireAward != null &&
        _shortlists[inspireAward]!.entriesView.containsKey(team) &&
        team._countHyptheticalShortlistedAdvancingCategories(without: award) < minimumInspireCategories;
  }

  void removeFromShortlist(Award award, Team team) {
    assert(_shortlists[award]!.entriesView.containsKey(team));
    _shortlists[award]!._remove(team);
    team._removeFromShortlist(award);
    if (inspireAward != null &&
        _shortlists[inspireAward]!.entriesView.containsKey(team) &&
        team._shortlistedAdvancingCategories.length < minimumInspireCategories) {
      _shortlists[inspireAward]!._remove(team);
      team._removeFromShortlist(inspireAward!);
    }
    notifyListeners();
  }

  Future<void> importShortlists(List<int> csvFile) async {
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.isEmpty) {
      throw const FormatException('Shortlists file corrupted.');
    }
    Map<int, Team> teamMap = {
      for (final Team team in _teams) team.number: team,
    };
    Map<String, Award> awardMap = {
      for (final Award award in _awards) award.name: award,
    };
    for (List<dynamic> row in csvData.skip(1)) {
      if (row.length < 5) {
        throw const FormatException('Shortlists file contains a row with less than five cells.');
      }
      if (!awardMap.containsKey('${row[0]}')) {
        throw FormatException('Parse error in shortlists file: award "${row[0]}" not recognized.');
      }
      final Award award = awardMap['${row[0]}']!;
      if (row[1] is! int || (row[1] < 0)) {
        throw FormatException('Parse error in shortlists file: "${row[1]}" is not a valid team number.');
      }
      if (!teamMap.containsKey(row[1] as int)) {
        throw FormatException('Parse error in shortlists file: team "${row[1]}" not recognised.');
      }
      final Team team = teamMap[row[1] as int]!;
      if (row[3] != '' && (row[3] is! int || (row[3] < 0))) {
        throw FormatException('Parse error in shortlists file: "${row[3]}" is not a valid rank.');
      }
      final int? rank = row[3] == '' ? null : row[3] as int;
      if (row[4] != 'y' && row[4] != 'n') {
        throw FormatException('Parse error in shortlists file: "${row[4]}" is not either "y" or "n".');
      }
      final String comment = row.length > 5 ? '${row[5]}' : '';
      addToShortlist(award, team, ShortlistEntry(lateEntry: row[4] == 'y', nominator: '${row[2]}', comment: comment, rank: rank));
    }
    notifyListeners();
  }

  String shortlistsToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Award name', // string
      'Team number', // numeric
      'Nominator', // string
      'Rank', // numeric or empty
      'Late entry', // 'y' or 'n'
      'Comment', // string (column is optional)
    ]);
    for (final Award award in _awards) {
      for (final Team team in _shortlists[award]!.entriesView.keys) {
        final ShortlistEntry entry = _shortlists[award]!.entriesView[team]!;
        data.add([award.name, team.number, entry.nominator, entry.rank ?? '', entry.lateEntry ? 'y' : 'n', entry.comment]);
      }
    }
    return const ListToCsvConverter().convert(data);
  }

  Future<void> importFinalistOverrides(List<int> csvFile) async {
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.isEmpty) {
      throw const FormatException('Finalist overrides are corrupted.');
    }
    Map<int, Team> teamMap = {
      for (final Team team in _teams) team.number: team,
    };
    Map<String, Award> awardMap = {
      for (final Award award in _awards) award.name: award,
    };
    for (List<dynamic> row in csvData.skip(1)) {
      if (row.length < 3) {
        throw const FormatException('Finalist overrides file contains a row with less than three cells.');
      }
      if (!awardMap.containsKey('${row[0]}')) {
        throw FormatException('Parse error in finalist overrides file: award "${row[0]}" not recognized.');
      }
      final Award award = awardMap['${row[0]}']!;
      if (row[1] is! int || (row[1] < 0)) {
        throw FormatException('Parse error in finalist overrides file: "${row[1]}" is not a valid team number.');
      }
      if (!teamMap.containsKey(row[1] as int)) {
        throw FormatException('Parse error in finalist overrides file: team "${row[1]}" not recognised.');
      }
      final Team team = teamMap[row[1] as int]!;
      if (row[2] is! int || (row[2] < 0)) {
        throw FormatException('Parse error in finalist overrides file: "${row[2]}" is not a valid rank.');
      }
      final int rank = row[2] as int;
      final FinalistKind kind = (row.length > 3) ? _parseFinalistKind(row[3]) : FinalistKind.override;
      addOverride(award, team, rank, kind);
    }
    notifyListeners();
  }

  String finalistOverridesToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Award name', // string
      'Team number', // numeric
      'Rank', // numeric
      'Kind', // 'automatic', 'override', or 'manual'
    ]);
    for (final Award award in _overrides.keys) {
      for (final int rank in _overrides[award]!.keys) {
        for (final Team team in _overrides[award]![rank]!.keys) {
          data.add([
            award.name,
            team.number,
            rank,
            _serializeFinalistKind(_overrides[award]![rank]![team]!)
          ]);
        }
      }
    }
    return const ListToCsvConverter().convert(data);
  }

  Future<void> importBlurbs(List<int> csvFile) async {
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.isEmpty) {
      throw const FormatException('Blurbs file corrupted.');
    }
    Map<int, Team> teamMap = {
      for (final Team team in _teams) team.number: team,
    };
    Map<String, Award> awardMap = {
      for (final Award award in _awards) award.name: award,
    };
    for (List<dynamic> row in csvData.skip(1)) {
      if (row.length < 3) {
        throw const FormatException('Blurbs file contains a row with less than three cells.');
      }
      if (row[0] is! int || (row[0] < 0)) {
        throw FormatException('Parse error in blurbs file: "${row[0]}" is not a valid team number.');
      }
      if (!teamMap.containsKey(row[0] as int)) {
        throw FormatException('Parse error in blurbs file: team "${row[0]}" not recognised.');
      }
      final Team team = teamMap[row[0] as int]!;
      if (!awardMap.containsKey('${row[1]}')) {
        throw FormatException('Parse error in blurbs file: award "${row[1]}" not recognized.');
      }
      final Award award = awardMap['${row[1]}']!;
      final String blurb = '${row[2]}';
      final String awardSubname = row.length > 3 ? '${row[3]}' : '';
      if (blurb.isNotEmpty) {
        team._blurbs[award] = blurb;
      }
      if (awardSubname.isNotEmpty) {
        team._awardSubnames[award] = awardSubname;
      }
    }
    notifyListeners();
  }

  String blurbsToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Team number', // numeric
      'Award name', // string
      'Blurb', // string (HTML fragment)
      'Award subname', // string (optional)
    ]);
    for (final Team team in _teams) {
      for (final Award award in _awards) {
        if (team._blurbs.containsKey(award) || team._awardSubnames.containsKey(award)) {
          data.add([
            team.number,
            award.name,
            team._blurbs[award] ?? '',
            team._awardSubnames[award] ?? '',
          ]);
        }
      }
    }
    return const ListToCsvConverter().convert(data);
  }

  // Derived artifacts

  String inspireCandiatesToCsv() {
    final List<List<Object?>> data = [];
    final List<Award> awards = awardsView.where(Award.isInspireQualifyingPredicate).toList();
    for (final Team team in teamsView.toList()..sort(Team.inspireCandidateComparator)) {
      final Set<String> categories = team.shortlistedAdvancingCategories;
      data.add([
        team.number,
        for (final Award award in awards)
          if (team.shortlistsView.containsKey(award)) team.shortlistsView[award]!.rank ?? "?" else "",
        categories.length,
        team.rankScore ?? '',
        team.rankedCount,
        switch (team.inspireStatus) {
          InspireStatus.eligible => '',
          InspireStatus.ineligible => 'Ineligible',
          InspireStatus.hidden => '',
          InspireStatus.exhibition => 'Not competing',
        }
      ]);
    }
    data.insert(0, [
      'Team', // numeric
      for (final Award award in awards) award.name, // numeric (rank) or ""
      'Category Count',
      'Rank Score',
      'Rank Count',
      'Eligibility',
    ]);
    data.insert(1, [
      '',
      for (final Award award in awards) award.category,
      '',
      '',
      '',
      '',
    ]);
    return const ListToCsvConverter().convert(data);
  }

  String finalistTablesToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Award name', // string
      'Team number', // numeric, or empty if nobody won at the given rank (in which case the Result is numeric)
      'Result', // see below
    ]);
    // The Result is one of the following:
    //  - a number (giving the rank of the win)
    //  - a number followed by the string " (tied)", indicating the win is currently shared by multiple teams
    //  - a string consisting of an award name, a space, and a rank (giving the award that the team won that disqualified them from winning this one)
    for (final (Award award, List<AwardFinalistEntry> finalists) in computeFinalists()) {
      // ignore: unused_local_variable
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) in finalists) {
        data.add([
          award.name,
          team?.number ?? '',
          '${otherAward != null ? "${otherAward.name} " : ""}$rank${tied ? " (tied)" : ""}',
        ]);
      }
    }
    return const ListToCsvConverter().convert(data);
  }

  String finalistListsToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Rank', // string (1st, 2nd, etc)
      for (final Award award in awardsView) award.name, // team number (numeric), or "tied", or ""
    ]);
    int maxRank = 0;
    final Map<Award, List<Set<Team>?>> placedAwards = {};
    for (final (Award award, List<AwardFinalistEntry> finalists) in computeFinalists()) {
      final List<Set<Team>?> placedTeams = [];
      placedAwards[award] = placedTeams;
      // ignore: unused_local_variable
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) in finalists) {
        if (otherAward != null) {
          continue;
        }
        if (rank > maxRank) {
          maxRank = rank;
        }
        if (placedTeams.length < rank) {
          placedTeams.length = rank;
        }
        if (team != null) {
          (placedTeams[rank - 1] ??= {}).add(team);
        }
      }
    }
    for (int rank = 1; rank <= maxRank; rank += 1) {
      final List<Object?> row = [placementDescriptor(rank)];
      for (final Award award in awardsView) {
        final List<Set<Team>?> placedTeams = placedAwards[award]!;
        if (placedTeams.length < rank || placedTeams[rank - 1] == null) {
          row.add('');
        } else if (placedTeams[rank - 1]!.length > 1) {
          row.add('tied');
        } else {
          row.add(placedTeams[rank - 1]!.single.number);
        }
      }
      data.add(row);
    }
    return const ListToCsvConverter().convert(data);
  }

  // Configuration

  Future<void> importConfiguration(List<int> csvFile) async {
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.isEmpty) {
      throw const FormatException('Configuration file corrupted.');
    }
    for (List<dynamic> row in csvData) {
      switch (row[0]) {
        case 'event name':
          _eventName = row[1];
        case 'expected pit visits':
          int? value = row[1] is int ? row[1] : int.tryParse('${row[1]}', radix: 10);
          if (value == null || value < 1) {
            throw const FormatException('Invalid "expected pit visits" configuration value; must be integer greater than or equal to 1.');
          }
          _expectedPitVisits = value;
        case 'award order':
          _awardOrder = switch (row[1]) {
            'categories' => AwardOrder.categories,
            'rank' => AwardOrder.rank,
            _ => AwardOrder.categories,
          };
        case 'show nomination comments':
          _showNominationComments = _parseShow(row[1]);
        case 'show nominators':
          _showNominators = _parseShow(row[1]);
        case 'expand inspire table':
          _expandInspireTable = _parseBool(row[1]);
        case 'show workings':
          _showWorkings = _parseBool(row[1]);
        case 'hide hidden teams':
          _hideInspireHiddenTeams = _parseBool(row[1]);
        case 'apply finalists by award ranking':
          _applyFinalistsByAwardRanking = _parseBool(row[1]);
        case 'inspire sort order':
          _inspireSortOrder = _parseSortOrder('${row[1]}');
        case 'finalists sort order': 
          _finalistsSortOrder = _parseSortOrder('${row[1]}');
        case 'pit visits - exclude autovisited teams':
          _pitVisitsIncludeAutovisitedTeams = !_parseBool(row[1]); // for backwards compatibilit
        case 'pit visits - include autovisited teams':
          _pitVisitsIncludeAutovisitedTeams = _parseBool(row[1]);
        case 'pit visits - include exhibition teams':
          _pitVisitsIncludeExhibitionTeams = _parseBool(row[1]);
        case 'pit visits - hide visited teams':
          if (_parseBool(row[1])) {
            _pitVisitsViewMinVisits = 0;
            _pitVisitsViewMaxVisits = 0;
          } else {
            _pitVisitsViewMinVisits = 0;
            _pitVisitsViewMaxVisits = null;
          }
        case 'pit visits - min':
          int? value = row[1] is int ? row[1] : int.tryParse('${row[1]}', radix: 10);
          if (value == null || value < 0) {
            throw const FormatException('Invalid "pit visits - min" configuration value; must be a non-negative integer.');
          }
          _pitVisitsViewMinVisits = value;
        case 'pit visits - max':
          if (row[1] == 'null') {
            _pitVisitsViewMaxVisits = null;
          } else {
            int? value = row[1] is int ? row[1] : int.tryParse('${row[1]}', radix: 10);
            if (value == null || value < 0) {
              throw const FormatException('Invalid "pit visits - max" configuration value; must be a non-negative integer or the string "null".');
            }
            _pitVisitsViewMaxVisits = value;
          }
      }
    }
    if (_pitVisitsViewMinVisits > _expectedPitVisits) {
      _pitVisitsViewMinVisits = 0;
    }
    if (_pitVisitsViewMaxVisits != null && (_pitVisitsViewMaxVisits! < _pitVisitsViewMinVisits || _pitVisitsViewMaxVisits! >= _expectedPitVisits)) {
      _pitVisitsViewMaxVisits = null;
    }
    notifyListeners();
  }

  // this is the default configuration before parsing settings from import
  // it is NOT the default configuration on startup
  void _resetConfiguration() {
    _eventName = '';
    _expectedPitVisits = 1;
    _awardOrder = AwardOrder.categories;
    _showNominationComments = Show.none;
    _showNominators = Show.none;
    _expandInspireTable = false;
    _showWorkings = true;
    _hideInspireHiddenTeams = false;
    _applyFinalistsByAwardRanking = true; // default to true for imported events, but false on fresh startup
    _inspireSortOrder = Team.teamNumberComparator;
    _finalistsSortOrder = Team.rankedCountComparator;
    _pitVisitsIncludeAutovisitedTeams = false;
    _pitVisitsIncludeExhibitionTeams = false;
    _pitVisitsViewMinVisits = 0;
    _pitVisitsViewMaxVisits = null;
    notifyListeners();
  }

  String configurationToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Setting', // string
      'Value', // varies
    ]);
    data.add(['event name', _eventName]);
    data.add(['expected pit visits', _expectedPitVisits]);
    data.add([
      'award order',
      switch (_awardOrder) {
        AwardOrder.categories => 'categories',
        AwardOrder.rank => 'rank',
      }
    ]);
    data.add(['show nomination comments', _serializeShow(_showNominationComments)]);
    data.add(['show nominators', _serializeShow(_showNominators)]);
    data.add(['expand inspire table', _expandInspireTable ? 'y' : 'n']);
    data.add(['show workings', _showWorkings ? 'y' : 'n']);
    data.add(['hide hidden teams', _hideInspireHiddenTeams ? 'y' : 'n']);
    data.add(['apply finalists by award ranking', _applyFinalistsByAwardRanking ? 'y' : 'n']);
    data.add(['inspire sort order', _serializeSortOrder(_inspireSortOrder)]);
    data.add(['finalists sort order', _serializeSortOrder(_finalistsSortOrder)]);
    data.add(['pit visits - include autovisited teams', _pitVisitsIncludeAutovisitedTeams ? 'y' : 'n']);
    data.add(['pit visits - include exhibition teams', _pitVisitsIncludeExhibitionTeams ? 'y' : 'n']);
    data.add(['pit visits - min', '$_pitVisitsViewMinVisits']); // numeric
    data.add(['pit visits - max', '$_pitVisitsViewMaxVisits']); // numeric or "null"
    return const ListToCsvConverter().convert(data);
  }

  static const String filenameTeams = 'teams.csv';
  static const String filenameAwards = 'awards.csv';
  static const String filenamePitVisitNotes = 'pit visit notes.csv';
  static const String filenameShortlists = 'shortlists.csv';
  static const String filenameBlurbs = 'blurbs.csv';
  static const String filenameFinalistOverrides = 'finalist overrides.csv';
  static const String filenameInspireCandidates = 'inspire candidates.csv';
  static const String filenameFinalistsTable = 'finalists table.csv';
  static const String filenameFinalistsLists = 'finalists lists.csv';
  static const String filenameConfiguration = 'jaa configuration.csv';

  Future<void> importEventState(PlatformFile zipFile) async {
    _loading = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    try {
      _clearTeams();
      _clearAwards();
      _resetConfiguration();
      try {
        final Archive zip = ZipDecoder().decodeBytes(await zipFile.readStream!.expand<int>((List<int> fragment) => fragment).toList());
        if (zip.findFile(filenameTeams) == null) {
          throw const FormatException('Archive is not a complete event state description (does not contain "$filenameTeams" file).');
        }
        if (zip.findFile(filenameAwards) == null) {
          throw const FormatException('Archive is not a complete event state description (does not contain "$filenameAwards" file).');
        }
        if (zip.findFile(filenamePitVisitNotes) == null) {
          throw const FormatException('Archive is not a complete event state description (does not contain "$filenamePitVisitNotes" file).');
        }
        if (zip.findFile(filenameShortlists) == null) {
          throw const FormatException('Archive is not a complete event state description (does not contain "$filenameShortlists" file).');
        }
        await importTeams(zip.findFile(filenameTeams)!.content, expectTeams: false);
        await importAwards(zip.findFile(filenameAwards)!.content, expectAwards: false);
        await importPitVisitNotes(zip.findFile(filenamePitVisitNotes)!.content);
        await importShortlists(zip.findFile(filenameShortlists)!.content);
        if (zip.findFile(filenameBlurbs) != null) {
          await importBlurbs(zip.findFile(filenameBlurbs)!.content);
        }
        if (zip.findFile(filenameFinalistOverrides) != null) {
          await importFinalistOverrides(zip.findFile(filenameFinalistOverrides)!.content);
        }
        if (zip.findFile(filenameConfiguration) != null) {
          await importConfiguration(zip.findFile(filenameConfiguration)!.content);
        }
        _lastAutosaveMessage = 'Imported event state.';
      } catch (e) {
        _clearTeams();
        _clearAwards();
        _applyFinalistsByAwardRanking = false; // _resetConfiguration sets this to true for legacy reasons
        _lastAutosaveMessage = 'Failed to import event state.';
        rethrow;
      }
    } finally {
      notifyListeners();
      _lastAutosave = null;
      _loading = false;
      _dirty = false;
    }
  }

  void exportEventState(String filename) {
    final String timestamp = DateTime.now().toIso8601String();
    final ZipEncoder zip = ZipEncoder();
    final OutputFileStream output = OutputFileStream(filename);
    zip.startEncode(output);
    zip.addFile(ArchiveFile.string(
      'README',
      'This file contains the judging and award nomination state for a FIRST Tech Challenge event.'
          '\n'
          'The event state was saved on $timestamp.\n'
          '\n'
          'This archive contains data that can be opened by the FIRST Tech Challenge Judge Advisor Assistant.\n'
          '\n'
          'The following files describe the event state: "$filenameTeams", "$filenameAwards", "$filenameShortlists", "$filenameBlurbs", and "$filenamePitVisitNotes".\n'
          'The "$filenameFinalistOverrides" file contains any award finalists overrides that are in effect.\n'
          'The "$filenameConfiguration" file contains settings for the Judge Advisor Assistant app, including the event name.\n'
          '\n'
          'Other files (such as this one) are included for information purposes only. They are not used when reimporting the event state.\n'
          'The "$filenameInspireCandidates" file contains a listing of each team\'s rankings for awards that contribute to Inspire award nominations.\n'
          'The "$filenameFinalistsTable" and "$filenameFinalistsLists" files contain the computed finalists at the time of the export.\n'
          '\n'
          'For more information see: https://github.com/Hixie/jaa/',
    ));
    // The following files should be in the same order as listed in the documentation above.
    zip.addFile(ArchiveFile(filenameTeams, -1, utf8.encode(teamsToCsv())));
    zip.addFile(ArchiveFile(filenameAwards, -1, utf8.encode(awardsToCsv())));
    zip.addFile(ArchiveFile(filenameShortlists, -1, utf8.encode(shortlistsToCsv())));
    zip.addFile(ArchiveFile(filenameBlurbs, -1, utf8.encode(blurbsToCsv())));
    zip.addFile(ArchiveFile(filenamePitVisitNotes, -1, utf8.encode(pitVisitNotesToCsv())));
    zip.addFile(ArchiveFile(filenameFinalistOverrides, -1, utf8.encode(finalistOverridesToCsv())));
    zip.addFile(ArchiveFile(filenameConfiguration, -1, utf8.encode(configurationToCsv())));
    zip.addFile(ArchiveFile(filenameInspireCandidates, -1, utf8.encode(inspireCandiatesToCsv())));
    zip.addFile(ArchiveFile(filenameFinalistsTable, -1, utf8.encode(finalistTablesToCsv())));
    zip.addFile(ArchiveFile(filenameFinalistsLists, -1, utf8.encode(finalistListsToCsv())));
    zip.endEncode();
    output.closeSync();
  }

  // must contain no sensitive data
  // output must match this schema:
  //
  // {
  //   "type": "array",
  //   "items": {
  //     "type": "object",
  //     "properties": {
  //       "type": {
  //         "type": "integer",
  //         "description": "Relevant types:\nInspire: 11\nThink: 9\nConnect: 8\nInnovate: 7\nControl: 4\nMotivate: 5\nDesign: 6\nJudges': 1\n\nA complete list can be found in our API at https://ftc-api.firstinspires.org/v2.0/2024/awards/list (requires API credentials). Note that importing Dean's List recipients is not currently supported."
  //       },
  //       "subType": {
  //         "type": "integer",
  //         "description": "Always 0 for relevant awards",
  //         "default": "0"
  //       },
  //       "place": {
  //         "type": "integer",
  //         "description": "Between 1 and 3 for most awards",
  //         "minimum": 1
  //       },
  //       "team": {
  //         "type": "integer"
  //       },
  //       "name": {
  //         "type": "string",
  //         "description": "Only applicable for Compass/Dean's List"
  //       },
  //       "comment": {
  //         "type": "string",
  //         "description": "Judges' script. Only applicable when place=1"
  //       }
  //     },
  //     "required": [
  //       "type",
  //       "subType",
  //       "place"
  //     ]
  //   }
  // }
  String winnersToJson() {
    final List<Object?> results = <Object?>[];
    // final Map<String, Object?> root = <String, Object>{
    //   'generator': 'FIRST Tech Challenge Judge Advisor Assistant app',
    //   'timestamp': DateTime.now().toIso8601String(),
    //   if (_eventName.isNotEmpty) 'eventName': _eventName,
    //   'awards': results,
    // };
    for (final (Award award, List<AwardFinalistEntry> finalists) in computeFinalists()) {
      if (award.type != 0) {
        // ignore: unused_local_variable
        for (final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) in finalists) {
          if (team != null && otherAward == null) {
            results.add(<String, Object?>{
              'type': award.type,
              'subtype': 0,
              if (award.isPlacement) 'place': rank,
              'team': team.number,
              // if (team._awardSubnames.containsKey(award)) 'name': team._awardSubnames[award],
              if (team._blurbs.containsKey(award)) 'comment': team._blurbs[award],
            });
          }
        }
      }
    }
    return const JsonEncoder.withIndent('  ').convert(results);
  }

  bool _dirty = false;
  bool _loading = false; // blocks autosave
  bool _autosaving = false;
  Timer? _autosaveTimer;
  DateTime? _lastAutosave;
  String _lastAutosaveMessage = 'Changes will be autosaved.';

  bool get dirty => _dirty;
  bool get autosaveScheduled => _autosaveTimer != null;
  bool get loading => _loading;
  String get lastAutosaveMessage => _lastAutosaveMessage;
  DateTime? get lastAutosave => _lastAutosave;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _cachedFinalists = null;
    if (!_loading && !_autosaving) {
      _dirty = true;
      _autosaveTimer?.cancel();
      _autosaveTimer = Timer(const Duration(seconds: 5), _autosave);
      if (_lastAutosave == null) {
        _lastAutosaveMessage = 'Not yet autosaved.';
      }
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  String get _autosaveTempPath => path.join(autosaveDirectory.path, r'jaa_autosave.$$$');
  String get _autosaveFinalPath => path.join(autosaveDirectory.path, r'jaa_autosave.zip');

  PlatformFile get autosaveFile {
    final File file = File(_autosaveFinalPath);
    return PlatformFile(
      path: file.path,
      name: path.basename(file.path),
      size: 0,
      readStream: file.openRead(),
    );
  }

  bool get hasAutosave {
    try {
      return File(_autosaveFinalPath).existsSync();
    } on FileSystemException catch (e) {
      debugPrint('Unexpected error checking autosave directory: $e');
      return false;
    }
  }

  void _autosave() {
    assert(!_autosaving);
    assert(!_loading);
    _autosaving = true;
    _autosaveTimer = null;
    try {
      exportEventState(_autosaveTempPath);
      if (File(_autosaveFinalPath).existsSync()) {
        File(_autosaveFinalPath).deleteSync();
      }
      File(_autosaveTempPath).renameSync(_autosaveFinalPath);
      _lastAutosave = DateTime.now();
      _lastAutosaveMessage = 'Autosaved to: $_autosaveFinalPath';
      _dirty = false;
    } catch (e) {
      _lastAutosaveMessage = 'Autosave failed: $e';
      rethrow;
    } finally {
      notifyListeners();
      _autosaving = false;
    }
  }

  void debugGenerateRandomData(math.Random random) {
    // TODO: test the bits labeled "needs testing"
    if (kReleaseMode) {
      return;
    }
    _clearAwards();
    _clearTeams();
    _resetConfiguration();
    final Randomizer randomizer = Randomizer(random);
    if (random.nextInt(5) > 2) {
      _eventName = randomizer.generatePhrase();
    }
    _expectedPitVisits = random.nextInt(3) + 1;
    if (random.nextBool()) {
      _awardOrder = AwardOrder.rank;
    }
    _showNominationComments = randomizer.randomItem(Show.values);
    _showNominators = randomizer.randomItem(Show.values);
    _expandInspireTable = random.nextBool();
    _showWorkings = random.nextBool();
    _pitVisitsIncludeAutovisitedTeams = random.nextBool();
    _pitVisitsIncludeExhibitionTeams = random.nextBool();
    _pitVisitsViewMinVisits = 0; // needs testing
    _pitVisitsViewMaxVisits = random.nextBool() ? null : 0; // needs testing more deeply
    final List<String> categories = List<String>.generate(4, (int index) => randomizer.generatePhrase(random.nextInt(2) + 1));
    final int awardCount = random.nextInt(10) + 2;
    bool seenInspire = false;
    final int seed = random.nextInt(1 << 16);
    for (int index = 0; index < awardCount; index += 1) {
      bool isAdvancing = !seenInspire || random.nextInt(6) > 0;
      String name = randomizer.generatePhrase(random.nextInt(2) + 1);
      String category = isAdvancing && seenInspire ? randomizer.randomItem(categories) : '';
      AwardKind kind = isAdvancing
          ? (seenInspire ? AwardKind.inspire : AwardKind.advancingInspire)
          : AwardKind.nonAdvancing;
      final Award award = Award(
        name: name,
        kind: kind,
        rank: index + 1,
        count: random.nextInt(5) + 1,
        category: category,
        spreadTheWealth: randomizer.randomItem(SpreadTheWealth.values),
        autonominationRule: null, // needs testing
        isPlacement: random.nextInt(7) > 0,
        needsPortfolio: false, // needs testing
        pitVisits: randomizer.randomItem(PitVisit.values),
        isEventSpecific: !isAdvancing && random.nextInt(5) == 0,
        type: _parseType(isAdvancing && !seenInspire, name, null),
        color: Color(math.Random(seed ^ category.hashCode).nextInt(0x1000000) + 0xFF000000 |
            (random.nextInt(0x22) + random.nextInt(0x22) << 8 + random.nextInt(0x22) << 16)),
        comment: random.nextInt(7) > 0 ? randomizer.generatePhrase(random.nextInt(5) + 1) : '',
        competition: this,
      );
      seenInspire = seenInspire || isAdvancing;
      _addAward(award);
    }
    _categories
      ..addAll(awardsView.where(Award.isInspireQualifyingPredicate).map((Award award) => award.category).toSet())
      ..sort();
    final int teamCount = random.nextInt(1024 - 16) + 16;
    for (int index = 0; index < teamCount; index += 1) {
      InspireStatus inspireStatus = randomizer.randomItem(InspireStatus.values);
      final Team team = Team(
        number: random.nextInt(100000),
        name: randomizer.generatePhrase(),
        location: randomizer.generatePhrase(),
        hasPortfolio: true, // needs testing
        inspireStatus: inspireStatus,
      );
      _teams.add(team);
      team._visited = random.nextInt(_expectedPitVisits);
      if (random.nextInt(5) > 0) {
        team.visitingJudgesNotes = randomizer.generatePhrase(random.nextInt(30) + 2);
      }
    }
    final List<String> judges = List<String>.generate(random.nextInt(12) + 1, (int index) => randomizer.generatePhrase(random.nextInt(4) + 1));
    for (Award award in _awards) {
      for (Team team in _teams) {
        if (random.nextInt(teamCount ~/ 5) == 0) {
          addToShortlist(
            award,
            team,
            ShortlistEntry(
              lateEntry: random.nextInt(64) == 0,
              nominator: randomizer.randomItem(judges),
              comment: randomizer.generatePhrase(random.nextInt(30)),
              rank: random.nextInt(32),
            ),
          );
        }
        if (random.nextInt(teamCount) == 0) {
          addOverride(award, team, random.nextInt(10), FinalistKind.override);
        }
        if (random.nextInt(5) == 0) {
          team._blurbs[award] = randomizer.generatePhrase(128);
        }
        if (!award.isPlacement && award.count > 1 && random.nextInt(3) == 0) {
          team._awardSubnames[award] = randomizer.generatePhrase();
        }
      }
    }
    notifyListeners();
  }

  void updateTeamNumber(Team team, int newNumber) {
    team._number = newNumber;
    _teams.sort();
    notifyListeners();
  }
}

String formTeamList(List<Team> teams) {
  if (teams.isEmpty) {
    return 'None';
  }
  if (teams.length == 1) {
    return 'Team ${teams.single.number}';
  }
  return 'Teams ${teams.map((Team team) => team.number).join(', ')}';
}
