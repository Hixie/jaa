import 'dart:collection';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

// TODO: this should save the current state to disk regularly so that it can be reloaded on startup automatically

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
    required this.spreadTheWealth,
    required this.placement,
    required this.pitVisits,
    required this.color,
  });

  final String name;
  final bool isInspire;
  final bool isAdvancing;
  final int rank;
  final int count;
  final String category;
  final bool spreadTheWealth;
  final bool placement;
  final PitVisit pitVisits;
  final Color color;

  // predicate for List.where clauses
  static bool needsShowTheLovePredicate(Award award) {
    return award.pitVisits != PitVisit.yes && !award.isInspire;
  }

  // predicate for List.where clauses
  static bool isNotInspirePredicate(Award award) {
    return !award.isInspire;
  }

  // predicate for List.where clauses
  static bool isRankedPredicate(Award award) {
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

  Future<void> importTeams(PlatformFile csvFile) async {
    _clearTeams();
    final String csvText = (await utf8.decodeStream(csvFile.readStream!)).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.length <= 1) {
      throw const FormatException('File does not contain any teams.');
    }
    try {
      for (List<dynamic> row in csvData.skip(1)) {
        if (row.length < 4) {
          throw const FormatException('File contains a row with less than four cells.');
        }
        if (row[0] is! int || (row[0] < 0)) {
          throw FormatException('Parse error: "${row[0]}" is not a valid team number.');
        }
        if ((row[3] is! int || (row[3] < 0)) && row[3] != 'y' && row[3] != 'n') {
          throw FormatException('Parse error: "${row[3]}" is not a valid number of Inspire award wins.');
        }
        final bool pastInspireWinner;
        if (row[3] == 'y') {
          pastInspireWinner = true;
        } else if (row[3] == 'n') {
          pastInspireWinner = false;
        } else {
          pastInspireWinner = row[3] as int > 0;
        }
        final Team team = Team(number: row[0] as int, name: '${row[1]}', city: '${row[2]}', inspireEligible: !pastInspireWinner);
        _teams.add(team);
        if (pastInspireWinner) {
          _previousInspireWinners.add(team);
        }
      }
    } catch (e) {
      _clearTeams();
      rethrow;
    }
    notifyListeners();
  }

  void _clearAwards() {
    _awards.clear();
    _advancingAwards.clear();
    _nonAdvancingAwards.clear();
    _shortlists.clear();
    for (final Team team in _teams) {
      team._clearShortlists();
    }
    notifyListeners();
  }

  Future<void> importAwards(PlatformFile csvFile) async {
    _clearAwards();
    final String csvText = (await utf8.decodeStream(csvFile.readStream!)).replaceAll('\r\n', '\n');
    final List<List<dynamic>> csvData = await compute(const CsvToListConverter(eol: '\n').convert, csvText);
    if (csvData.length <= 1) {
      throw const FormatException('File does not contain any awards.');
    }
    try {
      int rank = 1;
      bool seenInspire = false;
      final Set<String> names = <String>{};
      for (List<dynamic> row in csvData.skip(1)) {
        if (row.length < 8) {
          throw const FormatException('File contains a row with less than eight cells.');
        }
        final String name = '${row[0]}';
        if (name.isEmpty) {
          throw const FormatException('Parse error: An award has no name.');
        }
        if (names.contains(name)) {
          throw FormatException('Parse error: There are multiple awards named "$name".');
        }
        names.add(name);
        if (row[2] is! int || (row[2] < 0)) {
          throw FormatException('Parse error: "${row[2]}" is not a valid award count.');
        }
        final int count = row[2] as int;
        final bool isAdvancing = row[1] == 'Advancing';
        final bool isInspire = !seenInspire && isAdvancing;
        seenInspire = seenInspire || isInspire;
        final String category = '${row[3]}';
        if (isAdvancing && !isInspire && category.isEmpty) {
          throw FormatException('Parse error: "${row[0]}" is an advancing award but has no specified category.');
        }
        PitVisit pitVisit = switch ('${row[6]}') {
          'y' => PitVisit.yes,
          'n' => PitVisit.no,
          'maybe' => PitVisit.maybe,
          final String s => throw FormatException('Parse error: "$s" is not a valid value for the Pit Visits column.'),
        };
        final String colorAsString = '${row[7]}';
        if (!colorAsString.startsWith('#') || colorAsString.length != 7) {
          throw FormatException('Parse error: "$colorAsString" is not a valid color (e.g. "#FFFF00").');
        }
        int? colorAsInt = int.tryParse(colorAsString.substring(1), radix: 16);
        if (colorAsInt == null) {
          throw FormatException('Parse error: "$colorAsString" is not a valid color (e.g. "#00FFFF").');
        }
        final Award award = Award(
          name: name,
          isInspire: isInspire,
          isAdvancing: isAdvancing,
          rank: rank,
          count: count,
          category: category,
          spreadTheWealth: row[4] == 'y',
          placement: row[5] == 'y',
          pitVisits: pitVisit,
          color: Color(0xFF000000 | colorAsInt),
        );
        _awards.add(award);
        if (award.isAdvancing) {
          _advancingAwards.add(award);
        } else {
          _nonAdvancingAwards.add(award);
        }
        _shortlists[award] = Shortlist();
        rank += 1;
      }
      if (!seenInspire) {
        throw const FormatException('Parse error: None of the awards are advancing awards.');
      }
    } catch (e) {
      _clearAwards();
      rethrow;
    }
    notifyListeners();
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
