import 'package:flutter/material.dart';

import '../constants.dart';
import '../model/competition.dart';
import '../widgets.dart';

class AwardFinalistsPane extends StatelessWidget {
  const AwardFinalistsPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: competition,
        builder: (BuildContext context, Widget? child) {
          final Set<Award> emptyAwards = {};
          final List<(Award, List<(Team?, Award?, int, {bool tied})>)> finalists = [];
          final Map<Team, (Award, int)> winningTeams = <Team, (Award, int)>{};
          for (final Award award in competition.awardsView) {
            final List<(Team?, Award?, int, {bool tied})> awardResults = [];
            int remaining = award.count;
            assert(remaining > 0);
            int rank = 1;
            if (!competition.shortlistsView.containsKey(award)) {
              emptyAwards.add(award);
            } else {
              award:
              for (Set<Team> teams in competition.shortlistsView[award]!.asRankedList()) {
                Set<Team> skipped = teams.intersection(winningTeams.keys.toSet());
                for (Team team in skipped) {
                  final (Award previousAward, int previousRank) = winningTeams[team]!;
                  awardResults.add((team, previousAward, previousRank, tied: false));
                }
                Set<Team> winners = teams.difference(skipped);
                for (Team team in winners) {
                  if (!award.isInspire || rank == 1) {
                    winningTeams[team] = (award, rank);
                  }
                  awardResults.add((team, null, rank, tied: winners.length > 1));
                  rank += 1;
                  remaining -= 1;
                }
                if (remaining == 0) {
                  break award;
                }
              }
              if (rank == 1) {
                emptyAwards.add(award);
              }
              while (remaining > 0) {
                awardResults.add((null, null, rank, tied: false));
                rank += 1;
                remaining -= 1;
              }
              finalists.add((award, awardResults));
            }
          }
          final Award inspireAward = competition.awardsView.firstWhere((Award award) => award.isInspire);
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const PaneHeader(
                title: '6. Award Finalists',
                onHeaderButtonPressed: null, // TODO: exports the candidates table
              ),
              if (finalists.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                  child: Text('No finalists can be assigned until teams are nominated using the Ranks pane.'),
                )
              else if (emptyAwards.contains(inspireAward))
                Padding(
                  padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                  child: Text(
                    'No finalists designated for the ${inspireAward.name} award. '
                    'Use the Inspire pane to assign the ${inspireAward.name} winner and runner-ups.',
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
                  padding: const EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                  child: ScrollableWrap(
                    children: [
                      for (final (Award award, List<(Team?, Award?, int, {bool tied})> awardFinalists) in finalists)
                        AwardCard(
                          award: award,
                          showAwardRanks: true,
                          child: Table(
                            border: TableBorder.symmetric(
                              inside: const BorderSide(),
                            ),
                            defaultColumnWidth: MaxColumnWidth(
                              const IntrinsicColumnWidth(),
                              FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! * 5.0),
                            ),
                            defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const TableRow(
                                children: [
                                  Cell(Text('#', style: bold)),
                                  Cell(Text('Ranks', style: bold)),
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
                                      const Cell(Text('-')),
                                    tied
                                        ? TableCell(
                                            verticalAlignment: TableCellVerticalAlignment.fill,
                                            child: ColoredBox(
                                              color: Colors.red,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: spacing),
                                                child: Center(
                                                  child: Text(
                                                    'tied for ${placementDescriptor(rank)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Cell(
                                            Text(
                                              '${otherAward != null ? "${otherAward.name} " : ""}${placementDescriptor(rank)}',
                                              style: otherAward != null || (award.isInspire && rank > 1) ? null : bold,
                                            ),
                                          ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
