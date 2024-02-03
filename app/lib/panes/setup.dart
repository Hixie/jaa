import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../constants.dart';
import '../io.dart';
import '../widgets.dart';
import '../model/competition.dart';

class SetupPane extends StatelessWidget {
  const SetupPane({super.key, required this.competition});

  final Competition competition;

  static List<T> _subsetTable<T>(List<T> list, int initialRows, T overflow) {
    if (list.length <= initialRows + 2) return list;
    return [
      ...list.take(initialRows),
      overflow,
      list.last,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: indent),
          ConstrainedBox(
            // This stretches the Wrap across the Column as if the mainAxisAlignment was MainAxisAlignment.stretch.
            constraints: const BoxConstraints(minWidth: double.infinity),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(indent, 0.0, 0.0, 0.0),
                  child: Heading('1. Setup'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, spacing),
                  child: FilledButton(
                    onPressed: null, // TODO: Import ZIP
                    child: Text(
                      competition.teamsView.isEmpty || competition.awardsView.isEmpty
                          ? 'Import event state (ZIP)'
                          : 'Reset everything from saved event state (ZIP)',
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: FilledButton(
              child: Text(
                competition.teamsView.isEmpty || competition.awardsView.isEmpty
                    ? 'Import team list (CSV)'
                    : 'Reset all teams and rankings and import new team list (CSV)',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () async {
                final PlatformFile? csvFile = await openFile(context, title: 'Import Team List (CSV)', extension: 'csv');
                if (csvFile != null) {
                  await showProgress(
                    context, // ignore: use_build_context_synchronously
                    message: 'Importing teams...',
                    task: () => competition.importTeams(csvFile),
                  );
                }
              },
            ),
          ),
          if (competition.teamsView.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(indent, 0.0, 0.0, indent),
              child: HorizontalScrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.symmetric(
                      inside: const BorderSide(),
                    ),
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    children: [
                      const TableRow(
                        children: [
                          Cell(Text('Team Number', style: bold)),
                          Cell(Text('Team Name', style: bold)),
                          Cell(Text('Team City', style: bold)),
                          Cell(Text('Previous Inspire Winner', style: bold)),
                        ],
                      ),
                      for (final Team? team in _subsetTable(competition.teamsView, 4, null))
                        TableRow(
                          children: [
                            Cell(Text('${team?.number ?? '...'}')),
                            Cell(Text(team?.name ?? '...')),
                            Cell(Text(team?.city ?? '...')),
                            Cell(Text(
                              team != null
                                  ? team.inspireWins > 0
                                      ? 'Yes'
                                      : ''
                                  : '...',
                            )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: FilledButton(
              child: Text(
                competition.teamsView.isEmpty || competition.awardsView.isEmpty ? 'Import awards (CSV)' : 'Reset all rankings and import new awards (CSV)',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () async {
                final PlatformFile? csvFile = await openFile(context, title: 'Import Awards (CSV)', extension: 'csv');
                if (csvFile != null) {
                  await showProgress(
                    context, // ignore: use_build_context_synchronously
                    message: 'Importing awards...',
                    task: () => competition.importAwards(csvFile),
                  );
                }
              },
            ),
          ),
          if (competition.awardsView.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(indent, 0.0, 0.0, 0.0),
              child: HorizontalScrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.symmetric(
                      inside: const BorderSide(),
                    ),
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    children: [
                      const TableRow(
                        children: [
                          Cell(Text('Award Name', style: bold)),
                          Cell(Text('Award Type', style: bold)),
                          Cell(Text('Award Rank', style: bold)),
                          Cell(Text('Award Count', style: bold)),
                          Cell(Text('Inspire Category', style: bold)),
                          Cell(Text('Spread the wealth', style: bold)),
                          Cell(Text('Placement', style: bold)),
                          Cell(Text('Pit Visits', style: bold)),
                        ],
                      ),
                      for (final Award award in competition.awardsView)
                        TableRow(
                          children: [
                            Cell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12.0,
                                    height: 12.0,
                                    margin: const EdgeInsets.fromLTRB(0.0, 0.0, spacing, 0.0),
                                    decoration: BoxDecoration(border: Border.all(width: 0.0, color: const Color(0xFF000000)), color: award.color),
                                  ),
                                  Text(award.name),
                                ],
                              ),
                            ),
                            Cell(Text(award.advancing ? 'Advancing' : 'Non-Advancing')),
                            Cell(Text('${award.rank}')),
                            Cell(Text('${award.count}')),
                            Cell(Text(award.category)),
                            Cell(Text(award.spreadTheWealth ? 'Yes' : '')),
                            Cell(Text(award.placement ? 'Yes' : '')),
                            Cell(Text(switch (award.pitVisits) {
                              PitVisit.yes => 'Yes',
                              PitVisit.no => 'No',
                              PitVisit.maybe => 'Maybe',
                            })),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
