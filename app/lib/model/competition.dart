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

import '../widgets.dart';
import '../colors.dart';

typedef AwardFinalistEntry = (Team?, Award?, int, {bool tied});

enum PitVisit { yes, no, maybe }

@immutable
class Award {
  const Award({
    required this.name,
    required this.isInspire,
    required this.isAdvancing,
    required this.rank,
    required this.count,
    required this.category,
    required this.isSpreadTheWealth,
    required this.isPlacement,
    required this.pitVisits,
    required this.color,
  });

  final String name;
  final bool isInspire;
  final bool isAdvancing;
  final int rank;
  final int count;
  final String category;
  final bool isSpreadTheWealth;
  final bool isPlacement;
  final PitVisit pitVisits;
  final Color color;

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
}

class Team extends ChangeNotifier implements Comparable<Team> {
  Team({
    required this.number,
    required this.name,
    required this.city,
    required this.inspireEligible,
  });

  final int number;
  final String name;
  final String city;
  final bool inspireEligible;

  late final UnmodifiableMapView<Award, ShortlistEntry> shortlistsView = UnmodifiableMapView(_shortlists);
  final Map<Award, ShortlistEntry> _shortlists = <Award, ShortlistEntry>{};

  late final Set<String> shortlistedAdvancingCategories = UnmodifiableSetView(_shortlistedAdvancingCategories);
  final Set<String> _shortlistedAdvancingCategories = <String>{};

  // only meaningful when compared to teams with the same number of shortlistedAdvancingCategories
  int? get rankScore => _rankScore;
  int? _rankScore;

  bool _visited = false;
  bool get visited => _visited;
  set visited(bool value) {
    if (value == _visited) {
      return;
    }
    _visited = value;
    notifyListeners();
  }

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
    int? rank,
    required bool lateEntry,
  })  : _nominator = nominator,
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
  final Map<Award, Shortlist> _shortlists = <Award, Shortlist>{};

  late final UnmodifiableListView<Team> teamsView = UnmodifiableListView<Team>(_teams);
  late final UnmodifiableListView<Team> previousInspireWinnersView = UnmodifiableListView<Team>(_previousInspireWinners);
  late final UnmodifiableListView<Award> awardsView = UnmodifiableListView<Award>(_awards);
  late final UnmodifiableListView<Award> advancingAwardsView = UnmodifiableListView<Award>(_advancingAwards);
  late final UnmodifiableListView<Award> nonAdvancingAwardsView = UnmodifiableListView<Award>(_nonAdvancingAwards);
  late final UnmodifiableMapView<Award, Shortlist> shortlistsView = UnmodifiableMapView<Award, Shortlist>(_shortlists);

  Award? _inspireAward;
  Award? get inspireAward => _inspireAward;

  (Map<int, Map<Team, Set<String>>>, List<String>) computeInspireCandidates() {
    final Map<int, Map<Team, Set<String>>> candidates = <int, Map<Team, Set<String>>>{};
    for (final Team team in teamsView) {
      final Set<String> categories = team.shortlistedAdvancingCategories;
      if (categories.length > 1) {
        final Map<Team, Set<String>> group = candidates.putIfAbsent(categories.length, () => <Team, Set<String>>{});
        group[team] = categories;
      }
    }
    final List<String> categories = awardsView.where(Award.isInspireQualifyingPredicate).map((Award award) => award.category).toSet().toList()..sort();
    return (candidates, categories);
  }

  List<(Award, List<AwardFinalistEntry>)> computeFinalists() {
    final Map<Team, (Award, int)> placedTeams = {};
    final Map<Award, List<Set<Team>>> awardCandidates = {};
    final Map<Award, List<AwardFinalistEntry>> finalists = {};
    for (final Award award in awardsView) {
      awardCandidates[award] = shortlistsView[award]?.asRankedList() ?? [];
      finalists[award] = [];
    }
    int rank = 1;
    bool stillPlacing = true;
    while (stillPlacing) {
      stillPlacing = false;
      for (final Award award in awardsView) {
        if (rank <= award.count) {
          final List<Set<Team>> candidatesList = awardCandidates[award]!;
          bool placedTeam = false;
          while (candidatesList.isNotEmpty && !placedTeam) {
            final Set<Team> candidates = candidatesList.removeAt(0);
            final Set<Team> alreadyPlaced = award.isSpreadTheWealth && !award.isInspire ? placedTeams.keys.toSet() : {};
            final Set<Team> ineligible = candidates.intersection(alreadyPlaced);
            final Set<Team> winners = candidates.difference(ineligible);
            if (ineligible.isNotEmpty) {
              for (Team team in ineligible) {
                final (Award oldAward, int oldRank) = placedTeams[team]!;
                finalists[award]!.add((team, oldAward, oldRank, tied: false));
              }
            }
            if (winners.isNotEmpty) {
              placedTeam = true;
              for (Team team in winners) {
                finalists[award]!.add((team, null, rank, tied: winners.length > 1));
                if (!award.isInspire || rank == 1) {
                  if (award.isSpreadTheWealth) {
                    placedTeams[team] = (award, rank);
                  }
                }
              }
            }
          }
          if (!placedTeam) {
            finalists[award]!.add((null, null, rank, tied: false));
          }
          if (rank < award.count) {
            stillPlacing = true;
          }
        }
      }
      rank += 1;
    }
    List<(Award, List<AwardFinalistEntry>)> result = [];
    for (Award award in awardsView) {
      result.add((award, finalists[award]!));
    }
    return result;
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
    notifyListeners();
  }

  Future<void> importTeams(List<int> csvFile) async {
    _clearTeams();
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.length <= 1) {
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
    for (final Team team in _teams) {
      team._clearShortlists();
    }
    notifyListeners();
  }

  Future<void> importAwards(List<int> csvFile) async {
    _clearAwards();
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.length <= 1) {
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
        final bool isSpreadTheWealth = _parseBool(row[4]);
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
        final Award award = Award(
          name: name,
          isInspire: isInspire,
          isAdvancing: isAdvancing,
          rank: rank,
          count: count,
          category: category,
          isSpreadTheWealth: isSpreadTheWealth,
          isPlacement: isPlacement,
          pitVisits: pitVisit,
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
      if (!seenInspire) {
        throw const FormatException('Parse error in awards file: None of the awards are advancing awards.');
      }
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
    ]);
    for (final Award award in _awards) {
      data.add([
        award.name,
        award.isAdvancing ? 'Advancing' : 'Non-Advancing',
        award.count,
        award.category,
        award.isSpreadTheWealth ? 'y' : 'n',
        award.isPlacement ? 'y' : 'n',
        switch (award.pitVisits) { PitVisit.yes => 'y', PitVisit.no => 'n', PitVisit.maybe => 'maybe' },
        '#${(award.color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      ]);
    }
    return const ListToCsvConverter().convert(data);
  }

  Future<void> importPitVisitNotes(List<int> csvFile) async {
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.length <= 1) {
      throw const FormatException('Pit visit notes are corrupted or missing.');
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
      team.visited = row[1] == 'y';
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
        team.shortlistsView.keys.where((Award award) => award.pitVisits == PitVisit.yes).map((Award award) => award.name).join(', '),
      ]);
    }
    return const ListToCsvConverter().convert(data);
  }

  void addToShortlist(Award award, Team team, ShortlistEntry entry) {
    _shortlists[award]!._add(team, entry);
    team._addToShortlist(award, entry);
    notifyListeners();
  }

  void removeFromShortlist(Award award, Team team) {
    _shortlists[award]!._remove(team);
    team._removeFromShortlist(award);
    notifyListeners();
  }

  Future<void> importShortlists(List<int> csvFile) async {
    final String csvText = utf8.decode(csvFile).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.length <= 1) {
      throw const FormatException('Shortlists file corrupted or missing.');
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
      addToShortlist(award, team, ShortlistEntry(lateEntry: row[4] == 'y', nominator: '${row[2]}', rank: rank));
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
    ]);
    for (final Award award in _awards) {
      for (final Team team in _shortlists[award]!.entriesView.keys) {
        final ShortlistEntry entry = _shortlists[award]!.entriesView[team]!;
        data.add([award.name, team.number, entry.nominator, entry.rank ?? '', entry.lateEntry ? 'y' : 'n']);
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
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied) in finalists) {
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
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied) in finalists) {
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

  static const String filenameTeams = 'teams.csv';
  static const String filenameAwards = 'awards.csv';
  static const String filenamePitVisitNotes = 'pit visit notes.csv';
  static const String filenameShortlists = 'shortlists.csv';
  static const String filenameInspireCandidates = 'inspire-candidates.csv';
  static const String filenameFinalistsTable = 'finalists-table.csv';
  static const String filenameFinalistsLists = 'finalists-lists.csv';

  Future<void> importEventState(PlatformFile zipFile) async {
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
      await importTeams(zip.findFile(filenameTeams)!.content);
      await importAwards(zip.findFile(filenameAwards)!.content);
      await importPitVisitNotes(zip.findFile(filenamePitVisitNotes)!.content);
      await importShortlists(zip.findFile(filenameShortlists)!.content);
    } catch (e) {
      _clearTeams();
      _clearAwards();
      rethrow;
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
          '\n'
          'Other files (such as this one) are included for information purposes only. They are not used when reimporting the event state.\n'
          'The "$filenameInspireCandidates" file contains a listing of each team\'s rankings for awards that contribute to Inspire award nominations.'
          'The "$filenameFinalistsTable" and "$filenameFinalistsLists" files contain the computed finalists at the time of the export.\n'
          '\n'
          'For more information see: https://github.com/Hixie/jaa/',
    ));
    zip.addFile(ArchiveFile.string(filenameTeams, teamsToCsv()));
    zip.addFile(ArchiveFile.string(filenameAwards, awardsToCsv()));
    zip.addFile(ArchiveFile.string(filenamePitVisitNotes, pitVisitNotesToCsv()));
    zip.addFile(ArchiveFile.string(filenameShortlists, shortlistsToCsv()));
    zip.addFile(ArchiveFile.string(filenameInspireCandidates, inspireCandiatesToCsv()));
    zip.addFile(ArchiveFile.string(filenameFinalistsTable, finalistTablesToCsv()));
    zip.addFile(ArchiveFile.string(filenameFinalistsLists, finalistListsToCsv()));
    zip.endEncode();
  }

  Timer? _autosaveTimer;
  bool _autosaving = false;
  bool get needsAutosave => _autosaveTimer != null;
  DateTime? _lastAutosave;
  DateTime? get lastAutosave => _lastAutosave;
  String _lastAutosaveMessage = 'Not yet autosaved.';
  String get lastAutosaveMessage => _lastAutosaveMessage;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_autosaving) {
      _autosaveTimer?.cancel();
      _autosaveTimer = Timer(const Duration(seconds: 5), _autosave);
    }
  }

  void _autosave() {
    _autosaving = true;
    _autosaveTimer = null;
    try {
      final String tempAutosave = path.join(autosaveDirectory.path, r'jaa_autosave.$$$');
      final String finalAutosave = path.join(autosaveDirectory.path, r'jaa_autosave.zip');
      exportEventState(tempAutosave);
      if (File(finalAutosave).existsSync()) {
        File(finalAutosave).deleteSync();
      }
      File(tempAutosave).renameSync(finalAutosave);
      _lastAutosave = DateTime.now();
      _lastAutosaveMessage = 'Autosaved to: $finalAutosave';
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
