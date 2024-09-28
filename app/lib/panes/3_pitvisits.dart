import 'package:flutter/material.dart';

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
        if (team.visited) {
          notes.add('Visited. ');
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

  (List<Team>, int, int, int, int, int) computeAffectedTeams({required bool filterTeams, required bool hideVisited}) {
    final List<Team> teams = [];
    int totalCount = 0;
    int visitedCount = 0;
    int unvisitedNominatedCount = 0;
    int unvisitedAssignedCount = 0;
    int unvisitedRemainingCount = 0;
    for (Team team in widget.competition.teamsView) {
      final bool hasPitVisit = team.shortlistsView.keys.any(
        (Award award) => award.pitVisits == PitVisit.yes,
      );
      totalCount += 1;
      if (team.visited) {
        visitedCount += 1;
      } else if (hasPitVisit) {
        unvisitedNominatedCount += 1;
      } else if (team.visitingJudgesNotes.isNotEmpty) {
        unvisitedAssignedCount += 1;
      } else {
        unvisitedRemainingCount += 1;
      }
      if ((!hideVisited || !team.visited || _legacyTeams.contains(team)) && (!filterTeams || !hasPitVisit)) {
        teams.add(team);
      }
    }
    return (
      teams,
      totalCount,
      visitedCount,
      unvisitedNominatedCount,
      unvisitedAssignedCount,
      unvisitedRemainingCount,
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
        ) = computeAffectedTeams(
          filterTeams: widget.competition.pitVisitsExcludeAutovisitedTeams,
          hideVisited: widget.competition.pitVisitsHideVisitedTeams,
        );
        assert(totalCount == visitedCount + unvisitedNominatedCount + unvisitedAssignedCount + unvisitedRemainingCount);
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
                              const Text(
                                'Visited teams',
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
                              const Text(
                                'Teams with nominations that involve pit visits that are not marked visited',
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
                              const Text(
                                'Teams without such nominations but with judges assigned for a visit',
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
                checked: !widget.competition.pitVisitsExcludeAutovisitedTeams,
                onChanged: (bool? value) {
                  widget.competition.pitVisitsExcludeAutovisitedTeams = !value!;
                  setState(() {
                    _legacyTeams.clear();
                  });
                },
                tristate: false,
                label: 'Include teams that are nominated for an award that always involves a pit visit from the judges.',
              ),
            if (totalCount > 0)
              CheckboxRow(
                checked: widget.competition.pitVisitsHideVisitedTeams
                    ? _legacyTeams.isEmpty
                        ? false
                        : null
                    : true,
                onChanged: (bool? value) {
                  widget.competition.pitVisitsHideVisitedTeams = !value!;
                  setState(() {
                    _legacyTeams.clear();
                  });
                },
                tristate: widget.competition.pitVisitsHideVisitedTeams && _legacyTeams.isNotEmpty,
                label: 'Include teams that are already marked as visited.',
              ),
            if (widget.competition.teamsView.isNotEmpty && widget.competition.awardsView.isNotEmpty && teams.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  widget.competition.pitVisitsExcludeAutovisitedTeams
                      ? widget.competition.pitVisitsHideVisitedTeams
                          ? 'All of the teams that have not been shortlisted for awards that always involve pit visits have been visited.'
                          : 'All of the teams have been shortlisted for awards that always involve pit visits.'
                      : widget.competition.pitVisitsHideVisitedTeams
                          ? 'All of the teams have been visited.'
                          : () {
                              assert(false, 'internal error with teams filtering');
                              return '';
                            }(),
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (teams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  widget.competition.pitVisitsExcludeAutovisitedTeams
                      ? widget.competition.pitVisitsHideVisitedTeams
                          ? 'The following teams have not been shortlisted for any awards that always involve pit visits, and have not yet been visited:'
                          : 'The following teams have not been shortlisted for any awards that always involve pit visits:'
                      : widget.competition.pitVisitsHideVisitedTeams
                          ? 'The following teams have not yet been visited:'
                          : 'All teams:',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (teams.isNotEmpty)
              Padding(
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
                              const Cell(Text('#', style: bold), prototype: Text('000000')),
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
                              if (!widget.competition.pitVisitsExcludeAutovisitedTeams) const Cell(Text('Nominations for awards with pit visits')),
                            ],
                          ),
                          for (final Team team in teams)
                            TableRow(
                              decoration: widget.competition.pitVisitsHideVisitedTeams && team.visited && _legacyTeams.contains(team)
                                  ? BoxDecoration(color: Colors.grey.shade100)
                                  : null,
                              children: [
                                Tooltip(
                                  message: team.name,
                                  child: Cell(
                                    Text('${team.number}'),
                                  ),
                                ),
                                for (final Award award in relevantAwards)
                                  Cell(
                                    Text(team.shortlistsView.keys.contains(award) ? 'Yes' : ''),
                                  ),
                                VisitedCell(
                                  competition: widget.competition,
                                  team: team,
                                  onVisitedChanged: _handleVisitedChanged,
                                ),
                                if (!widget.competition.pitVisitsExcludeAutovisitedTeams)
                                  Cell(Text(team.shortlistedAwardsWithPitVisits.map((Award award) => award.name).join(', '))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.competition.teamsView.isNotEmpty && relevantAwards.where((Award award) => award.pitVisits == PitVisit.maybe).isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, 0.0),
                child: Text('* This award may involve pit visits.', style: italic),
              ),
            const SizedBox(height: indent),
          ],
        );
      },
    );
  }
}
