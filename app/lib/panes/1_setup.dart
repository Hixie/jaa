import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../constants.dart';
import '../io.dart';
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
      page.writeln('<th>City');
      page.writeln('<th>Notes');
      page.writeln('<tbody>');
      for (final Team team in competition.teamsView) {
        page.writeln('<tr>');
        page.writeln('<td>${team.number}');
        page.writeln('<td>${escapeHtml(team.name)}');
        page.writeln('<td>${escapeHtml(team.city)}');
        page.writeln('<td>${team.visited ? "Visited." : ""} ${escapeHtml(team.visitingJudgesNotes)}');
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
                          Cell(Text('Team City', style: bold), prototype: Text('Mooselookmeguntic')),
                          Cell(Text('Inspire eligible', style: bold), prototype: Text('Yes')),
                        ],
                      ),
                      for (final Team? team in SetupPane._subsetTable(widget.competition.teamsView, 4, null))
                        TableRow(
                          children: [
                            Cell(Text('${team?.number ?? '...'}')),
                            Cell(Text(team?.name ?? '...')),
                            Cell(Text(team?.city ?? '...')),
                            Cell(Text(
                              team != null
                                  ? team.inspireEligible
                                      ? 'Yes'
                                      : 'No'
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
            child: NewAwardCard(
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
                    children: [
                      TableRow(
                        children: [
                          Cell(Text('Award Name${widget.competition.awardsView.any((Award award) => award.canBeRenamed) ? " ✎_" : ""}', style: bold)),
                          const Cell(
                            Text('Award Type', style: bold),
                            prototype: EventSpecificCell(competition: null, award: null),
                            padPrototype: false,
                          ),
                          const Cell(Text('Award Rank', style: bold), prototype: Text('000')),
                          const Cell(Text('Award Count', style: bold), prototype: Text('000')),
                          const Cell(Text('Inspire Category', style: bold), prototype: Text('Documentation')),
                          const Cell(Text('Spread the wealth', style: bold), prototype: Text('Winner Only')),
                          const Cell(Text('Placement', style: bold), prototype: Text('Yes')),
                          const Cell(Text('Pit Visits', style: bold), prototype: Text('Maybe')),
                        ],
                      ),
                      for (final Award award in widget.competition.awardsView)
                        TableRow(
                          children: [
                            Cell(
                              ListenableBuilder(
                                listenable: award,
                                builder: (BuildContext context, Widget? child) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ColorIndicator(
                                      color: award.color,
                                      width: 12.0,
                                      height: 12.0,
                                      borderRadius: 0.0,
                                      onSelectFocus: false,
                                      onSelect: () async {
                                        Color selectedColor = award.color;
                                        if (await ColorPicker(
                                          // we don't bother updating the name live if it changes in the background
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
                                          award.color = selectedColor;
                                        }
                                      },
                                    ),
                                    const SizedBox(width: spacing),
                                    Expanded(
                                      child: (!award.canBeRenamed)
                                          ? Text(award.name)
                                          : Material(
                                              type: MaterialType.transparency,
                                              child: TextEntryCell(
                                                value: award.name,
                                                onChanged: (String value) {
                                                  award.name = value;
                                                },
                                                padding: EdgeInsets.zero,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            award.isEventSpecific
                                ? EventSpecificCell(competition: widget.competition, award: award)
                                : Cell(
                                    Text(
                                      award.isInspire
                                          ? 'Inspire'
                                          : award.isAdvancing
                                              ? 'Advancing'
                                              : 'Non-Advancing',
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
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(indent, spacing + indent, indent, indent),
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
              splashRadius: 100.0,
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
  final TextEditingController _cityController = TextEditingController();

  Team? _team;

  String get _currentTeamLabel => _team != null ? "${_team!.number} ${_team!.name}" : "";

  @override
  void initState() {
    super.initState();
    _teamController.addListener(_handleTeamTextChange);
    _nameController.addListener(_handleTeamDetailsTextChange);
    _cityController.addListener(_handleTeamDetailsTextChange);
  }

  @override
  void dispose() {
    _teamController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _handleTeamChange(Team? team) {
    setState(() {
      _team = null;
      _nameController.text = team?.name ?? '';
      _cityController.text = team?.city ?? '';
      _team = team;
    });
  }

  void _handleTeamTextChange() {
    // Workaround for https://github.com/flutter/flutter/issues/143505
    if (_teamController.text != _currentTeamLabel) {
      _handleTeamChange(widget.competition.teamsView.cast<Team?>().singleWhere(
            (Team? team) => "${team!.number} ${team.name}" == _teamController.text,
            orElse: () => null,
          ));
    }
  }

  void _handleTeamDetailsTextChange() {
    if (_team != null) {
      widget.competition.updateTeam(_team!, _nameController.text, _cityController.text);
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
                      controller: _cityController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Team City',
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
      if (!_team!.inspireEligible) {
        teamNotes.add(const Text('Team is not eligible for an Inspire award at this event.'));
      }
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
                child: ListenableBuilder(
                  listenable: award,
                  builder: (BuildContext context, Widget? child) => Text.rich(
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
              ),
            ],
          ));
        }
      }
      teamNotes.add(const SizedBox(height: spacing));
      List<Award> pitVisitAwards = _team!.shortlistsView.keys.where((Award award) => award.pitVisits == PitVisit.yes).toList();
      if (pitVisitAwards.isNotEmpty) {
        teamNotes.add(
          ListenableBuilder(
            listenable: Listenable.merge(pitVisitAwards),
            builder: (BuildContext context, Widget? child) => Text(
              'Team will be visited as part of judging for: ${pitVisitAwards.map((Award award) => award.name).join(', ')}',
            ),
          ),
        );
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
                DropdownMenu<Team>(
                  controller: _teamController,
                  onSelected: _handleTeamChange,
                  requestFocusOnTap: true,
                  enableFilter: true,
                  menuStyle: const MenuStyle(
                    maximumSize: MaterialStatePropertyAll(
                      Size(double.infinity, indent * 11.0),
                    ),
                  ),
                  label: const Text(
                    'Team',
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dropdownMenuEntries: widget.competition.teamsView.map<DropdownMenuEntry<Team>>((Team team) {
                    return DropdownMenuEntry<Team>(
                      value: team,
                      label: '${team.number} ${team.name}',
                    );
                  }).toList(),
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

class NewAwardCard extends StatefulWidget {
  const NewAwardCard({
    super.key,
    required this.competition,
    required this.onClosed,
  });

  final Competition competition;
  final VoidCallback onClosed;

  @override
  State<NewAwardCard> createState() => _NewAwardCardState();
}

class _NewAwardCardState extends State<NewAwardCard> {
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
      listenable: Listenable.merge([_nameController, ...widget.competition.awardsView, widget.competition]),
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
