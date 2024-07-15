import 'package:flutter/material.dart';
import 'package:jaa/widgets/awards.dart';

import '../utils/constants.dart';
import '../exporters.dart';
import '../utils/io.dart';
import '../model/competition.dart';
import '../panes/1_setup.dart';
import '../widgets/widgets.dart';
import '2_shortlists.dart';
import '3_pitvisits.dart';
import '4_ranks.dart';
import '5_inspire.dart';
import '6_finalists.dart';

class ExportPane extends StatelessWidget {
  const ExportPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        List<Award> sortedAwards = competition.awardsView.where(Award.isNotInspirePredicate).toList()..sort(competition.awardSorter);
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Heading(title: '8. Export'),
            const Padding(
              padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
              child: Text('For printing:', style: bold),
            ),
            ExportButton(
              label: 'Export team list (HTML)',
              onPressed: () => SetupPane.exportTeamsHTML(context, competition),
            ),
            ExportButton(
              label: 'Export shortlists (HTML)',
              onPressed: () => ShortlistsPane.exportShortlistsHTML(context, competition, sortedAwards),
            ),
            if (sortedAwards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent * 2.0, 0.0, indent, spacing),
                child: AwardSelector(
                  label: 'Export shortlists (HTML) for:',
                  awards: sortedAwards,
                  onPressed: (Award award) => ShortlistsPane.exportShortlistsHTML(context, competition, [award]),
                ),
              ),
            ExportButton(
              label: 'Export judge panel summary (HTML)',
              onPressed: () => exportJudgePanelsHTML(context, competition),
            ),
            ExportButton(
              label: 'Export pit visits notes (HTML)',
              onPressed: () => PitVisitsPane.exportPitVisitsHTML(context, competition),
            ),
            ExportButton(
              label: 'Export ranked lists (HTML)',
              onPressed: () => RanksPane.exportRanksHTML(context, competition, sortedAwards),
            ),
            if (sortedAwards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent * 2.0, 0.0, indent, spacing),
                child: AwardSelector(
                  label: 'Export ranked list (HTML) for:',
                  awards: sortedAwards,
                  onPressed: (Award award) => RanksPane.exportRanksHTML(context, competition, [award]),
                ),
              ),
            ExportButton(
              label: 'Export Inspire award results (HTML)',
              onPressed: () => InspirePane.exportInspireHTML(context, competition),
            ),
            ExportButton(
              label: 'Export finalists tables (HTML)',
              onPressed: () => AwardFinalistsPane.exportFinalistsTableHTML(context, competition),
            ),
            ExportButton(
              label: 'Export awards ceremony script (HTML)',
              onPressed: () => AwardFinalistsPane.exportFinalistsScriptHTML(context, competition),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
              child: Text('For spreadsheet import:', style: bold),
            ),
            ExportButton(
              label: 'Export pit visit notes (CSV)',
              onPressed: () => exportPitVisitNotes(context, competition),
            ),
            ExportButton(
              label: 'Export Inspire candidates table (CSV)',
              onPressed: () => exportInspireCandidatesTable(context, competition),
            ),
            ExportButton(
              label: 'Export finalists tables (CSV)',
              onPressed: () => exportFinalistsTable(context, competition),
            ),
            ExportButton(
              label: 'Export finalists lists (CSV)',
              onPressed: () => exportFinalistsLists(context, competition),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
              child: Text('For archiving:', style: bold),
            ),
            ExportButton(
              label: 'Export event state (ZIP)',
              onPressed: () => exportEventState(context, competition),
            ),
            const SizedBox(height: indent),
          ],
        );
      },
    );
  }

  static Future<void> exportJudgePanelsHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    final StringBuffer page = createHtmlPage(competition, 'Judge Panels', now);
    page.writeln('<h2>Nominations</h2>');
    final Map<String, Set<(Award, Team, {String comment})>> nominations = <String, Set<(Award, Team, {String comment})>>{};
    int nominationCount = 0;
    for (Award award in competition.shortlistsView.keys) {
      for (Team team in competition.shortlistsView[award]!.entriesView.keys) {
        final ShortlistEntry entry = competition.shortlistsView[award]!.entriesView[team]!;
        nominationCount += 1;
        if (entry.nominator.isNotEmpty) {
          nominations.putIfAbsent(entry.nominator, () => <(Award, Team, {String comment})>{}).add((award, team, comment: entry.comment));
        }
      }
    }
    if (nominationCount == 0) {
      page.writeln('<p>No nominations.');
    } else if (nominations.isEmpty) {
      page.writeln('<p>No nominations specify a judge panel.');
    } else {
      final List<String> judgePanels = nominations.keys.toList()..sort();
      for (final String judgePanel in judgePanels) {
        page.writeln('<h3>${escapeHtml(judgePanel)}</h3>');
        page.writeln('<ul>');
        final List<(Award, Team, {String comment})> panelNominations = nominations[judgePanel]!.toList()
          ..sort(
            ((Award, Team, {String comment}) a, (Award, Team, {String comment}) b) {
              if (a.$1 == b.$1) {
                return a.$2.number - b.$2.number;
              }
              return a.$1.rank - b.$1.rank;
            },
          );
        Award? lastAward;
        for (final (Award award, Team team, comment: String comment) in panelNominations) {
          if (lastAward != null && award != lastAward) {
            page.writeln('</ul>');
            page.writeln('<ul>');
          }
          page.writeln('<li>${team.number} <i>${escapeHtml(team.name)}</i> for ${award.spreadTheWealth != SpreadTheWealth.no ? "#${award.rank} " : ""}'
              '${escapeHtml(award.name)} award'
              '${award.category.isNotEmpty ? " (${award.category} category)" : ""}');
          if (comment.isNotEmpty) page.writeln('<br><i>${escapeHtml(comment)}</i>');
          lastAward = award;
        }
        page.writeln('</ul>');
      }
    }
    page.writeln('<h2>Pit Visits</h2>');
    final Map<String, Set<Team>> pitVisits = <String, Set<Team>>{};
    for (Team team in competition.teamsView) {
      if (team.visitingJudgesNotes.isNotEmpty) {
        pitVisits.putIfAbsent(team.visitingJudgesNotes, () => <Team>{}).add(team);
      }
    }
    if (pitVisits.isEmpty) {
      page.writeln('<p>No teams have a judging team assigned for extra pit visits.');
    } else {
      final List<String> judgePanels = pitVisits.keys.toList()..sort();
      for (final String judgePanel in judgePanels) {
        page.writeln('<h3>${escapeHtml(judgePanel)}</h3>');
        page.writeln('<ul>');
        for (final Team team in pitVisits[judgePanel]!) {
          page.writeln('<li>${team.number} <i>${escapeHtml(team.name)}</i>'
              '${team.visited ? " (visited)" : ""}');
        }
        page.writeln('</ul>');
      }
    }
    return exportHTML(competition, 'judge_panels', now, page.toString());
  }
}
