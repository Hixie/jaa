import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/constants.dart';
import '../utils/io.dart';
import '../model/competition.dart';
import '../widgets/cells.dart';
import '../widgets/widgets.dart';

class SetupPane extends StatefulWidget {
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
  State<SetupPane> createState() => _SetupPaneState();

  static Future<void> exportTeamsHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    final StringBuffer page = createHtmlPage(competition, 'Teams', now);
    if (competition.teamsView.isEmpty) {
      page.writeln('<p>No teams loaded.');
    } else {
      page.writeln('<table>');
      page.writeln('<thead>');
      page.writeln('<tr>');
      page.writeln('<th>Team');
      page.writeln('<th>Name');
      page.writeln('<th>Location');
      page.writeln('<th>Notes');
      page.writeln('<tbody>');
      for (final Team team in competition.teamsView) {
        page.writeln('<tr>');
        page.writeln('<td>${team.number}');
        page.writeln('<td>${escapeHtml(team.name)}');
        page.writeln('<td>${escapeHtml(team.location)}');
        page.writeln(
          '<td>${team.visited == competition.expectedPitVisits ? "Visited." : team.visited == 0 ? "" : "${team.visited}/${competition.expectedPitVisits}"} ${escapeHtml(team.visitingJudgesNotes)}',
        );
      }
      page.writeln('</table>');
    }
    return exportHTML(competition, 'teams', now, page.toString());
  }
}

class _SetupPaneState extends State<SetupPane> {
  bool _teamEditor = false;
  bool _awardEditor = false;
  final TextEditingController _eventNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _eventNameController.addListener(() {
      widget.competition.eventName = _eventNameController.text;
    });
    widget.competition.addListener(_handleCompetitionChanged);
    _handleCompetitionChanged();
  }

  @override
  void didUpdateWidget(covariant SetupPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.competition != widget.competition) {
      oldWidget.competition.removeListener(_handleCompetitionChanged);
      widget.competition.addListener(_handleCompetitionChanged);
      _handleCompetitionChanged();
    }
  }

  void _handleCompetitionChanged() {
    setState(() {
      if (widget.competition.eventName != _eventNameController.text) {
        _eventNameController.text = widget.competition.eventName;
      }
    });
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    widget.competition.removeListener(_handleCompetitionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PaneHeader(
          title: '1. Setup',
          headerButtonLabel: widget.competition.teamsView.isEmpty || widget.competition.awardsView.isEmpty
              ? 'Import event state (ZIP)'
              : 'Reset everything from saved event state (ZIP)',
          onHeaderButtonPressed: () async {
            final PlatformFile? zipFile = await openFile(context, title: 'Import Event State (ZIP)', extension: 'zip');
            if (zipFile != null) {
              await showProgress(
                context, // ignore: use_build_context_synchronously
                message: 'Importing event state...',
                task: () => widget.competition.importEventState(zipFile),
              );
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              FilledButton(
                child: Text(
                  widget.competition.teamsView.isEmpty || widget.competition.awardsView.isEmpty
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
                      task: () async => widget.competition.importTeams(await csvFile.readStream!.expand((List<int> fragment) => fragment).toList()),
                    );
                  }
                },
              ),
              FilledButton(
                onPressed: widget.competition.teamsView.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _teamEditor = !_teamEditor;
                        });
                      },
                child: Text(
                  _teamEditor ? 'Hide team editor' : 'Show team editor',
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (widget.competition.teamsView.isNotEmpty && _teamEditor)
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, indent),
            child: TeamEditor(
              competition: widget.competition,
              onClosed: () {
                setState(() {
                  _teamEditor = false;
                });
              },
            ),
          ),
        if (widget.competition.teamsView.isNotEmpty)
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
                    defaultColumnWidth: const IntrinsicCellWidth(),
                    children: [
                      const TableRow(
                        children: [
                          Cell(Text('Team Number', style: bold), prototype: Text('000000')),
                          Cell(Text('Team Name', style: bold), prototype: Text('Wonderful Kittens')),
                          Cell(Text('Team Location', style: bold), prototype: Text('Mooselookmeguntic')),
                          Cell(Text('Inspire eligible', style: bold), prototype: Text('Yes')),
                        ],
                      ),
                      for (final Team? team in SetupPane._subsetTable(widget.competition.teamsView, 4, null))
                        TableRow(
                          children: [
                            Cell(Text('${team?.number ?? '...'}')),
                            Cell(Text(team?.name ?? '...')),
                            Cell(Text(team?.location ?? '...')),
                            Cell(Text(
                              team != null
                                  ? switch (team.inspireStatus) {
                                      InspireStatus.eligible => 'Yes',
                                      InspireStatus.ineligible => 'Ineligible',
                                      InspireStatus.hidden => 'Yes (hidden)',
                                      InspireStatus.exhibition => 'Not competing',
                                    }
                                  : '...',
                            )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(indent, indent, indent, spacing),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              FilledButton(
                child: Text(
                  widget.competition.teamsView.isEmpty || widget.competition.awardsView.isEmpty
                      ? 'Import awards (CSV)'
                      : 'Reset all rankings and import new awards (CSV)',
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () async {
                  final PlatformFile? csvFile = await openFile(context, title: 'Import Awards (CSV)', extension: 'csv');
                  if (csvFile != null) {
                    await showProgress(
                      context, // ignore: use_build_context_synchronously
                      message: 'Importing awards...',
                      task: () async => widget.competition.importAwards(await csvFile.readStream!.expand((List<int> fragment) => fragment).toList()),
                    );
                  }
                },
              ),
              FilledButton(
                onPressed: widget.competition.awardsView.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _awardEditor = !_awardEditor;
                        });
                      },
                child: Text(
                  _awardEditor ? 'Close event-specific award editor' : 'Add event-specific award...',
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (_awardEditor)
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, 0.0),
            child: AwardEditor(
              competition: widget.competition,
              onClosed: () {
                setState(() {
                  _awardEditor = false;
                });
              },
            ),
          ),
        if (widget.competition.awardsView.isNotEmpty)
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
                    columnWidths: const <int, TableColumnWidth>{0: IntrinsicColumnWidth()},
                    defaultColumnWidth: const IntrinsicCellWidth(),
                    defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TableRow(
                        children: [
                          Cell(Text('Award Name', style: bold)),
                          Cell(
                            Text('Type', style: bold),
                            prototype: Text('Advancing (Independent)'),
                            // if the longest cell is the event-specific one, use this:
                            // prototype: EventSpecificCell(competition: null, award: null),
                            // padPrototype: false,
                          ),
                          Cell(Text('Rank', style: bold), prototype: Text('000')),
                          Cell(Text('Winners', style: bold), prototype: Text('000')),
                          Cell(Text('Category', style: bold), prototype: Text('Documentation')),
                          Cell(Text('Spread the wealth', style: bold), prototype: Text('Winner Only')),
                          Cell(Text('Autonomination', style: bold), prototype: Text('Enabled')),
                          Cell(Text('Placement', style: bold), prototype: Text('Yes')),
                          Cell(Text('Pit Visits', style: bold), prototype: Text('Maybe')),
                          Cell(
                              Row(
                                children: [
                                  Icon(
                                    Symbols.emoji_objects,
                                    size: DefaultTextStyle.of(context).style.fontSize,
                                  ),
                                  SizedBox(width: spacing),
                                  Text('Comment ✎_', style: bold),
                                ],
                              ),
                              prototype: Text('Hello World')),
                        ],
                      ),
                      for (final Award award in widget.competition.awardsView)
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
                            award.isEventSpecific
                                ? EventSpecificCell(competition: widget.competition, award: award)
                                : Cell(
                                    Tooltip(
                                      message: award.type != 0 ? 'FTC Award ID ${award.type}' : 'No FTC Award ID',
                                      child: Text(
                                        switch (award.kind) {
                                          AwardKind.inspire => 'Inspire',
                                          AwardKind.advancingInspire => 'Inspire Contributor',
                                          AwardKind.advancingIndependent => 'Advancing (Independent)',
                                          AwardKind.nonAdvancing => 'Non-Advancing',
                                        },
                                      ),
                                    ),
                                  ),
                            Cell(Text(award.spreadTheWealth != SpreadTheWealth.no ? '${award.rank}' : '')),
                            Cell(Text('${award.count}')),
                            Cell(Text(award.category)),
                            Cell(Text(switch (award.spreadTheWealth) {
                              SpreadTheWealth.allPlaces => 'All Places',
                              SpreadTheWealth.winnerOnly => 'Winner Only',
                              SpreadTheWealth.no => '',
                            })),
                            Cell(
                              Tooltip(
                                message: award.autonominationRule?.description ?? '',
                                child: Text(award.autonominationRule?.name ?? ''),
                              ),
                            ),
                            Cell(Text(award.isPlacement ? 'Yes' : '')),
                            Cell(Text(switch (award.pitVisits) {
                              PitVisit.yes => 'Yes',
                              PitVisit.no => 'No',
                              PitVisit.maybe => 'Maybe',
                            })),
                            Material(
                              type: MaterialType.transparency,
                              child: TextEntryCell(
                                padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, 0.0),
                                value: award.comment,
                                onChanged: award.updateComment,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(indent, spacing + indent, indent, spacing),
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              controller: _eventNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Event Name (optional)',
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(indent, spacing, indent, indent),
          child: Row(
            children: [
              Text('Expected number of pit visits per team:'),
              SizedBox(width: spacing),
              VisitInput(
                value: widget.competition.expectedPitVisits,
                min: 1,
                onChanged: (int value) {
                  widget.competition.expectedPitVisits = value;
                },
              ),
            ],
          ),
        ),
        if (!kReleaseMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, indent),
            child: FilledButton(
              onPressed: () => widget.competition.debugGenerateRandomData(math.Random(0)),
              child: const Text(
                'Generate random data (debug only)',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

class EventSpecificCell extends StatelessWidget {
  const EventSpecificCell({
    super.key,
    required this.competition,
    required this.award,
  });

  final Competition? competition;
  final Award? award;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(spacing, 0.0, 0.0, 0.0),
      child: Row(
        children: [
          const Expanded(child: Text('Event-Specific')),
          Material(
            type: MaterialType.transparency,
            child: IconButton(
              onPressed: competition == null || award == null || !competition!.canDelete(award!)
                  ? null
                  : () {
                      competition!.deleteEventAward(award!);
                    },
              iconSize: DefaultTextStyle.of(context).style.fontSize,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              tooltip: competition != null && award != null && competition!.canDelete(award!)
                  ? 'Delete this event-specific award.'
                  : 'Cannot delete awards that have nominees.',
              icon: const Icon(Icons.delete_forever),
            ),
          ),
        ],
      ),
    );
  }
}

class TeamEditor extends StatefulWidget {
  const TeamEditor({
    super.key,
    required this.competition,
    required this.onClosed,
  });

  final Competition competition;
  final VoidCallback onClosed;

  @override
  State<TeamEditor> createState() => _TeamEditorState();
}

class _TeamEditorState extends State<TeamEditor> {
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  Team? _team;

  String get _currentTeamLabel => _team != null ? "${_team!.number} ${_team!.name}" : "";

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleTeamDetailsTextChange);
    _locationController.addListener(_handleTeamDetailsTextChange);
  }

  @override
  void dispose() {
    _teamController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _handleTeamChange(Team? team) {
    setState(() {
      _team = null;
      _nameController.text = team?.name ?? '';
      _locationController.text = team?.location ?? '';
      _team = team;
    });
  }

  void _handleTeamDetailsTextChange() {
    if (_team != null) {
      widget.competition.updateTeam(_team!, _nameController.text, _locationController.text);
      _teamController.text = _currentTeamLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> teamNotes = [];
    if (_team != null) {
      teamNotes.add(const SizedBox(height: spacing * 2.0));
      teamNotes.add(const Divider());
      teamNotes.add(const SizedBox(height: spacing * 2.0));
      teamNotes.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: indent * 20.0),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Team Name',
                      ),
                      enabled: _team != null,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: indent * 20.0),
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Team Location',
                      ),
                      enabled: _team != null,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(spacing, 0.0, 0.0, 0.0),
              child: IconButton(
                icon: const Icon(Symbols.done),
                onPressed: _team == null
                    ? null
                    : () {
                        setState(() {
                          _team = null;
                          _teamController.text = '';
                        });
                      },
              ),
            ),
          ],
        ),
      );
      teamNotes.add(const SizedBox(height: spacing * 2.0));
      teamNotes.add(
        MergeSemantics(
          child: Row(
            children: [
              Checkbox(
                value: _team!.hasPortfolio,
                onChanged: (bool? value) { 
                  widget.competition.updatePortfolio(_team!, value!);
                },
              ),
              const Text('Team has portfolio.'),
            ],
          ),
        ),
      );
      switch (_team!.inspireStatus) {
        case InspireStatus.eligible:
        case InspireStatus.exhibition:
          teamNotes.add(
            CheckboxRow(
              checked: _team!.inspireStatus == InspireStatus.exhibition,
              onChanged: _team!.inspireStatus != InspireStatus.eligible && _team!.inspireStatus != InspireStatus.exhibition
                  ? null
                  : (bool? value) {
                      if (value!) {
                        widget.competition.updateTeamInspireStatus(_team!, status: InspireStatus.exhibition);
                      } else {
                        widget.competition.updateTeamInspireStatus(_team!, status: InspireStatus.eligible);
                      }
                    },
              tristate: false,
              label: 'Remove team from judging lists (exhibition team).',
              includePadding: false,
            ),
          );
          if (_team!.inspireStatus == InspireStatus.exhibition) {
            teamNotes.add(const SizedBox(height: spacing));
            teamNotes.add(const Text('Team is an exhibition team at this event, they are not eligible for any awards.'));
          }
        case InspireStatus.ineligible:
          teamNotes.add(const Text('Team is not eligible for an Inspire award at this event.'));
        case InspireStatus.hidden:
          teamNotes.add(const Text('Team is currently hidden on the Inspire pane.'));
          teamNotes.add(
            FilledButton(
              onPressed: () {
                widget.competition.updateTeamInspireStatus(_team!, status: InspireStatus.eligible);
              },
              child: const Text(
                'Unhide team',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
      }
      teamNotes.add(const SizedBox(height: spacing));
      if (_team!.inspireStatus == InspireStatus.eligible || _team!.inspireStatus == InspireStatus.hidden) {
        if (_team!.shortlistsView.isEmpty) {
          teamNotes.add(const Text('Team is not currently nominated for any awards.'));
        } else {
          teamNotes.add(const Text('Team is nominated for:'));
          for (final Award award in _team!.shortlistsView.keys) {
            ShortlistEntry entry = _team!.shortlistsView[award]!;
            teamNotes.add(Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('• '),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '${award.spreadTheWealth != SpreadTheWealth.no ? '#${award.rank} ' : ''}'
                          '${award.name}'
                          '${entry.nominator.isEmpty ? '' : ' (nominated by ${entry.nominator})'}'
                          '${entry.rank != null ? ' — rank ${entry.rank}' : ''}',
                      children: [
                        if (entry.comment.isNotEmpty) TextSpan(text: '\n${entry.comment}', style: italic),
                      ],
                    ),
                    softWrap: true,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ],
            ));
          }
        }
        teamNotes.add(const SizedBox(height: spacing));
        List<Award> pitVisitAwards = _team!.shortlistsView.keys.where((Award award) => award.pitVisits == PitVisit.yes).toList();
        if (pitVisitAwards.isNotEmpty) {
          teamNotes.add(Text('Team will be visited as part of judging for: ${pitVisitAwards.map((Award award) => award.name).join(', ')}'));
        } else {
          teamNotes.add(const Text('Team will not be automatically visited as part of judging.'));
        }
        teamNotes.add(
          VisitedCell(
            label: const Text('Visted?'),
            competition: widget.competition,
            team: _team!,
          ),
        );
      }
    }
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) {
        return InlineScrollableCard(
          onClosed: widget.onClosed,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Padding(
                  // TODO: remove this once DropdownMenu correctly reports its baseline
                  padding: EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 0.0),
                  child: Text('Edit team:', style: bold),
                ),
                const SizedBox(width: indent),
                Flexible(
                  child: DropdownList<Team>(
                    controller: _teamController,
                    onSelected: _handleTeamChange,
                    label: 'Team',
                    values: Map<Team, String>.fromIterable(widget.competition.teamsView, value: (dynamic team) => '${team.number} ${team.name}'),
                  ),
                ),
              ],
            ),
            ...teamNotes,
          ],
        );
      },
    );
  }
}

class AwardEditor extends StatefulWidget {
  const AwardEditor({
    super.key,
    required this.competition,
    required this.onClosed,
  });

  final Competition competition;
  final VoidCallback onClosed;

  @override
  State<AwardEditor> createState() => _AwardEditorState();
}

class _AwardEditorState extends State<AwardEditor> {
  final TextEditingController _nameController = TextEditingController();
  int _count = 1;
  SpreadTheWealth _spreadTheWealth = SpreadTheWealth.no;
  bool _placement = false;
  PitVisit _pitVisit = PitVisit.no;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_nameController, widget.competition]),
      builder: (BuildContext context, Widget? child) {
        bool nameIsUnique = !widget.competition.awardsView.any((Award award) => award.name == _nameController.text);
        return InlineScrollableCard(
          onClosed: widget.onClosed,
          children: [
            const Text('Add event-specific award:', style: bold),
            const SizedBox(height: spacing),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Award Name',
                errorText: nameIsUnique ? null : 'Name must be unique.',
              ),
            ),
            const SizedBox(height: spacing),
            Row(
              children: [
                const Text('Maximum number of winners:'),
                const SizedBox(width: indent),
                IconButton.outlined(
                  onPressed: _count <= 1
                      ? null
                      : () {
                          setState(() {
                            _count -= 1;
                          });
                        },
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: DefaultTextStyle.of(context).style.fontSize! * 3.0,
                  child: Text(
                    '$_count',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton.outlined(
                  onPressed: _count >= 32
                      ? null
                      : () {
                          setState(() {
                            _count += 1;
                          });
                        },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: switch (_spreadTheWealth) {
                      SpreadTheWealth.allPlaces => true,
                      SpreadTheWealth.winnerOnly => null,
                      SpreadTheWealth.no => false,
                    },
                    tristate: true,
                    onChanged: (bool? value) {
                      setState(() {
                        _spreadTheWealth = switch (value) {
                          true => SpreadTheWealth.allPlaces,
                          null => SpreadTheWealth.winnerOnly,
                          false => SpreadTheWealth.no,
                        };
                      });
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _spreadTheWealth = switch (_spreadTheWealth) {
                            SpreadTheWealth.allPlaces => SpreadTheWealth.winnerOnly,
                            SpreadTheWealth.winnerOnly => SpreadTheWealth.no,
                            SpreadTheWealth.no => SpreadTheWealth.allPlaces,
                          };
                        });
                      },
                      child: const Text(
                        'Apply "spread the wealth" rules when assigning finalists (all places, winner only, no). '
                        'Teams can only be finalists for one "spread the wealth" award per event.',
                        softWrap: true,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _count > 1 && _placement,
                    onChanged: _count <= 1
                        ? null
                        : (bool? value) {
                            setState(() {
                              _placement = value!;
                            });
                          },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _placement = !_placement;
                        });
                      },
                      child: const Text(
                        'Finalists are ranked (1st, 2nd, 3rd, etc).',
                        softWrap: true,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: switch (_pitVisit) {
                      PitVisit.yes => true,
                      PitVisit.no => false,
                      PitVisit.maybe => null,
                    },
                    tristate: true,
                    onChanged: (bool? value) {
                      setState(() {
                        _pitVisit = switch (value) {
                          true => PitVisit.yes,
                          false => PitVisit.no,
                          null => PitVisit.maybe,
                        };
                      });
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _pitVisit = switch (_pitVisit) {
                            PitVisit.no => PitVisit.yes,
                            PitVisit.maybe => PitVisit.no,
                            PitVisit.yes => PitVisit.maybe,
                          };
                        });
                      },
                      child: const Text(
                        'Judging this award always involves a pit visit (yes, maybe, no).',
                        softWrap: true,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: spacing),
            FilledButton(
              onPressed: _nameController.text.isEmpty || !nameIsUnique
                  ? null
                  : () {
                      widget.competition.addEventAward(
                        name: _nameController.text,
                        count: _count,
                        spreadTheWealth: _spreadTheWealth,
                        isPlacement: _placement,
                        pitVisit: _pitVisit,
                      );
                      widget.onClosed.call();
                    },
              child: const Text(
                'Add award',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}
