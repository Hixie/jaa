import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../constants.dart';
import '../io.dart';
import '../model/competition.dart';
import '../widgets/awards.dart';
import '../widgets/cells.dart';
import '../widgets/widgets.dart';

class AwardFinalistsPane extends StatefulWidget {
  const AwardFinalistsPane({super.key, required this.competition});

  final Competition competition;

  @override
  State<AwardFinalistsPane> createState() => _AwardFinalistsPaneState();

  static Future<void> exportFinalistsTableHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    StringBuffer page = createHtmlPage(competition, 'Finalists', now);
    final List<(Award, List<AwardFinalistEntry>)> finalists = competition.computeFinalists();
    if (competition.awardsView.isEmpty) {
      page.writeln('<p>No awards loaded.');
    } else {
      for (final (Award award, List<AwardFinalistEntry> entry) in finalists) {
        page.writeln(
          '<h2>${award.spreadTheWealth != SpreadTheWealth.no ? "#${award.rank}: " : ""}'
          '${escapeHtml(award.name)} award'
          '${award.category.isNotEmpty ? " (${award.category} category)" : ""}</h2>',
        );
        page.writeln('<table>');
        page.writeln('<thead>');
        page.writeln('<tr>');
        page.writeln('<th>Team');
        page.writeln('<th>Result');
        page.writeln('<tbody>');
        // ignore: unused_local_variable
        for (final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool overridden) in entry) {
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
    }
    return exportHTML(competition, 'finalists', now, page.toString());
  }

  static Future<void> exportFinalistsScriptHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    StringBuffer page = createHtmlPage(competition, 'Awards Ceremony Script', now);
    final List<(Award, List<AwardFinalistEntry>)> finalists = competition.computeFinalists();
    if (competition.awardsView.isEmpty) {
      page.writeln('<p>This event has no awards.');
    } else {
      for (final (Award award, List<AwardFinalistEntry> entry) in finalists.reversed) {
        bool includedHeader = false;
        for (final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool _) in entry.reversed) {
          final bool winner = team != null && otherAward == null && rank <= award.count;
          if (winner) {
            if (!includedHeader) {
              page.writeln(
                '<h2>${award.spreadTheWealth != SpreadTheWealth.no ? "#${award.rank}: " : ""}'
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
    }
    return exportHTML(competition, 'awards_ceremony_script', now, page.toString());
  }
}

class _AwardFinalistsPaneState extends State<AwardFinalistsPane> {
  bool _showOverride = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) {
        final List<(Award, List<AwardFinalistEntry>)> finalists = widget.competition.computeFinalists();
        final Set<Award> emptyAwards = {};
        final Set<Award> tiedAwards = {};
        final Set<Award> overriddenAwards = {};
        final Set<Award> incompleteAwards = {};
        final canShowOverrides = widget.competition.teamsView.isNotEmpty && widget.competition.awardsView.isNotEmpty;
        for (final (Award award, List<AwardFinalistEntry> results) in finalists) {
          bool hasAny = false;
          // ignore: unused_local_variable
          for (final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool overridden) in results) {
            if (team != null && otherAward == null) {
              hasAny = true;
            }
            if (tied) {
              tiedAwards.add(award);
            }
            if (overridden) {
              overriddenAwards.add(award);
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
              headerButtonLabel: _showOverride ? 'Close override editor' : 'Show override editor',
              onHeaderButtonPressed: !canShowOverrides
                  ? null
                  : () {
                      setState(() {
                        _showOverride = !_showOverride;
                      });
                    },
            ),
            if (finalists.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No finalists can be assigned until teams are nominated using the Ranks pane.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (widget.competition.inspireAward != null && emptyAwards.contains(widget.competition.inspireAward))
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No finalists designated for the ${widget.competition.inspireAward!.name} award. '
                  'Use the Inspire pane to assign the ${widget.competition.inspireAward!.name} winner and runner-ups.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (emptyAwards.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'Some awards have no ranked qualifying teams. Use the Ranks pane to assign ranks for teams in award shortlists. '
                  'The following awards are affected: ${emptyAwards.map((Award award) => award.name).join(", ")}.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (emptyAwards.length == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'The ${emptyAwards.single.name} award has no ranked qualifying teams. '
                  'Use the Ranks pane to assign ranks for teams in award shortlists.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (incompleteAwards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'Not all awards have had teams selected for all available places.\n'
                  'For advice with handling difficult cases, consider calling FIRST:\n'
                  '$currentHelp',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (canShowOverrides && _showOverride) OverrideEditor(competition: widget.competition),
            if (overriddenAwards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'Some awards have explicitly placed teams! Check results carefully!',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (finalists.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0.0, spacing, 0.0, indent),
                child: ScrollableRegion(
                  child: Wrap(
                    runSpacing: spacing,
                    spacing: 0.0,
                    children: [
                      for (final (Award award, List<AwardFinalistEntry> awardFinalists) in finalists)
                        ListenableBuilder(
                          listenable: award,
                          builder: (BuildContext context, Widget? child) {
                            final Color foregroundColor = textColorForColor(award.color);
                            return AwardCard(
                              award: award,
                              showAwardRanks: true,
                              child: Table(
                                border: TableBorder.symmetric(
                                  inside: BorderSide(color: foregroundColor),
                                ),
                                columnWidths: <int, TableColumnWidth>{
                                  1: const IntrinsicCellWidth(flex: 1),
                                  2: FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! + spacing * 2)
                                },
                                defaultColumnWidth: MaxColumnWidth(
                                  const IntrinsicCellWidth(),
                                  FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! * 5.0),
                                ),
                                defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  TableRow(
                                    children: [
                                      const Cell(Text('#', style: bold), prototype: Text('000000')),
                                      Cell(Text(award.isPlacement ? 'Ranks' : 'Results', style: bold), prototype: const Text('Unlikely result')),
                                      if (overriddenAwards.contains(award))
                                        TableCell(
                                          verticalAlignment: TableCellVerticalAlignment.middle,
                                          child: Icon(
                                            Icons.more_vert,
                                            color: foregroundColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                  for (final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool overridden) in awardFinalists)
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
                                        if (overriddenAwards.contains(award))
                                          overridden
                                              ? RemoveOverrideCell(
                                                  competition: widget.competition,
                                                  award: award,
                                                  team: team!,
                                                  rank: rank,
                                                  foregroundColor: foregroundColor,
                                                )
                                              : const SizedBox.shrink(),
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
              ),
            const SizedBox(height: indent)
          ],
        );
      },
    );
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

class OverrideEditor extends StatefulWidget {
  OverrideEditor({
    required this.competition,
  }) : super(key: ValueKey<Competition>(competition));

  final Competition competition;

  @override
  State<OverrideEditor> createState() => _OverrideEditorState();
}

class _OverrideEditorState extends State<OverrideEditor> {
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _rankController = TextEditingController();
  final FocusNode _teamFocusNode = FocusNode();
  final FocusNode _rankFocusNode = FocusNode();

  Award? _award;
  Team? _team;
  int? _rank;

  @override
  void initState() {
    super.initState();
    _teamController.addListener(_handleTeamTextChange);
    _rankController.addListener(_handleRankTextChange);
    widget.competition.addListener(_markNeedsBuild);
  }

  @override
  void didUpdateWidget(covariant OverrideEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.competition == oldWidget.competition);
  }

  @override
  void dispose() {
    widget.competition.removeListener(_markNeedsBuild);
    _teamController.dispose();
    _rankController.dispose();
    _teamFocusNode.dispose();
    _rankFocusNode.dispose();
    super.dispose();
  }

  void _markNeedsBuild() {
    setState(() {
      // build is depenendent on the competition object
    });
  }

  void _handleAwardSelection(Award award) {
    if (_award == award) {
      if (_teamController.text.isEmpty && _rankController.text.isEmpty) {
        setState(() {
          _award = null;
        });
      } else {
        _teamFocusNode.requestFocus();
      }
    } else {
      setState(() {
        _award = award;
        if (_rank != null) {
          if (_rank! > _award!.count) {
            _rank = null;
          }
        }
      });
      _teamFocusNode.requestFocus();
    }
  }

  void _handleTeamChange(Team? team) {
    _rankFocusNode.requestFocus();
    setState(() {
      _team = team;
    });
  }

  void _handleTeamTextChange() {
    // Workaround for https://github.com/flutter/flutter/issues/143505
    if (_teamController.text != (_team != null ? "${_team!.number} ${_team!.name}" : "")) {
      Team? team = widget.competition.teamsView.cast<Team?>().singleWhere(
            (Team? team) => "${team!.number} ${team.name}" == _teamController.text,
            orElse: () => null,
          );
      setState(() {
        _team = team;
      });
    }
  }

  void _handleRankTextChange() {
    setState(() {
      if (_rankController.text == '') {
        _rank = null;
      } else {
        _rank = int.parse(_rankController.text);
        if (_rank! < 1 || _rank! > _award!.count) {
          _rank = null;
        }
      }
    });
  }

  void _addOverride() {
    widget.competition.addOverride(
      _award!,
      _team!,
      _rank!,
    );
    _teamController.clear();
    _rankController.clear();
    setState(() {
      _award = null;
      _team = null;
      _rank = null;
    });
  }

  static final Key _cardKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return ListBody(
      children: [
        if (widget.competition.awardsView.isNotEmpty && widget.competition.teamsView.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: AwardSelector(
              label: 'Override rankings for:',
              awards: widget.competition.awardsView,
              onPressed: _handleAwardSelection,
            ),
          ),
        if (_award != null)
          Padding(
            key: _cardKey,
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: ListenableBuilder(
              listenable: _award!,
              child: ListenableBuilder(
                listenable: widget.competition.shortlistsView[_award]!,
                builder: (BuildContext context, Widget? child) => InlineScrollableCard(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Override placement for '),
                          TextSpan(text: _award!.name, style: bold),
                          TextSpan(text: ' (${_award!.description}):'),
                        ],
                      ),
                    ),
                    const SizedBox(height: spacing),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownMenu<Team>(
                          focusNode: _teamFocusNode,
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
                        const SizedBox(width: spacing),
                        SizedBox(
                          width: DefaultTextStyle.of(context).style.fontSize! * 6.0,
                          child: TextField(
                            controller: _rankController,
                            focusNode: _rankFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Rank',
                              hintText: '1..${_award!.count}',
                              border: const OutlineInputBorder(),
                            ),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            keyboardType: TextInputType.number,
                            onSubmitted: (String value) {
                              if (_team == null) {
                                _teamFocusNode.requestFocus();
                              } else if (_rank == null) {
                                _rankFocusNode.requestFocus();
                              } else {
                                _addOverride();
                              }
                            },
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: spacing),
                        IconButton.filledTonal(
                          onPressed: _team != null && _rank != null ? _addOverride : null,
                          icon: const Icon(
                            Symbols.playlist_add,
                          ),
                        ),
                      ],
                    ),
                  ],
                  onClosed: () {
                    setState(() {
                      _award = null;
                      _team = null;
                      _rank = null;
                      _teamController.clear();
                      _rankController.clear();
                    });
                  },
                ),
              ),
              builder: (BuildContext context, Widget? child) {
                return Theme(
                  data: ThemeData.from(
                    colorScheme: ColorScheme.fromSeed(seedColor: _award!.color),
                  ),
                  child: child!,
                );
              },
            ),
          ),
      ],
    );
  }
}

class RemoveOverrideCell extends StatelessWidget {
  const RemoveOverrideCell({
    super.key,
    required this.competition,
    required this.award,
    required this.team,
    required this.rank,
    required this.foregroundColor,
  });

  final Competition competition;
  final Award award;
  final Team team;
  final int rank;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: IconButton(
        tooltip: 'Remove override',
        onPressed: () {
          competition.removeOverride(award, team, rank);
        },
        padding: EdgeInsets.zero,
        iconSize: DefaultTextStyle.of(context).style.fontSize,
        visualDensity: VisualDensity.compact,
        color: foregroundColor,
        icon: const Icon(
          Symbols.playlist_remove,
        ),
      ),
    );
  }
}
