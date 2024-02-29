import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../widgets/widgets.dart';
import '../colors.dart';

typedef AwardFinalistEntry = (Team?, Award?, int, {bool tied, bool overridden});

enum PitVisit { yes, no, maybe }

enum SpreadTheWealth { allPlaces, winnerOnly, no }

enum AwardOrder { categories, rank }

// change notifications are specifically for the color changing
class Award extends ChangeNotifier {
  Award({
    required this.name,
    required this.isInspire,
    required this.isAdvancing,
    required this.rank,
    required this.count,
    required this.category,
    required this.spreadTheWealth,
    required this.isPlacement,
    required this.pitVisits,
    required this.isEventSpecific,
    required Color color,
  }) : _color = color;

  final String name;
  final bool isInspire;
  final bool isAdvancing;
  final int rank;
  final int count;
  final String category;
  final SpreadTheWealth spreadTheWealth;
  final bool isPlacement;
  final PitVisit pitVisits;
  final bool isEventSpecific;

  Color _color;
  Color get color => _color;

  void updateColor(Color color) {
    _color = color;
    notifyListeners();
  }

  String get description {
    StringBuffer buffer = StringBuffer();
    if (spreadTheWealth != SpreadTheWealth.no) {
      buffer.write('rank $rank ');
    }
    if (isAdvancing) {
      buffer.write('advancing award');
    } else {
      buffer.write('non-advancing award');
    }
    if (category.isNotEmpty) {
      buffer.write(' in the $category category');
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

class Team extends ChangeNotifier implements Comparable<Team> {
  Team({
    required this.number,
    required String name,
    required String city,
    required this.inspireEligible,
    bool visited = false,
  })  : _name = name,
        _city = city,
        _visited = visited;

  final int number;
  final bool inspireEligible;

  String get name => _name;
  String _name;

  String get city => _city;
  String _city;

  late final UnmodifiableMapView<Award, ShortlistEntry> shortlistsView = UnmodifiableMapView(_shortlists);
  final Map<Award, ShortlistEntry> _shortlists = <Award, ShortlistEntry>{};

  late final Set<String> shortlistedAdvancingCategories = UnmodifiableSetView(_shortlistedAdvancingCategories);
  final Set<String> _shortlistedAdvancingCategories = <String>{};

  // only meaningful when compared to teams with the same number of shortlistedAdvancingCategories
  int? get rankScore => _rankScore;
  int? _rankScore;

  bool get visited => _visited;
  bool _visited = false;

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
  set rank(int? value) {
    if (_rank != value) {
      _rank = value;
      notifyListeners();
    }
  }

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
    entry.addListener(_checkForTies);
    _checkForTies();
    notifyListeners();
  }

  void _remove(Team team) {
    assert(_entries.containsKey(team));
    _entries[team]!.removeListener(_checkForTies);
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
  final List<Team> _previousInspireWinners = <Team>[];
  final List<Award> _awards = <Award>[];
  final List<Award> _advancingAwards = <Award>[];
  final List<Award> _nonAdvancingAwards = <Award>[];
  final List<String> _categories = <String>[];
  final Map<Award, Shortlist> _shortlists = <Award, Shortlist>{};

  late final UnmodifiableListView<Team> teamsView = UnmodifiableListView<Team>(_teams);
  late final UnmodifiableListView<Team> previousInspireWinnersView = UnmodifiableListView<Team>(_previousInspireWinners);
  late final UnmodifiableListView<Award> awardsView = UnmodifiableListView<Award>(_awards);
  late final UnmodifiableListView<Award> advancingAwardsView = UnmodifiableListView<Award>(_advancingAwards);
  late final UnmodifiableListView<Award> nonAdvancingAwardsView = UnmodifiableListView<Award>(_nonAdvancingAwards);
  late final UnmodifiableMapView<Award, Shortlist> shortlistsView = UnmodifiableMapView<Award, Shortlist>(_shortlists);
  late final UnmodifiableListView<String> categories = UnmodifiableListView(_categories);

  final Map<Award, Map<int, Set<Team>>> _overrides = {};

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

  void updateTeam(Team team, String name, String city) {
    team._name = name;
    team._city = city;
    notifyListeners();
  }

  void updateTeamVisited(Team team, {required bool visited}) {
    team._visited = visited;
    notifyListeners();
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

  List<(Award, List<AwardFinalistEntry>)> computeFinalists() {
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
            Set<Team>? overrides = _overrides[award]?[rank];
            if (overrides != null && overrides.isNotEmpty) {
              placedTeam = true;
              for (Team team in overrides) {
                finalists[award]!.add((team, null, rank, tied: overrides.length > 1, overridden: true));
              }
            } else {
              final List<Set<Team>> candidatesList = awardCandidates[award]!;
              while (candidatesList.isNotEmpty && !placedTeam) {
                final Set<Team> candidates = candidatesList.removeAt(0);
                final Set<Team> alreadyPlaced = award.spreadTheWealth != SpreadTheWealth.no ? placedTeams.keys.toSet() : {};
                final Set<Team> ineligible = candidates.intersection(alreadyPlaced);
                final Set<Team> winners = candidates.difference(ineligible);
                if (ineligible.isNotEmpty) {
                  for (Team team in ineligible) {
                    final (Award oldAward, int oldRank) = placedTeams[team]!;
                    finalists[award]!.add((team, oldAward, oldRank, tied: false, overridden: false));
                  }
                }
                if (winners.isNotEmpty) {
                  placedTeam = true;
                  for (Team team in winners) {
                    finalists[award]!.add((team, null, rank, tied: winners.length > 1, overridden: false));
                    if (award.spreadTheWealth == SpreadTheWealth.allPlaces || (award.spreadTheWealth == SpreadTheWealth.winnerOnly && rank == 1)) {
                      placedTeams[team] = (award, rank);
                    }
                  }
                }
              }
            }
            if (!placedTeam) {
              finalists[award]!.add((null, null, rank, tied: false, overridden: false));
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
    return result;
  }

  void addEventAward({
    required String name,
    required int count,
    required SpreadTheWealth spreadTheWealth,
    required bool isPlacement,
    required PitVisit pitVisit,
  }) {
    final Award award = Award(
      name: name,
      isInspire: false,
      isAdvancing: false,
      rank: _awards.isEmpty ? 1 : _awards.last.rank + 1,
      count: count,
      category: '',
      spreadTheWealth: spreadTheWealth,
      isPlacement: isPlacement,
      pitVisits: pitVisit,
      isEventSpecific: true,
      color: const Color(0xFFFFFFFF),
    );
    _awards.add(award);
    _shortlists[award] = Shortlist();
    // event awards cannot affect Inspire logic:
    assert(award.category == '');
    assert(!award.isAdvancing);
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

  void addOverride(Award award, Team team, int rank) {
    _overrides.putIfAbsent(award, () => <int, Set<Team>>{}).putIfAbsent(rank, () => <Team>{}).add(team);
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

  int Function(Award a, Award b) get awardSorter => switch (_awardOrder) {
        AwardOrder.categories => Award.categoryBasedComparator,
        AwardOrder.rank => Award.rankBasedComparator,
      };

  AwardOrder get awardOrder => _awardOrder;
  AwardOrder _awardOrder = AwardOrder.categories;
  set awardOrder(AwardOrder value) {
    if (value != _awardOrder) {
      _awardOrder = value;
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

  // Data model

  void _clearTeams() {
    _teams.clear();
    _previousInspireWinners.clear();
    for (final Shortlist shortlist in _shortlists.values) {
      shortlist._clear();
    }
    for (final Team team in _teams) {
      team._clearShortlists();
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
        final bool pastInspireWinner = _parseBool(row[3]);
        final Team team = Team(
          number: row[0] as int,
          name: '${row[1]}',
          city: '${row[2]}',
          inspireEligible: !pastInspireWinner,
        );
        _teams.add(team);
        if (pastInspireWinner) {
          _previousInspireWinners.add(team);
        }
        rowNumber += 1;
      }
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
      'Team city', // string
      'Previous Inspire winner', // 'y' or 'n'
    ]);
    for (final Team team in _teams) {
      data.add(['${team.number}', team.name, team.city, !team.inspireEligible ? "y" : "n"]);
    }
    return const ListToCsvConverter().convert(data);
  }

  void _clearAwards() {
    _awards.clear();
    _advancingAwards.clear();
    _nonAdvancingAwards.clear();
    _inspireAward = null;
    _shortlists.clear();
    _categories.clear();
    for (final Team team in _teams) {
      team._clearShortlists();
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
        if (row[1] != 'Advancing' && row[1] != 'Non-Advancing') {
          throw FormatException('Parse error in awards file row $rank column 2: Unknown value for "Advancing" column: "${row[1]}".');
        }
        final bool isAdvancing = row[1] == 'Advancing';
        final bool isInspire = !seenInspire && isAdvancing;
        seenInspire = seenInspire || isInspire;
        if (row[2] is! int || (row[2] < 0)) {
          throw FormatException('Parse error in awards file row $rank column 3: "${row[2]}" is not a valid award count.');
        }
        final int count = row[2] as int;
        final String category = '${row[3]}';
        if (isAdvancing && !isInspire && category.isEmpty) {
          throw FormatException('Parse error in awards file row $rank column 4: "${row[0]}" is an Advancing award but has no specified category.');
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
        final PitVisit pitVisit = '${row[6]}' == 'maybe'
            ? PitVisit.maybe
            : _parseBool(row[6])
                ? PitVisit.yes
                : PitVisit.no;
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
        final Award award = Award(
          name: name,
          isInspire: isInspire,
          isAdvancing: isAdvancing,
          rank: rank,
          count: count,
          category: category,
          spreadTheWealth: spreadTheWealth,
          isPlacement: isPlacement,
          pitVisits: pitVisit,
          isEventSpecific: isEventSpecific,
          color: color,
        );
        _awards.add(award);
        if (award.isAdvancing) {
          _advancingAwards.add(award);
        } else {
          _nonAdvancingAwards.add(award);
        }
        if (isInspire) {
          _inspireAward = award;
        }
        _shortlists[award] = Shortlist();
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
      'Award type', // 'Advancing' or 'Non-Advancing'
      'Award count', // numeric
      'Award category', // string
      'Spread the wealth', // 'y' or 'n'
      'Placement', // 'y' or 'n'
      'Pit visits', // 'y', 'n', 'maybe'
      'Color', // #XXXXXX
      if (_awards.any((Award award) => award.isEventSpecific)) 'Event-Specific', // 'y', 'n'
    ]);
    for (final Award award in _awards) {
      data.add([
        award.name,
        award.isAdvancing ? 'Advancing' : 'Non-Advancing',
        award.count,
        award.category,
        switch (award.spreadTheWealth) {
          SpreadTheWealth.allPlaces => 'all places',
          SpreadTheWealth.winnerOnly => 'winner only',
          SpreadTheWealth.no => 'no',
        },
        award.isPlacement ? 'y' : 'n',
        switch (award.pitVisits) { PitVisit.yes => 'y', PitVisit.no => 'n', PitVisit.maybe => 'maybe' },
        '#${(award.color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        if (_awards.any((Award award) => award.isEventSpecific)) award.isEventSpecific ? 'y' : 'n'
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
      if (row[1] != 'y' && row[1] != 'n') {
        throw FormatException('Parse error in pit visits notes file: "${row[1]}" is not either "y" or "n".');
      }
      team._visited = row[1] == 'y';
      team.visitingJudgesNotes = row[2];
    }
    notifyListeners();
  }

  String pitVisitNotesToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Team number', // numeric
      'Visited?', // 'y' or 'n'
      'Assigned judging team', // string
      'Pit visit nominations', // comma-separated string (ambiguous if any awards have commas in their name)
    ]);
    for (final Team team in _teams) {
      data.add([
        team.number,
        team.visited ? 'y' : 'n',
        team.visitingJudgesNotes,
        team.shortlistedAwardsWithPitVisits.map((Award award) => award.name).join(', '),
      ]);
    }
    return const ListToCsvConverter().convert(data);
  }

  void addToShortlist(Award award, Team team, ShortlistEntry entry) {
    _shortlists[award]!._add(team, entry);
    team._addToShortlist(award, entry);
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
    if (inspireAward != null && team._shortlistedAdvancingCategories.length < minimumInspireCategories) {
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
      addOverride(award, team, rank);
    }
    notifyListeners();
  }

  String finalistOverridesToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Award name', // string
      'Team number', // numeric
      'Rank', // numeric
    ]);
    for (final Award award in _overrides.keys) {
      for (final int rank in _overrides[award]!.keys) {
        for (final Team team in _overrides[award]![rank]!) {
          data.add([
            award.name,
            team.number,
            rank,
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
        team.inspireEligible ? '' : 'Ineligible',
      ]);
    }
    data.insert(0, [
      'Team', // numeric
      for (final Award award in awards) award.name, // numeric (rank) or ""
      'Category Count',
      'Rank Score',
      'Eligibility',
    ]);
    data.insert(1, [
      '',
      for (final Award award in awards) award.category,
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
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool overridden) in finalists) {
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
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool overridden) in finalists) {
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

  Future<void> importConfiguration(List<int> csvFile) async {
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.isEmpty) {
      throw const FormatException('Configuration file corrupted.');
    }
    for (List<dynamic> row in csvData) {
      switch (row[0]) {
        case 'award order':
          _awardOrder = switch (row[1]) {
            'categories' => AwardOrder.categories,
            'rank' => AwardOrder.rank,
            _ => AwardOrder.categories,
          };
      }
    }
    notifyListeners();
  }

  void resetConfiguration() {
    _awardOrder = AwardOrder.categories;
    notifyListeners();
  }

  String configurationToCsv() {
    final List<List<Object?>> data = [];
    data.add([
      'Setting', // string
      'Value', // varies
    ]);
    data.add([
      'award order',
      switch (_awardOrder) {
        AwardOrder.categories => 'categories',
        AwardOrder.rank => 'rank',
      }
    ]);
    return const ListToCsvConverter().convert(data);
  }

  static const String filenameTeams = 'teams.csv';
  static const String filenameAwards = 'awards.csv';
  static const String filenamePitVisitNotes = 'pit visit notes.csv';
  static const String filenameShortlists = 'shortlists.csv';
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
        if (zip.findFile(filenameFinalistOverrides) != null) {
          await importFinalistOverrides(zip.findFile(filenameFinalistOverrides)!.content);
        }
        if (zip.findFile(filenameConfiguration) == null) {
          resetConfiguration();
        } else {
          await importConfiguration(zip.findFile(filenameConfiguration)!.content);
        }
        _lastAutosaveMessage = 'Imported event state.';
      } catch (e) {
        _clearTeams();
        _clearAwards();
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
          'The following files describe the event state: "$filenameTeams", "$filenameAwards", "$filenameShortlists", and "$filenamePitVisitNotes".\n'
          'The "$filenameFinalistOverrides" file contains any award finalists overrides that are in effect.\n'
          'The "$filenameConfiguration" file contains settings for the Judge Advisor Assistant app that do not affect the event itself.\n'
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
    zip.addFile(ArchiveFile(filenamePitVisitNotes, -1, utf8.encode(pitVisitNotesToCsv())));
    zip.addFile(ArchiveFile(filenameFinalistOverrides, -1, utf8.encode(finalistOverridesToCsv())));
    zip.addFile(ArchiveFile(filenameConfiguration, -1, utf8.encode(configurationToCsv())));
    zip.addFile(ArchiveFile(filenameInspireCandidates, -1, utf8.encode(inspireCandiatesToCsv())));
    zip.addFile(ArchiveFile(filenameFinalistsTable, -1, utf8.encode(finalistTablesToCsv())));
    zip.addFile(ArchiveFile(filenameFinalistsLists, -1, utf8.encode(finalistListsToCsv())));
    zip.endEncode();
    output.closeSync();
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
    if (!_loading && !_autosaving) {
      _dirty = true;
      _autosaveTimer?.cancel();
      _autosaveTimer = Timer(const Duration(seconds: 5), _autosave);
      if (_lastAutosave == null) {
        _lastAutosaveMessage = 'Not yet autosaved.';
      }
    }
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
