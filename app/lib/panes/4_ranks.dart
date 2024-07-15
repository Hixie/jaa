import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/constants.dart';
import '../utils/io.dart';
import '../model/competition.dart';
import '../widgets/awards.dart';
import '../widgets/cells.dart';
import '../widgets/shortlists.dart';
import '../widgets/widgets.dart';

class RanksPane extends StatelessWidget {
  const RanksPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final List<Award> awards = competition.awardsView.where(Award.isNotInspirePredicate).toList()..sort(competition.awardSorter);
        final int lowRoughRank = (competition.teamsView.length * 5.0 / 6.0).round();
        final int middleRoughRank = (competition.teamsView.length * 3.0 / 6.0).round();
        final int highRoughRank = (competition.teamsView.length * 1.0 / 6.0).round();
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Heading(title: '4. Rank Lists'),
            if (competition.teamsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No teams loaded. Use the Setup pane to import a teams list.',
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            if (competition.teamsView.isNotEmpty)
              ShortlistEditor(
                competition: competition,
                sortedAwards: awards,
                lateEntry: true,
              ),
            if (competition.teamsView.isNotEmpty)
              ShortlistSummary(
                competition: competition,
              ),
            if (awards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Rankings:', style: bold),
              ),
            if (awards.isNotEmpty)
              CheckboxRow(
                checked: showToBool(competition.showNominators),
                onChanged: (bool? value) {
                  competition.showNominators = boolToShow(value);
                },
                tristate: true,
                label: 'Show nominators (always, if any, never).',
              ),
            if (awards.isNotEmpty)
              CheckboxRow(
                checked: showToBool(competition.showNominationComments),
                onChanged: (bool? value) {
                  competition.showNominationComments = boolToShow(value);
                },
                tristate: true,
                label: 'Show nomination comments (always, if any, never).',
              ),
            if (awards.isNotEmpty)
              RankTables(
                sortedAwards: awards,
                competition: competition,
                showNominators: competition.showNominators,
                showComments: competition.showNominationComments,
              ),
            if (awards.isNotEmpty && competition.teamsView.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, spacing),
                child: Text(
                  'Rough ranks: high=$highRoughRank, middle=$middleRoughRank, low=$lowRoughRank.\n'
                  'Red ranks indicates invalid or duplicate ranks. '
                  'Italics indicates late entry nominations. '
                  'Bold team numbers indicate award finalists. '
                  'Strikethrough indicates teams that do not qualify for the award due to spread-the-wealth rules.',
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            if (awards.isNotEmpty)
              AwardOrderSwitch(
                competition: competition,
              ),
          ],
        );
      },
    );
  }

  static Future<void> exportRanksHTML(BuildContext context, Competition competition, List<Award> awards) async {
    final DateTime now = DateTime.now();
    final StringBuffer page = createHtmlPage(competition, 'Ranks', now);
    if (competition.awardsView.isEmpty) {
      page.writeln('<p>No awards loaded.');
    } else {
      final (winningTeams: Map<Award, Set<Team>> winningTeams, disqualifiedTeams: Map<Award, Set<Team>> disqualifiedTeams) =
          RankTables.computeWinnersAndLosers(competition);
      for (final Award award in awards) {
        page.writeln('<h2>${award.spreadTheWealth != SpreadTheWealth.no ? "#${award.rank}: " : ""}${escapeHtml(award.name)} award</h2>');
        final String pitVisits = switch (award.pitVisits) {
          PitVisit.yes => 'does involve',
          PitVisit.no => 'does not involve',
          PitVisit.maybe => 'may involve',
        };
        page.writeln(
          '<p>'
          'Category: ${award.category.isEmpty ? "<i>none</i>" : escapeHtml(award.category)}. '
          '${award.count} ${award.count == 1 ? "winner" : award.isPlacement ? 'ranked places' : 'equal winners'} to be awarded. '
          'Judging ${escapeHtml(pitVisits)} a pit visit.'
          '</p>',
        );
        Map<Team, ShortlistEntry> shortlist = competition.shortlistsView[award]!.entriesView;
        final List<Team> teams = shortlist.keys.toList();
        teams.sort((Team a, Team b) {
          if (shortlist[a]!.rank == shortlist[b]!.rank) {
            return a.number - b.number;
          }
          if (shortlist[a]!.rank == null) {
            return 1;
          }
          if (shortlist[b]!.rank == null) {
            return -1;
          }
          return shortlist[a]!.rank! - shortlist[b]!.rank!;
        });
        if (teams.isEmpty) {
          page.writeln('<p>No nominees.</p>');
        } else {
          page.writeln('<h3>Nominees:</h3>');
          page.writeln('<ol>');
          for (final Team team in teams) {
            final String nominator = competition.shortlistsView[award]!.entriesView[team]!.nominator;
            page.write('<li${shortlist[team]!.rank != null ? " value=${shortlist[team]!.rank!}" : ""}>');
            if (disqualifiedTeams[award]!.contains(team)) {
              page.write('<s>');
            }
            if (winningTeams[award]!.contains(team)) {
              page.write('<b>');
            }
            page.write('${team.number}');
            if (disqualifiedTeams[award]!.contains(team)) {
              page.write('</s>');
            }
            if (winningTeams[award]!.contains(team)) {
              page.write('</b>');
            }
            page.write(' <i>${escapeHtml(team.name)}</i>');

            page.writeln(
              nominator.isEmpty ? "" : " (nominated by ${escapeHtml(nominator)})",
            );
          }
          page.writeln('</ol>');
        }
      }
    }
    String suffix = awards.length == 1 ? escapeFilename(awards.single.name) : "all";
    return exportHTML(competition, 'ranks.$suffix', now, page.toString());
  }
}

class RankTables extends StatelessWidget {
  const RankTables({
    super.key,
    required this.sortedAwards,
    required this.competition,
    required this.showNominators,
    required this.showComments,
  });

  final List<Award> sortedAwards;
  final Competition competition;
  final Show showNominators;
  final Show showComments;

  static ({Map<Award, Set<Team>> winningTeams, Map<Award, Set<Team>> disqualifiedTeams}) computeWinnersAndLosers(Competition competition) {
    final List<(Award, List<AwardFinalistEntry>)> finalists = competition.computeFinalists();
    final Map<Award, Set<Team>> disqualifiedTeams = {};
    final Map<Award, Set<Team>> winningTeams = {};
    for (final (Award award, List<AwardFinalistEntry> finalistEntries) in finalists) {
      disqualifiedTeams[award] = {};
      winningTeams[award] = {};
      // ignore: unused_local_variable
      for (final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool overridden) in finalistEntries) {
        if (otherAward != null) {
          disqualifiedTeams[award]!.add(team!);
        } else if (team != null) {
          winningTeams[award]!.add(team);
        }
      }
    }
    return (winningTeams: winningTeams, disqualifiedTeams: disqualifiedTeams);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final (winningTeams: Map<Award, Set<Team>> winningTeams, disqualifiedTeams: Map<Award, Set<Team>> disqualifiedTeams) =
            computeWinnersAndLosers(competition);
        return AwardBuilder(
          sortedAwards: sortedAwards,
          competition: competition,
          builder: (BuildContext context, Award award, Shortlist shortlist) {
            final Color foregroundColor = textColorForColor(award.color);
            final List<MapEntry<Team, ShortlistEntry>> entries = shortlist.entriesView.entries.toList()
              ..sort((MapEntry<Team, ShortlistEntry> a, MapEntry<Team, ShortlistEntry> b) {
                return a.key.compareTo(b.key);
              });
            final bool includeNominatorColumn = (showNominators == Show.all) ||
                (showNominators == Show.ifNeeded && entries.any((MapEntry<Team, ShortlistEntry> entry) => entry.value.nominator.isNotEmpty));
            final bool includeCommentsColumn = (showComments == Show.all) ||
                (showComments == Show.ifNeeded && entries.any((MapEntry<Team, ShortlistEntry> entry) => entry.value.comment.isNotEmpty));
            return ShortlistCard(
              award: award,
              child: shortlist.entriesView.isEmpty
                  ? null
                  : Table(
                      border: TableBorder.symmetric(
                        inside: BorderSide(color: foregroundColor),
                      ),
                      columnWidths: {
                        0: IntrinsicCellWidth(flex: includeNominatorColumn || includeCommentsColumn ? 1 : null),
                        if (includeNominatorColumn) 2: const IntrinsicCellWidth(flex: 1),
                        if (includeCommentsColumn) (includeNominatorColumn ? 3 : 2): const IntrinsicCellWidth(flex: 1),
                        (includeCommentsColumn && includeNominatorColumn
                            ? 4
                            : includeCommentsColumn || includeNominatorColumn
                                ? 3
                                : 2): FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! + spacing * 2),
                      },
                      defaultColumnWidth: const IntrinsicCellWidth(),
                      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        TableRow(
                          children: [
                            const Cell(Text('Rank ✎_', style: bold), prototype: Text('000')),
                            const Cell(Text('#', style: bold), prototype: Text('000000')),
                            if (includeNominatorColumn) const Cell(Text('Nominator ✎_', style: bold), prototype: Text('Judging Panel')),
                            if (includeCommentsColumn) const Cell(Text('Comments ✎_', style: bold), prototype: Text('This is a medium-length comment.')),
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
                              ListenableBuilder(
                                listenable: entry, // for lateEntry, tied, nominator, and comment
                                builder: (BuildContext context, Widget? child) => RankCell(
                                  value: entry.rank,
                                  onChanged: (int? value) {
                                    competition.updateShortlistRank(award, team, value);
                                  },
                                  lateEntry: entry.lateEntry,
                                  tied: entry.tied,
                                  winner: winningTeams[award]!.contains(team),
                                  disqualified: disqualifiedTeams[award]!.contains(team),
                                  foregroundColor: foregroundColor,
                                  minimum: 1,
                                  maximum: entries.length,
                                  icons: [
                                    if (entry.nominator.isNotEmpty && !includeNominatorColumn)
                                      Tooltip(
                                        message: entry.nominator,
                                        child: Icon(
                                          Symbols.people,
                                          size: DefaultTextStyle.of(context).style.fontSize,
                                          color: foregroundColor,
                                        ),
                                      ),
                                    if (entry.comment.isNotEmpty && !includeCommentsColumn)
                                      Tooltip(
                                        message: entry.comment,
                                        child: Icon(
                                          Symbols.mark_unread_chat_alt,
                                          size: DefaultTextStyle.of(context).style.fontSize,
                                          color: foregroundColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Tooltip(
                                message: team.name,
                                child: Cell(
                                  ListenableBuilder(
                                    listenable: entry,
                                    builder: (BuildContext context, Widget? child) {
                                      return Text(
                                        '${team.number}',
                                        style: _styleFor(
                                          context,
                                          lateEntry: entry.lateEntry,
                                          winner: winningTeams[award]!.contains(team),
                                          disqualified: disqualifiedTeams[award]!.contains(team),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              if (includeNominatorColumn)
                                TextEntryCell(
                                  value: entry.nominator,
                                  onChanged: (String value) {
                                    entry.nominator = value;
                                  },
                                ),
                              if (includeCommentsColumn)
                                ListenableBuilder(
                                  listenable: entry,
                                  builder: (BuildContext context, Widget? child) => TextEntryCell(
                                    value: entry.comment,
                                    onChanged: (String value) {
                                      entry.comment = value;
                                    },
                                  ),
                                ),
                              RemoveFromShortlistCell(
                                competition: competition,
                                team: team,
                                award: award,
                                foregroundColor: foregroundColor,
                              ),
                            ],
                          ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

class RankCell extends StatefulWidget {
  const RankCell({
    super.key,
    required this.value,
    required this.onChanged,
    required this.lateEntry,
    required this.tied,
    required this.winner,
    required this.disqualified,
    required this.foregroundColor,
    required this.minimum,
    required this.maximum,
    this.icons,
  }) : _valueAsString = value == null ? '' : '$value';

  final int? value;
  final ValueSetter<int?> onChanged;
  final bool lateEntry;
  final bool tied;
  final bool winner;
  final bool disqualified;
  final Color foregroundColor;
  final int minimum;
  final int maximum;
  final List<Widget>? icons;

  final String _valueAsString;

  @override
  State<RankCell> createState() => _RankCellState();
}

class _RankCellState extends State<RankCell> {
  final TextEditingController _controller = TextEditingController();
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextFieldUpdate);
    _controller.text = widget._valueAsString;
    _updateError();
  }

  @override
  void didUpdateWidget(RankCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (_controller.text != widget._valueAsString) {
        _controller.text = widget._valueAsString;
      }
    }
    _updateError();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateError() {
    _error = widget.value == null || widget.value! > widget.maximum || widget.value! < widget.minimum || widget.tied;
  }

  void _handleTextFieldUpdate() {
    widget.onChanged(_controller.text == '' ? null : int.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = _styleFor(context, lateEntry: widget.lateEntry, winner: widget.winner, disqualified: widget.disqualified);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacing),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              width: DefaultTextStyle.of(context).style.fontSize! * 4.0,
              child: TextField(
                controller: _controller,
                decoration: InputDecoration.collapsed(
                  hintText: '·',
                  hintStyle: textStyle,
                ),
                style: _error
                    ? textStyle.copyWith(
                        color: Colors.red,
                        shadows: const [Shadow(color: Colors.white, blurRadius: 3.0)],
                      )
                    : textStyle,
                cursorColor: textStyle.color,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                keyboardType: TextInputType.number,
              ),
            ),
          ),
          ...?widget.icons,
        ],
      ),
    );
  }
}

TextStyle _styleFor(BuildContext context, {required bool lateEntry, required bool winner, required bool disqualified}) {
  TextStyle result = DefaultTextStyle.of(context).style;
  if (winner) {
    result = result.copyWith(fontWeight: FontWeight.bold);
  }
  if (lateEntry) {
    result = result.copyWith(fontStyle: FontStyle.italic);
  }
  if (disqualified) {
    result = result.copyWith(decoration: TextDecoration.lineThrough, decorationColor: result.color);
  }
  return result;
}
