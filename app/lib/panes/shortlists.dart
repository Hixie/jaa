import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import '../widgets.dart';
import '../model/competition.dart';

class ShortlistsPane extends StatefulWidget {
  const ShortlistsPane({super.key, required this.competition});

  final Competition competition;

  @override
  State<ShortlistsPane> createState() => _ShortlistsPaneState();
}

class _ShortlistsPaneState extends State<ShortlistsPane> {
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final FocusNode _teamFocusNode = FocusNode();
  final FocusNode _roomFocusNode = FocusNode();

  Award? _award;
  Team? _team;

  @override
  void dispose() {
    _teamController.dispose();
    _roomController.dispose();
    _teamFocusNode.dispose();
    _roomFocusNode.dispose();
    super.dispose();
  }

  void _handleAwardSelection(Award award) {
    setState(() {
      _award = award;
      if (widget.competition.shortlistsView[award]!.entries.containsKey(_team)) {
        _team = null;
        _teamController.clear();
      }
    });
    _teamFocusNode.requestFocus();
  }

  void _addTeamToShortlist() {
    widget.competition.addToShortlist(_award!, _team!, (room: _roomController.text));
    _teamController.clear();
    _roomController.clear();
    _teamFocusNode.requestFocus();
    setState(() {
      _team = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) {
        List<Award> awards = widget.competition.awardsView.toList();
        awards.sort((Award a, Award b) {
          if (a.category != b.category) {
            if (a.category.isEmpty) {
              return 1;
            }
            if (b.category.isEmpty) {
              return -1;
            }
            return a.category.compareTo(b.category);
          }
          return a.rank.compareTo(b.rank);
        });
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: awards.isEmpty || widget.competition.teamsView.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(indent, indent, 0.0, 0.0),
                    child: Heading('2. Enter Shortlists'),
                  ),
                  if (widget.competition.teamsView.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(indent, indent, indent, 0.0),
                      child: Text('No teams loaded. Use the Setup pane to import a teams list.'),
                    ),
                  if (awards.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(indent, indent, indent, indent),
                      child: Text('No awards loaded. Use the Setup pane to import an awards list.'),
                    ),
                ]
              : [
                  const SizedBox(height: indent),
                  ConstrainedBox(
                    // This stretches the Wrap across the Column as if the mainAxisAlignment was MainAxisAlignment.stretch.
                    constraints: const BoxConstraints(minWidth: double.infinity),
                    child: const Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(indent, 0.0, 0.0, 0.0),
                          child: Heading('2. Enter Shortlists'),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(indent, 0.0, indent, spacing),
                          child: FilledButton(
                            onPressed: null, // TODO: exports the shortlists per award
                            child: Text(
                              'Export (HTML)',
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (awards.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(indent, spacing * 2.0, indent, indent),
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final Award award in awards)
                            if (!award.isInspire)
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: award.color,
                                  foregroundColor: textColorForColor(award.color),
                                  side: award.color.computeLuminance() > 0.9 ? const BorderSide(color: Colors.black, width: 0.0) : null,
                                ),
                                onPressed: () => _handleAwardSelection(award),
                                child: Text(
                                  award.name,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        ],
                      ),
                    ),
                  if (_award != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, 0.0),
                      child: Theme(
                        data: ThemeData.from(
                          colorScheme: ColorScheme.fromSeed(seedColor: _award!.color),
                        ),
                        child: Card(
                          child: Stack(
                            children: [
                              ListenableBuilder(
                                listenable: widget.competition.shortlistsView[_award]!,
                                builder: (BuildContext context, Widget? child) {
                                  Set<Team> shortlistedTeams = widget.competition.shortlistsView[_award]!.entries.keys.toSet();
                                  List<Team> remainingTeams = widget.competition.teamsView.where((Team team) => !shortlistedTeams.contains(team)).toList();
                                  if (remainingTeams.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(indent, indent - spacing, indent + spacing, indent - spacing),
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(text: 'All the teams have already been shortlisted for the '),
                                            TextSpan(text: _award!.name, style: bold),
                                            TextSpan(text: ' (rank ${_award!.rank} award) award!'),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(indent, indent - spacing, indent, indent),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(text: 'Add team to '),
                                              TextSpan(text: _award!.name, style: bold),
                                              TextSpan(text: ' (rank ${_award!.rank} award) shortlist:'),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: spacing),
                                        LayoutBuilder(
                                          builder: (BuildContext context, BoxConstraints constraints) => HorizontalScrollbar(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(minWidth: constraints.maxWidth, maxWidth: math.max(constraints.maxWidth, 500.0)),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    DropdownMenu<Team>(
                                                      // focusNode: _teamFocusNode,
                                                      controller: _teamController,
                                                      onSelected: (Team? team) {
                                                        _roomFocusNode.requestFocus();
                                                        setState(() {
                                                          _team = team;
                                                        });
                                                      },
                                                      requestFocusOnTap: true,
                                                      enableFilter: true,
                                                      menuStyle: MenuStyle(
                                                        maximumSize: MaterialStatePropertyAll(
                                                          Size(constraints.maxWidth, indent * 11.0),
                                                        ),
                                                      ),
                                                      label: const Text(
                                                        'Team',
                                                        softWrap: false,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      dropdownMenuEntries: remainingTeams.map<DropdownMenuEntry<Team>>((Team team) {
                                                        return DropdownMenuEntry<Team>(
                                                          value: team,
                                                          label: '${team.number} ${team.name}',
                                                        );
                                                      }).toList(),
                                                    ),
                                                    const SizedBox(width: indent),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: _roomController,
                                                        focusNode: _roomFocusNode,
                                                        decoration: const InputDecoration(
                                                          label: Text(
                                                            'Room',
                                                            softWrap: false,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          border: OutlineInputBorder(),
                                                        ),
                                                        onSubmitted: (String value) {
                                                          if (_team != null) {
                                                            _addTeamToShortlist();
                                                          } else {
                                                            _teamFocusNode.requestFocus();
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: indent),
                                                    IconButton.filledTonal(
                                                      onPressed: _team != null ? _addTeamToShortlist : null,
                                                      icon: const Icon(
                                                        Icons.group_add,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _award = null;
                                    });
                                  },
                                  iconSize: DefaultTextStyle.of(context).style.fontSize,
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(indent),
                    child: Wrap(
                      runSpacing: spacing,
                      spacing: spacing,
                      children: [
                        for (final Award award in awards)
                          if (!award.isInspire)
                            ListenableBuilder(
                              listenable: widget.competition.shortlistsView[award]!,
                              builder: (BuildContext context, Widget? child) {
                                final Shortlist shortlist = widget.competition.shortlistsView[award]!;
                                final Color foregroundColor = textColorForColor(award.color);
                                final List<MapEntry<Team, ShortlistEntry>> entries = shortlist.entries.entries.toList();
                                entries.sort((MapEntry<Team, ShortlistEntry> a, MapEntry<Team, ShortlistEntry> b) {
                                  return a.key.compareTo(b.key);
                                });
                                return Card(
                                  color: award.color,
                                  child: DefaultTextStyle.merge(
                                    style: TextStyle(color: foregroundColor),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(spacing),
                                          child: Text(award.name),
                                        ),
                                        if (shortlist.entries.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.all(spacing),
                                            child: Text('No teams shortlisted.'),
                                          ),
                                        if (shortlist.entries.isNotEmpty)
                                          Table(
                                            border: TableBorder.symmetric(
                                              inside: BorderSide(color: foregroundColor),
                                            ),
                                            defaultColumnWidth: const IntrinsicColumnWidth(),
                                            children: [
                                              TableRow(
                                                children: [
                                                  const Cell(Text('#', style: bold)),
                                                  const Cell(Text('Room', style: bold)),
                                                  TableCell(
                                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                                    child: Icon(
                                                      Icons.more_vert,
                                                      color: foregroundColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              for (final MapEntry(key: Team team, value: ShortlistEntry entry) in entries)
                                                TableRow(
                                                  children: [
                                                    Tooltip(
                                                      message: team.name,
                                                      child: Cell(
                                                        Text('${team.number}'),
                                                      ),
                                                    ),
                                                    Cell(Text(entry.room)),
                                                    TableCell(
                                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                                      child: IconButton(
                                                        onPressed: () {
                                                          widget.competition.removeFromShortlist(award, team);
                                                        },
                                                        iconSize: DefaultTextStyle.of(context).style.fontSize,
                                                        visualDensity: VisualDensity.compact,
                                                        color: foregroundColor,
                                                        icon: const Icon(
                                                          Icons.group_remove,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
                  ),
                ],
        );
      },
    );
  }
}
