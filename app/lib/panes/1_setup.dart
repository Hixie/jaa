import 'package:flex_color_picker/flex_color_picker.dart';
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
          PaneHeader(
            title: '1. Setup',
            headerButtonLabel:
                competition.teamsView.isEmpty || competition.awardsView.isEmpty ? 'Import event state (ZIP)' : 'Reset everything from saved event state (ZIP)',
            onHeaderButtonPressed: () async {
              final PlatformFile? zipFile = await openFile(context, title: 'Import Event State (ZIP)', extension: 'zip');
              if (zipFile != null) {
                await showProgress(
                  context, // ignore: use_build_context_synchronously
                  message: 'Importing event state...',
                  task: () => competition.importEventState(zipFile),
                );
              }
            },
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
                    task: () async => competition.importTeams(await csvFile.readStream!.expand((List<int> fragment) => fragment).toList()),
                  );
                }
              },
            ),
          ),
          if (competition.teamsView.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(indent, 0.0, 0.0, spacing),
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
                                  ? team.inspireEligible
                                      ? ''
                                      : 'Yes'
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
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, 0.0),
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
                    task: () async => competition.importAwards(await csvFile.readStream!.expand((List<int> fragment) => fragment).toList()),
                  );
                }
              },
            ),
          ),
          if (competition.awardsView.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(indent, spacing, 0.0, 0.0),
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
                                  ListenableBuilder(
                                    listenable: award,
                                    builder: (BuildContext context, Widget? child) {
                                      return ColorIndicator(
                                        color: award.color,
                                        width: 12.0,
                                        height: 12.0,
                                        borderRadius: 0.0,
                                        onSelectFocus: false,
                                        onSelect: () async {
                                          Color selectedColor = award.color;
                                          if (await ColorPicker(
                                            heading: Text('${award.name} color', style: headingStyle),
                                            color: selectedColor,
                                            wheelWidth: indent,
                                            wheelSquareBorderRadius: indent,
                                            pickersEnabled: const <ColorPickerType, bool>{
                                              ColorPickerType.accent: false,
                                              ColorPickerType.both: false,
                                              ColorPickerType.bw: false,
                                              ColorPickerType.custom: false,
                                              ColorPickerType.primary: false,
                                              ColorPickerType.wheel: true,
                                            },
                                            enableShadesSelection: false,
                                            showColorName: true,
                                            showColorCode: true,
                                            colorCodeHasColor: true,
                                            copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                                              parseShortHexCode: true,
                                              copyFormat: ColorPickerCopyFormat.numHexRRGGBB,
                                            ),
                                            actionButtons: const ColorPickerActionButtons(
                                              dialogActionOrder: ColorPickerActionButtonOrder.adaptive,
                                            ),
                                            onColorChanged: (Color color) {
                                              selectedColor = color;
                                            },
                                          ).showPickerDialog(context)) {
                                            award.updateColor(selectedColor);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(width: spacing),
                                  Text(award.name),
                                ],
                              ),
                            ),
                            Cell(Text(award.isAdvancing ? 'Advancing' : 'Non-Advancing')),
                            Cell(Text('${award.rank}')),
                            Cell(Text('${award.count}')),
                            Cell(Text(award.category)),
                            Cell(Text(award.isSpreadTheWealth ? 'Yes' : '')),
                            Cell(Text(award.isPlacement ? 'Yes' : '')),
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
          const SizedBox(height: indent),
        ],
      ),
    );
  }
}
