import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/constants.dart';
import '../utils/io.dart';
import '../model/competition.dart';
import '../widgets/cells.dart';
import '../widgets/widgets.dart';

class PitVisitsPane extends StatefulWidget {
  const PitVisitsPane({super.key, required this.competition});

  final Competition competition;

  @override
  State<PitVisitsPane> createState() => _PitVisitsPaneState();

  static List<Award> computeAffectedAwards(Competition competition) {
    return competition.awardsView.where(Award.needsExtraPitVisitPredicate).toList();
  }

  static Future<void> exportPitVisitsHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    final List<Award> relevantAwards = computeAffectedAwards(competition);
    final StringBuffer page = createHtmlPage(competition, 'Pit Visits', now);
    if (competition.teamsView.isEmpty) {
      page.writeln('<p>No teams loaded.');
    } else {
      page.writeln('<table>');
      page.writeln('<thead>');
      page.writeln('<tr>');
      page.writeln('<th>Team');
      for (final Award award in relevantAwards) {
        page.writeln('<th>${escapeHtml(award.name)}${award.pitVisits == PitVisit.maybe ? "*" : ""}');
      }
      page.writeln('<th>Notes');
      page.writeln('<tbody>');
      for (final Team team in competition.teamsView) {
        page.writeln('<tr>');
        page.writeln('<td>${team.number} <i>${escapeHtml(team.name)}</i>');

        for (final Award award in relevantAwards) {
          page.writeln('<td>${team.shortlistsView.keys.contains(award) ? "Yes" : ""}');
        }
        List<String> notes = [];
        if (team.visited == competition.expectedPitVisits) {
          notes.add('Visited. ');
        } else if (team.visited > 0) {
          notes.add('Visited ${team.visited}/${competition.expectedPitVisits} times. ');
        }
        if (team.visitingJudgesNotes.isNotEmpty) {
          notes.add(team.visitingJudgesNotes);
        }
        List<Award> others = team.shortlistedAwardsWithPitVisits.toList();
        if (others.isNotEmpty) {
          notes.add(
            '${team.visitingJudgesNotes.isEmpty ? '' : '; will also be seen by: '}' '${others.map((Award award) => award.name).join(', ')}.',
          );
        }
        page.writeln('<td>${notes.map(escapeHtml).join().trim()}');
      }
      page.writeln('</table>');
      if (relevantAwards.where((Award award) => award.pitVisits == PitVisit.maybe).isNotEmpty) {
        page.writeln('<p><small>* This award may involve pit visits.</small>');
      }
    }
    return exportHTML(competition, 'pit_visits', now, page.toString());
  }
}

class _PitVisitsPaneState extends State<PitVisitsPane> {
  final Set<Team> _legacyTeams = <Team>{};

  (List<Team>, int, int, int, int, int, int) computeAffectedTeams({
    required bool showAutovisitedTeams,
    required bool showExhibitionTeams,
    required int minVisits,
    required int maxVisits}) {
    final List<Team> teams = [];
    int totalCount = 0;
    int visitedCount = 0;
    int unvisitedNominatedCount = 0;
    int unvisitedAssignedCount = 0;
    int unvisitedRemainingCount = 0;
    int exhibitionTeams = 0;
    for (Team team in widget.competition.teamsView) {
      totalCount += 1;
      if (team.inspireStatus == InspireStatus.exhibition) {
        exhibitionTeams += 1;
        if (showExhibitionTeams) {
          teams.add(team);
        }
        continue;
      } else {
        final bool hasSufficientAutomaticPitVisits = team.shortlistsView.keys
          .where((Award award) => award.pitVisits == PitVisit.yes)
          .length >= widget.competition.expectedPitVisits;
        if (team.visited == widget.competition.expectedPitVisits) {
          visitedCount += 1;
        } else if (hasSufficientAutomaticPitVisits) {
          unvisitedNominatedCount += 1;
        } else if (team.visitingJudgesNotes.isNotEmpty) {
          unvisitedAssignedCount += 1;
        } else {
          unvisitedRemainingCount += 1;
        }
        if (((team.visited >= minVisits && min(team.visited, widget.competition.expectedPitVisits) <= maxVisits) || _legacyTeams.contains(team)) &&
            (showAutovisitedTeams || !hasSufficientAutomaticPitVisits)) {
          teams.add(team);
        }
      }
    }
    return (
      teams,
      totalCount,
      visitedCount,
      unvisitedNominatedCount,
      unvisitedAssignedCount,
      unvisitedRemainingCount,
      exhibitionTeams,
    );
  }

  void _handleVisitedChanged(Team value) {
    _legacyTeams.add(value);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) {
        final (
          List<Team> teams,
          int totalCount,
          int visitedCount,
          int unvisitedNominatedCount,
          int unvisitedAssignedCount,
          int unvisitedRemainingCount,
          int exhibitionTeams,
        ) = computeAffectedTeams(
          showAutovisitedTeams: widget.competition.pitVisitsIncludeAutovisitedTeams,
          showExhibitionTeams: widget.competition.pitVisitsIncludeExhibitionTeams,
          minVisits: widget.competition.pitVisitsViewMinVisits,
          maxVisits: widget.competition.pitVisitsViewMaxVisits,
        );
        assert(totalCount == visitedCount + unvisitedNominatedCount + unvisitedAssignedCount + unvisitedRemainingCount + exhibitionTeams);
        final List<Award> relevantAwards = PitVisitsPane.computeAffectedAwards(widget.competition);
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Heading(title: '3. Pit Visits'),
            if (totalCount == 0)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No teams loaded. Use the Setup pane to import a teams list.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (widget.competition.awardsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No awards loaded. Use the Setup pane to import an awards list.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (totalCount > 0)
              ScrollableRegion(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0.0, spacing, 0.0, 0.0),
                      child: Text('Summary:', style: bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                      child: Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        defaultVerticalAlignment: TableCellVerticalAlignment.top,
                        children: [
                          TableRow(
                            children: [
                              const SizedBox.shrink(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0.0, 0.0, spacing, 0.0),
                                child: Text('$visitedCount', textAlign: TextAlign.right),
                              ),
                              Text(
                                widget.competition.expectedPitVisits == 1 ? 'Visited teams' : 'Sufficiently visited teams',
                                softWrap: true,
                                overflow: TextOverflow.clip,
                              ),
                            ],
                          ),
                          TableRow(
                            children: [
                              const SizedBox.shrink(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0.0, 0.0, spacing, 0.0),
                                child: Text('$unvisitedNominatedCount', textAlign: TextAlign.right),
                              ),
                              Text(
                                'Teams with ${widget.competition.expectedPitVisits == 1 ? '' : 'sufficiently '}nominations that involve pit visits that are not yet ${widget.competition.expectedPitVisits == 1 ? '' : 'sufficiently '}marked as visited',
                                softWrap: true,
                                overflow: TextOverflow.clip,
                              ),
                            ],
                          ),
                          TableRow(
                            children: [
                              const SizedBox.shrink(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0.0, 0.0, spacing, 0.0),
                                child: Text('$unvisitedAssignedCount', textAlign: TextAlign.right),
                              ),
                              Text(
                                widget.competition.expectedPitVisits == 1
                                    ? 'Teams without such nominations but with judges assigned for a visit'
                                    : 'Teams without sufficient nominations that involve pit visits but with one or more judges assigned',
                                softWrap: true,
                                overflow: TextOverflow.clip,
                              ),
                            ],
                          ),
                          if (exhibitionTeams > 0)
                            TableRow(
                              children: [
                                const SizedBox.shrink(),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(spacing, 0.0, spacing, 0.0),
                                  child: Text('$exhibitionTeams', textAlign: TextAlign.right),
                                ),
                                const Text(
                                  'Exhibition teams',
                                  softWrap: true,
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                          TableRow(
                            children: [
                              const Text('+'),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(spacing, 0.0, spacing, 0.0),
                                child: Text('$unvisitedRemainingCount', textAlign: TextAlign.right),
                              ),
                              const Text(
                                'Remaining teams',
                                softWrap: true,
                                overflow: TextOverflow.clip,
                              ),
                            ],
                          ),
                          const TableRow(
                            decoration: BoxDecoration(border: Border(top: BorderSide(width: 1.0))),
                            children: [
                              SizedBox(height: 1.0),
                              SizedBox(height: 1.0),
                              SizedBox(height: 1.0),
                            ],
                          ),
                          TableRow(
                            children: [
                              const SizedBox.shrink(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(spacing, 0.0, spacing, 0.0),
                                child: Text('$totalCount', textAlign: TextAlign.right),
                              ),
                              const Text(
                                'Total teams',
                                softWrap: true,
                                overflow: TextOverflow.clip,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (totalCount > 0)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text('Details:', style: bold),
              ),
            if (totalCount > 0)
              CheckboxRow(
                checked: widget.competition.pitVisitsIncludeAutovisitedTeams,
                onChanged: (bool? value) {
                  widget.competition.pitVisitsIncludeAutovisitedTeams = value!;
                  setState(() {
                    _legacyTeams.clear();
                  });
                },
                tristate: false,
                label: widget.competition.expectedPitVisits == 1
                    ? 'Include teams that are nominated for an award that always involves a pit visit from the judges.'
                    : 'Include teams that are nominated for sufficient awards that involve pit visits from the judges to reach the expected pit visit count.',
              ),
            if (exhibitionTeams > 0)
              CheckboxRow(
                checked: widget.competition.pitVisitsIncludeExhibitionTeams,
                onChanged: (bool? value) {
                  widget.competition.pitVisitsIncludeExhibitionTeams = value!;
                  setState(() {
                    _legacyTeams.clear();
                  });
                },
                tristate: false,
                label: 'Include ${count(exhibitionTeams, 'exhibition team')}.',
              ),
            if (totalCount > 0)
              if (widget.competition.expectedPitVisits > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(indent, 0, indent, 0),
                  child: Row(
                    children: [
                      Material(
                        type: MaterialType.transparency,
                        child: Checkbox(
                          value: widget.competition.pitVisitsViewMinVisits != 0 || widget.competition.pitVisitsViewMaxVisits != widget.competition.expectedPitVisits,
                          onChanged: (bool? value) {
                            widget.competition.pitVisitsViewMinVisits = 0;
                            if (value!) {
                              widget.competition.pitVisitsViewMaxVisits = widget.competition.expectedPitVisits - 1;
                            } else {
                              widget.competition.pitVisitsViewMaxVisits = widget.competition.expectedPitVisits;
                            }
                            setState(() {
                              _legacyTeams.clear();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          softWrap: true,
                          overflow: TextOverflow.clip,
                          TextSpan(
                            text: 'Filter view to only show teams that have been visited between ',
                            children: <InlineSpan>[
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: VisitInput(
                                min: 0,
                                max: widget.competition.expectedPitVisits,
                                highlightThreshold: widget.competition.expectedPitVisits,
                                value: widget.competition.pitVisitsViewMinVisits,
                                onChanged: (int value) {
                                  widget.competition.pitVisitsViewMinVisits = value;
                                  if (widget.competition.pitVisitsViewMinVisits > widget.competition.pitVisitsViewMaxVisits) {
                                    widget.competition.pitVisitsViewMaxVisits = widget.competition.pitVisitsViewMinVisits;
                                  }
                                  setState(() {
                                    _legacyTeams.clear();
                                  });
                                },
                              ),
                            ),
                            TextSpan(text: ' and '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: VisitInput(
                                min: 0,
                                max: widget.competition.expectedPitVisits,
                                highlightThreshold: widget.competition.expectedPitVisits,
                                value: widget.competition.pitVisitsViewMaxVisits,
                                onChanged: (int value) {
                                  widget.competition.pitVisitsViewMaxVisits = value;
                                  if (widget.competition.pitVisitsViewMaxVisits < widget.competition.pitVisitsViewMinVisits) {
                                    widget.competition.pitVisitsViewMinVisits = widget.competition.pitVisitsViewMaxVisits;
                                  }
                                  setState(() {
                                    _legacyTeams.clear();
                                  });
                                },
                              ),
                            ),
                            TextSpan(text: ' times.'),
                          ],
                        )),
                      ),
                    ],
                  ),
                )
              else
                CheckboxRow(
                  checked: widget.competition.pitVisitsViewMinVisits != 0
                      ? null
                      : widget.competition.pitVisitsViewMaxVisits == 0
                        ? _legacyTeams.isEmpty
                            ? false
                            : null
                        : true,
                  onChanged: (bool? value) {
                    if (value!) {
                      widget.competition.pitVisitsViewMinVisits = 0;
                      widget.competition.pitVisitsViewMaxVisits = widget.competition.expectedPitVisits;
                    } else {
                      widget.competition.pitVisitsViewMinVisits = 0;
                      widget.competition.pitVisitsViewMaxVisits = 0;
                    }
                    setState(() {
                      _legacyTeams.clear();
                    });
                  },
                  tristate: widget.competition.pitVisitsViewMinVisits != 0 || (widget.competition.pitVisitsViewMaxVisits == 0 && _legacyTeams.isNotEmpty),
                  label: 'Include teams that are already marked as visited.',
                ),
            if (totalCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(0.0, spacing, 0.0, 0.0),
                child: ScrollableRegion(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View:'),
                      SizedBox(width: indent),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Grid'),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Full list'),
                          ),
                        ],
                        selected: <bool>{widget.competition.pitVisitsShowQuickGrid},
                        onSelectionChanged: (Set<bool> newSelection) {
                          widget.competition.pitVisitsShowQuickGrid = newSelection.single;
                          setState(() {
                            _legacyTeams.clear();
                          });
                        },
                      ),
                    ],
                  )
                ),
              ),
            if (widget.competition.teamsView.isNotEmpty && widget.competition.awardsView.isNotEmpty && teams.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No teams match the current filter.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (teams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text(
                  widget.competition.expectedPitVisits == 1
                   ? !widget.competition.pitVisitsIncludeAutovisitedTeams
                      ? widget.competition.pitVisitsViewMinVisits == 0 && widget.competition.pitVisitsViewMaxVisits == 0
                         ? 'The following teams have not been shortlisted for any awards that always involve pit visits, and have not yet been visited:'
                         : 'The following teams have not been shortlisted for any awards that always involve pit visits:'
                      : widget.competition.pitVisitsViewMinVisits == 0 && widget.competition.pitVisitsViewMaxVisits == 0
                         ? 'The following teams have not yet been visited:'
                         : exhibitionTeams > 0 && !widget.competition.pitVisitsIncludeExhibitionTeams
                           ? 'All teams eligible for awards:'
                           : 'All teams:'
                   : !widget.competition.pitVisitsIncludeAutovisitedTeams ||
                     widget.competition.pitVisitsViewMinVisits != 0 ||
                     widget.competition.pitVisitsViewMaxVisits != widget.competition.expectedPitVisits
                       ? 'Filtered teams:'
                       : exhibitionTeams > 0 && !widget.competition.pitVisitsIncludeExhibitionTeams
                         ? 'All teams eligible for awards:'
                         : 'All teams:',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (teams.isNotEmpty && !widget.competition.pitVisitsShowQuickGrid)
              PitVisitsListView(
                relevantAwards: relevantAwards,
                competition: widget.competition,
                teams: teams, 
                legacyTeams: _legacyTeams,
                onVisitedChanged: _handleVisitedChanged,
              ),
            if (!widget.competition.pitVisitsShowQuickGrid && widget.competition.teamsView.isNotEmpty && relevantAwards.where((Award award) => award.pitVisits == PitVisit.maybe).isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, 0.0),
                child: Text('* This award may involve pit visits.', style: italic),
              ),
            if (teams.isNotEmpty && widget.competition.pitVisitsShowQuickGrid)
              PitVisitsGridView(
                relevantAwards: relevantAwards,
                competition: widget.competition,
                teams: teams, 
                legacyTeams: _legacyTeams,
                onVisitedChanged: _handleVisitedChanged,
              ),
            const SizedBox(height: indent),
          ],
        );
      },
    );
  }
}

class PitVisitsListView extends StatelessWidget {
  const PitVisitsListView({
    super.key,
    required this.relevantAwards,
    required this.competition,
    required this.teams,
    required Set<Team> legacyTeams,
    required this.onVisitedChanged,
  }) : _legacyTeams = legacyTeams;

  final List<Award> relevantAwards;
  final Competition competition;
  final List<Team> teams;
  final Set<Team> _legacyTeams;
  final ValueSetter<Team> onVisitedChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, spacing, 0.0, 0.0),
      child: HorizontalScrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, 0.0),
            child: Table(
              border: const TableBorder.symmetric(
                inside: BorderSide(),
              ),
              columnWidths: <int, TableColumnWidth>{
                relevantAwards.length + 1: const MaxColumnWidth(IntrinsicCellWidth(), IntrinsicCellWidth(row: 1))
              },
              defaultColumnWidth: const IntrinsicCellWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TableRow(
                  children: [
                    Cell(Text('#', style: bold), prototype: Text('${competition.longestTeamNumber}${competition.pitVisitsIncludeExhibitionTeams ? " WW" : ""}')),
                    for (final Award award in relevantAwards)
                      ListenableBuilder(
                        listenable: award,
                        builder: (BuildContext context, Widget? child) {
                          return ColoredBox(
                            color: award.color,
                            child: Cell(
                              Text(
                                '${award.name}${award.pitVisits == PitVisit.maybe ? "*" : ""}',
                                style: bold.copyWith(
                                  color: textColorForColor(award.color),
                                ),
                              ),
                              prototype: const Text('Yes'),
                            ),
                          );
                        },
                      ),
                    const Cell(Text('Visited? ✎_', style: bold)),
                    if (competition.pitVisitsIncludeAutovisitedTeams) const Cell(Text('Nominations for awards with pit visits')),
                  ],
                ),
                for (final Team team in teams)
                  TableRow(
                    decoration: (team.visited < competition.pitVisitsViewMinVisits || (team.visited > competition.pitVisitsViewMaxVisits && competition.pitVisitsViewMaxVisits < competition.expectedPitVisits)) &&
                            _legacyTeams.contains(team)
                        ? BoxDecoration(color: Colors.grey.shade100)
                        : null,
                    children: [
                      Tooltip(
                        message: team.name,
                        child: Cell(
                          Text('${team.number}'),
                        icons: team.inspireStatus == InspireStatus.exhibition
                            ? [
                                Tooltip(
                                  message: 'Team is an exhibition team and is not eligible for any awards!',
                                  child: Icon(
                                    Symbols.cruelty_free, // bunny
                                    size: DefaultTextStyle.of(context).style.fontSize,
                                  ),
                                ),
                              ]
                            : null,
                        ),
                      ),
                      for (final Award award in relevantAwards)
                        Cell(
                          Text(team.shortlistsView.keys.contains(award) ? 'Yes' : ''),
                        ),
                      VisitedCell(
                        competition: competition,
                        team: team,
                        onVisitedChanged: onVisitedChanged,
                      ),
                      if (competition.pitVisitsIncludeAutovisitedTeams)
                        Cell(Text(team.shortlistedAwardsWithPitVisits.map((Award award) => award.name).join(', '))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PitVisitsGridView extends StatelessWidget {
  const PitVisitsGridView({
    super.key,
    required this.relevantAwards,
    required this.competition,
    required this.teams,
    required Set<Team> legacyTeams,
    required this.onVisitedChanged,
  }) : _legacyTeams = legacyTeams;

  final List<Award> relevantAwards;
  final Competition competition;
  final List<Team> teams;
  final Set<Team> _legacyTeams;
  final ValueSetter<Team> onVisitedChanged;

  @override
  Widget build(BuildContext context) {
    double fontSize = DefaultTextStyle.of(context).style.fontSize! * 0.66;
    return Padding(
      padding: const EdgeInsets.fromLTRB(indent, spacing, indent, 0.0),
      child: Wrap(
        runSpacing: spacing,
        children: [
          for (final Team team in teams)
            SizedBox(
              key: ObjectKey(team),
              width: spacing * 12,
              height: spacing * 16,
              child: Container(
                foregroundDecoration: BoxDecoration(
                  border: Border.all(width: 2.0),
                ),
                decoration: BoxDecoration(
                   color: (team.visited < competition.pitVisitsViewMinVisits || (team.visited > competition.pitVisitsViewMaxVisits && competition.pitVisitsViewMaxVisits < competition.expectedPitVisits)) &&
                            _legacyTeams.contains(team) ? Colors.grey.shade100 : null,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ColoredBox(
                        color: team.visited == 0 ? Colors.red.shade200 : team.visited < competition.expectedPitVisits ? Colors.yellow.shade100 : Colors.green.shade100,
                        child: Center(
                          child: Tooltip(
                            message: team.name,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text('${team.number}', style: bold, textAlign: TextAlign.center),
                                if (team.inspireStatus == InspireStatus.exhibition)
                                  Tooltip(
                                    message: 'Team is an exhibition team and is not eligible for any awards!',
                                    child: Icon(
                                      Symbols.cruelty_free, // bunny
                                      size: DefaultTextStyle.of(context).style.fontSize,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: BoxBorder.symmetric(
                            horizontal: BorderSide(width: 2.0),
                          )
                        ),
                        child: Center(
                          child: Material(
                            type: MaterialType.transparency,
                            child: VisitInput(
                              min: 0,
                              highlightThreshold: competition.expectedPitVisits,
                              value: team.visited,
                              onChanged: (int value) {
                                competition.updateTeamVisited(team, visited: value);
                                onVisitedChanged.call(team);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(spacing / 2.0),
                        child: Center(
                          child: Text(
                            team.shortlistedAwardsWithPitVisits.map((Award award) => award.name).join(', '),
                            softWrap: true,
                            overflow: TextOverflow.clip,
                            textAlign: TextAlign.center,
                            style: italic.copyWith(fontSize: fontSize, height: kTextHeightNone),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
