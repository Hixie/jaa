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
    required this.advancing,
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
  final bool advancing;
  final int rank;
  final int count;
  final String category;
  final bool spreadTheWealth;
  final bool placement;
  final PitVisit pitVisits;
  final Color color;

  // predicate for List.where clauses
  static bool needsShowTheLove(Award award) {
    return award.pitVisits != PitVisit.yes && !award.isInspire;
  }
}

class Team extends ChangeNotifier implements Comparable<Team> {
  Team({
    required this.number,
    required this.name,
    required this.city,
    required this.inspireWins,
  });

  final int number;
  final String name;
  final String city;
  final int inspireWins;

  final Set<Award> _shortlists = <Award>{};
  late final UnmodifiableSetView<Award> shortlistsView = UnmodifiableSetView(_shortlists);

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

  void _addToShortlist(Award award) {
    _shortlists.add(award);
    notifyListeners();
  }

  void _removeFromShortlist(Award award) {
    _shortlists.remove(award);
    notifyListeners();
  }

  void _clearShortlists() {
    _shortlists.clear();
    notifyListeners();
  }
}

typedef ShortlistEntry = ({String room});

class Shortlist extends ChangeNotifier {
  final Map<Team, ShortlistEntry> entries = <Team, ShortlistEntry>{};

  void _add(Team team, ShortlistEntry entry) {
    assert(!entries.containsKey(team));
    entries[team] = entry;
    notifyListeners();
  }

  void _remove(Team team) {
    assert(entries.containsKey(team));
    entries.remove(team);
    notifyListeners();
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
    _shortlists.clear();
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
        if (row[3] is! int || (row[3] < 0)) {
          throw FormatException('Parse error: "${row[3]}" is not a valid number of Inspire award wins.');
        }
        final Team team = Team(number: row[0] as int, name: '${row[1]}', city: '${row[2]}', inspireWins: row[3] as int);
        _teams.add(team);
        if (team.inspireWins > 0) {
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
      for (List<dynamic> row in csvData.skip(1)) {
        if (row.length < 8) {
          throw const FormatException('File contains a row with less than eight cells.');
        }
        if (row[2] is! int || (row[2] < 0)) {
          throw FormatException('Parse error: "${row[2]}" is not a valid award count.');
        }
        String colorAsString = '${row[7]}';
        if (!colorAsString.startsWith('#') || colorAsString.length != 7) {
          throw FormatException('Parse error: "$colorAsString" is not a valid color (e.g. "#FFFF00").');
        }
        int? colorAsInt = int.tryParse(colorAsString.substring(1), radix: 16);
        if (colorAsInt == null) {
          throw FormatException('Parse error: "$colorAsString" is not a valid color (e.g. "#00FFFF").');
        }
        bool isAdvancing = row[1] == 'Advancing';
        bool isInspire = !seenInspire && isAdvancing;
        seenInspire = seenInspire || isInspire;
        PitVisit pitVisit = switch ('${row[6]}') {
          'y' => PitVisit.yes,
          'n' => PitVisit.no,
          'maybe' => PitVisit.maybe,
          final String s => throw FormatException('Parse error: "$s" is not a valid value for the Pit Visits column.'),
        };
        final Award award = Award(
          name: '${row[0]}',
          isInspire: isInspire,
          advancing: isAdvancing,
          rank: rank,
          count: row[2] as int,
          category: '${row[3]}',
          spreadTheWealth: row[4] == 'y',
          placement: row[5] == 'y',
          pitVisits: pitVisit,
          color: Color(0xFF000000 | colorAsInt),
        );
        _awards.add(award);
        if (award.advancing) {
          _advancingAwards.add(award);
        } else {
          _nonAdvancingAwards.add(award);
        }
        _shortlists[award] = Shortlist();
        rank += 1;
      }
    } catch (e) {
      _clearAwards();
      rethrow;
    }
    notifyListeners();
  }

  void addToShortlist(Award award, Team team, ShortlistEntry entry) {
    _shortlists[award]!._add(team, entry);
    team._addToShortlist(award);
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
