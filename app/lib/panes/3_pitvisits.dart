import 'package:flutter/material.dart';

import '../constants.dart';
import '../io.dart';
import '../model/competition.dart';
import '../widgets.dart';

class PitVisitsPane extends StatelessWidget {
  const PitVisitsPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final List<Team> teams = computeAffectedTeams(competition);
        final List<Award> relevantAwards = computeAffectedAwards(competition);
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaneHeader(
              title: '3. Pit Visits',
              onHeaderButtonPressed: () => exportPitVisitsHTML(context, competition),
            ),
            if (competition.teamsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No teams loaded. Use the Setup pane to import a teams list.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (competition.awardsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No awards loaded. Use the Setup pane to import an awards list.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (competition.teamsView.isNotEmpty && competition.awardsView.isNotEmpty && teams.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'All of the teams have been shortlisted for awards that involve pit visits.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (teams.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'The following teams have not been shortlisted for any awards that always involve pit visits:',
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
                        border: TableBorder.symmetric(
                          inside: const BorderSide(),
                        ),
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          TableRow(
                            children: [
                              const Cell(Text('#', style: bold)),
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
                                      ),
                                    );
                                  },
                                ),
                              const Cell(Text('Visited? ✎_', style: bold)),
                            ],
                          ),
                          for (final Team team in teams)
                            TableRow(
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
                                Material(
                                  type: MaterialType.transparency,
                                  child: VisitedCell(team: team),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (relevantAwards.where((Award award) => award.pitVisits == PitVisit.maybe).isNotEmpty)
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

  static List<Team> computeAffectedTeams(Competition competition) {
    return competition.teamsView
        .where((Team team) => !team.shortlistsView.keys.any(
              (Award award) => award.pitVisits == PitVisit.yes,
            ))
        .toList();
  }

  static List<Award> computeAffectedAwards(Competition competition) {
    return competition.awardsView.where(Award.needsExtraPitVisitPredicate).toList();
  }

  static Future<void> exportPitVisitsHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    final List<Award> relevantAwards = computeAffectedAwards(competition);
    final StringBuffer page = createHtmlPage('Pit Visits', now);
    final List<Team> teams = computeAffectedTeams(competition);
    if (teams.isEmpty) {
      page.writeln('<p>All of the teams have been shortlisted for awards that involve pit visits.');
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
      for (final Team team in teams) {
        page.writeln('<tr>');
        page.writeln('<td>${team.number} <i>${escapeHtml(team.name)}</i>');

        for (final Award award in relevantAwards) {
          page.writeln('<td>${team.shortlistsView.keys.contains(award) ? "Yes" : ""}');
        }
        page.writeln('<td>${team.visited ? "Visited." : ""} ${escapeHtml(team.visitingJudgesNotes)}');
      }
      page.writeln('</table>');
      if (relevantAwards.where((Award award) => award.pitVisits == PitVisit.maybe).isNotEmpty) {
        page.writeln('<p><small>* This award may involve pit visits.</small>');
      }
    }
    return exportHTML(competition, 'pit_visits', now, page.toString());
  }
}
