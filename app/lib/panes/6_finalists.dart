import 'package:flutter/material.dart';

import '../constants.dart';
import '../io.dart';
import '../model/competition.dart';
import '../widgets.dart';

class AwardFinalistsPane extends StatelessWidget {
  const AwardFinalistsPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final List<(Award, List<AwardFinalistEntry>)> finalists = competition.computeFinalists();
        final Set<Award> emptyAwards = {};
        final Set<Award> tiedAwards = {};
        final Set<Award> incompleteAwards = {};
        for (final (Award award, List<AwardFinalistEntry> results) in finalists) {
          bool hasAny = false;
          // ignore: unused_local_variable
          for (final (Team? team, Award? otherAward, int rank, tied: bool tied) in results) {
            if (team != null && otherAward == null) {
              hasAny = true;
            }
            if (tied) {
              tiedAwards.add(award);
            }
            if (team == null) {
              incompleteAwards.add(award);
            }
          }
          if (!hasAny) {
            emptyAwards.add(award);
          }
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaneHeader(
              title: '6. Award Finalists',
              onHeaderButtonPressed: () => exportFinalistsTableHTML(context, competition),
            ),
            if (finalists.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text('No finalists can be assigned until teams are nominated using the Ranks pane.'),
              )
            else if (competition.inspireAward != null && emptyAwards.contains(competition.inspireAward))
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No finalists designated for the ${competition.inspireAward!.name} award. '
                  'Use the Inspire pane to assign the ${competition.inspireAward!.name} winner and runner-ups.',
                ),
              )
            else if (emptyAwards.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'Some awards have no ranked qualifying teams. Use the Ranks pane to assign ranks for teams in award shortlists. '
                  'The following awards are affected: ${emptyAwards.map((Award award) => award.name).join(", ")}',
                ),
              )
            else if (emptyAwards.length == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'The ${emptyAwards.single.name} award has no ranked qualifying teams. Use the Ranks pane to assign ranks for teams in award shortlists.',
                ),
              ),
            if (finalists.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, 0),
                child: ScrollableWrap(
                  children: [
                    for (final (Award award, List<AwardFinalistEntry> awardFinalists) in finalists)
                      ListenableBuilder(
                        listenable: award,
                        builder: (BuildContext context, Widget? child) {
                          return AwardCard(
                            award: award,
                            showAwardRanks: true,
                            child: Table(
                              border: TableBorder.symmetric(
                                inside: BorderSide(color: textColorForColor(award.color)),
                              ),
                              defaultColumnWidth: MaxColumnWidth(
                                const IntrinsicColumnWidth(),
                                FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! * 5.0),
                              ),
                              defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                TableRow(
                                  children: [
                                    const Cell(Text('#', style: bold)),
                                    if (award.isPlacement) const Cell(Text('Ranks', style: bold)) else const Cell(Text('Results', style: bold)),
                                  ],
                                ),
                                for (final (Team? team, Award? otherAward, int rank, tied: bool tied) in awardFinalists)
                                  TableRow(
                                    children: [
                                      if (team != null)
                                        Tooltip(
                                          message: team.name,
                                          child: Cell(Text(
                                            '${team.number}',
                                            style: otherAward != null || (award.isInspire && rank > 1) ? null : bold,
                                          )),
                                        )
                                      else
                                        const ErrorCell(message: 'missing'),
                                      if (tied)
                                        ErrorCell(message: 'Tied for ${placementDescriptor(rank)}')
                                      else if (otherAward != null)
                                        Cell(Text('${otherAward.name} ${placementDescriptor(rank)}'))
                                      else
                                        Cell(
                                          Text(
                                            award.isPlacement
                                                ? placementDescriptor(rank)
                                                : rank <= award.count
                                                    ? 'Win'
                                                    : 'Runner-Up',
                                            style: otherAward == null && rank <= (award.isInspire ? 1 : award.count) ? bold : null,
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            if (incompleteAwards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, 0),
                child: Text(
                  'Not all awards have had teams selected for all available places.\n'
                  'For advice with handling difficult cases, consider calling FIRST:\n'
                  '$currentHelp',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            const SizedBox(height: indent)
          ],
        );
      },
    );
  }

  static Future<void> exportFinalistsTableHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    StringBuffer page = createHtmlPage('Finalists', now);
    final List<(Award, List<AwardFinalistEntry>)> finalists = competition.computeFinalists();
    for (final (Award award, List<AwardFinalistEntry> entry) in finalists) {
      page.writeln(
        '<h2>${award.isSpreadTheWealth ? "#${award.rank}: " : ""}'
        '${escapeHtml(award.name)} award'
        '${award.category.isNotEmpty ? " (${award.category} category)" : ""}</h2>',
      );
      page.writeln('<table>');
      page.writeln('<thead>');
      page.writeln('<tr>');
      page.writeln('<th>Team');
      page.writeln('<th>Result');
      page.writeln('<tbody>');
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied) in entry) {
        final bool winner = otherAward == null && rank <= (award.isInspire ? 1 : award.count);
        page.writeln('<tr>');
        if (team != null) {
          page.writeln('<td>${otherAward != null ? "<s>" : ""}${team.number} <i>${escapeHtml(team.name)}</i>${otherAward != null ? "</s>" : ""}');
        } else {
          page.writeln('<td>&mdash;');
        }
        if (otherAward != null) {
          page.writeln('<td><s>${escapeHtml(otherAward.name)} ${escapeHtml(placementDescriptor(rank))}</s>');
        } else if (winner) {
          page.writeln('<td><strong>${escapeHtml(award.isPlacement ? placementDescriptor(rank) : "Win")}</strong>${tied ? " TIED" : ""}');
        } else {
          page.writeln('<td>${escapeHtml(award.isPlacement ? placementDescriptor(rank) : "Runner-Up")}');
        }
      }
      page.writeln('</table>');
    }
    return exportHTML(competition, 'finalists', now, page.toString());
  }

  static Future<void> exportFinalistsScriptHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    StringBuffer page = createHtmlPage('Finalists Script', now);
    final List<(Award, List<AwardFinalistEntry>)> finalists = competition.computeFinalists();
    for (final (Award award, List<AwardFinalistEntry> entry) in finalists.reversed) {
      bool includedHeader = false;
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied) in entry.reversed) {
        final bool winner = team != null && otherAward == null && rank <= award.count;
        if (winner) {
          if (!includedHeader) {
            page.writeln(
              '<h2>${award.isSpreadTheWealth ? "#${award.rank}: " : ""}'
              '${escapeHtml(award.name)} award'
              '${award.category.isNotEmpty ? " (${award.category} category)" : ""}</h2>',
            );
            includedHeader = true;
          }
          page.writeln(
            '<p>'
            '${tied ? "Tied for " : ""}${escapeHtml(award.isPlacement ? placementDescriptor(rank) : "Win")}: '
            '${team.number} <i>${escapeHtml(team.name)}</i> from ${escapeHtml(team.city)}',
          );
        }
      }
    }
    return exportHTML(competition, 'finalists_script', now, page.toString());
  }
}

class ErrorCell extends StatelessWidget {
  const ErrorCell({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: ColoredBox(
        color: Colors.red,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: spacing),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
