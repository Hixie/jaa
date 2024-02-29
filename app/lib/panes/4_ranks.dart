import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../constants.dart';
import '../io.dart';
import '../model/competition.dart';
import '../widgets/awards.dart';
import '../widgets/cells.dart';
import '../widgets/shortlists.dart';
import '../widgets/widgets.dart';

class RanksPane extends StatefulWidget {
  const RanksPane({super.key, required this.competition});

  final Competition competition;

  @override
  State<RanksPane> createState() => _RanksPaneState();

  static Future<void> exportRanksHTML(BuildContext context, Competition competition, List<Award> awards) async {
    final DateTime now = DateTime.now();
    final StringBuffer page = createHtmlPage('Ranks', now);
    if (competition.awardsView.isEmpty) {
      page.writeln('<p>No awards loaded.');
    } else {
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
          '${award.count} ${award.isPlacement ? 'ranked places to be awarded.' : 'equal winners to be awarded.'} '
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
            page.writeln(
              '<li${shortlist[team]!.rank != null ? " value=${shortlist[team]!.rank!}" : ""}>'
              '${team.number} <i>${escapeHtml(team.name)}</i>'
              '${nominator.isEmpty ? "" : " (nominated by ${escapeHtml(nominator)})"}',
            );
          }
          page.writeln('</ol>');
        }
      }
    }
    return exportHTML(competition, 'ranks', now, page.toString());
  }
}

class _RanksPaneState extends State<RanksPane> {
  bool _showComments = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) {
        final List<Award> awards = widget.competition.awardsView.where(Award.isNotInspirePredicate).toList()..sort(widget.competition.awardSorter);
        final int lowRoughRank = (widget.competition.teamsView.length * 5.0 / 6.0).round();
        final int middleRoughRank = (widget.competition.teamsView.length * 3.0 / 6.0).round();
        final int highRoughRank = (widget.competition.teamsView.length * 1.0 / 6.0).round();
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaneHeader(
              title: '4. Rank Lists',
              onHeaderButtonPressed: () => RanksPane.exportRanksHTML(context, widget.competition, awards),
            ),
            if (widget.competition.teamsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No teams loaded. Use the Setup pane to import a teams list.',
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            if (widget.competition.teamsView.isNotEmpty)
              ShortlistEditor(
                competition: widget.competition,
                sortedAwards: awards,
                lateEntry: true,
              ),
            if (widget.competition.teamsView.isNotEmpty)
              ShortlistSummary(
                competition: widget.competition,
              ),
            if (awards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Rankings:', style: bold),
              ),
            if (awards.isNotEmpty)
              CheckboxRow(
                checked: _showComments,
                onChanged: (bool value) {
                  setState(() {
                    _showComments = value;
                  });
                },
                label: 'Show nominators and nomination comments.',
              ),
            if (awards.isNotEmpty)
              RankTables(
                sortedAwards: awards,
                competition: widget.competition,
                showComments: _showComments,
              ),
            if (awards.isNotEmpty && widget.competition.teamsView.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, spacing),
                child: Text(
                  'Rough ranks: high=$highRoughRank, middle=$middleRoughRank, low=$lowRoughRank.\n'
                  'Red ranks indicates invalid or duplicate ranks. '
                  'Bold team numbers indicate missing or duplicate ranks. '
                  'Italics indicates late entry nominations.',
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            if (awards.isNotEmpty)
              AwardOrderSwitch(
                competition: widget.competition,
              ),
          ],
        );
      },
    );
  }
}

class RankTables extends StatelessWidget {
  const RankTables({
    super.key,
    required this.sortedAwards,
    required this.competition,
    required this.showComments,
  });

  final List<Award> sortedAwards;
  final Competition competition;
  final bool showComments;

  @override
  Widget build(BuildContext context) {
    return AwardBuilder(
      sortedAwards: sortedAwards,
      competition: competition,
      builder: (BuildContext context, Award award, Shortlist shortlist) {
        final Color foregroundColor = textColorForColor(award.color);
        final List<MapEntry<Team, ShortlistEntry>> entries = shortlist.entriesView.entries.toList()
          ..sort((MapEntry<Team, ShortlistEntry> a, MapEntry<Team, ShortlistEntry> b) {
            return a.key.compareTo(b.key);
          });
        return ShortlistCard(
          award: award,
          child: shortlist.entriesView.isEmpty
              ? null
              : Table(
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: foregroundColor),
                  ),
                  columnWidths: {
                    0: IntrinsicCellWidth(flex: showComments ? 1 : null),
                    if (showComments) 2: const IntrinsicCellWidth(flex: 1),
                    if (showComments) 3: const IntrinsicCellWidth(flex: 1),
                    (showComments ? 4 : 2): FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! + spacing * 2),
                  },
                  defaultColumnWidth: const IntrinsicCellWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    TableRow(
                      children: [
                        const Cell(Text('Rank ✎_', style: bold), prototype: Text('000')),
                        const Cell(Text('#', style: bold), prototype: Text('000000')),
                        if (showComments) const Cell(Text('Nominator ✎_', style: bold), prototype: Text('Judging Panel')),
                        if (showComments) const Cell(Text('Comments ✎_', style: bold), prototype: Text('This is a medium-length comment.')),
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
                          RankCell(
                            entry: entry,
                            foregroundColor: foregroundColor,
                            maxRank: entries.length,
                            icons: !showComments
                                ? [
                                    if (entry.nominator.isNotEmpty)
                                      Tooltip(
                                        message: entry.nominator,
                                        child: Icon(
                                          Symbols.people,
                                          size: DefaultTextStyle.of(context).style.fontSize,
                                          color: foregroundColor,
                                        ),
                                      ),
                                    if (entry.comment.isNotEmpty)
                                      Tooltip(
                                        message: entry.comment,
                                        child: Icon(
                                          Symbols.mark_unread_chat_alt,
                                          size: DefaultTextStyle.of(context).style.fontSize,
                                          color: foregroundColor,
                                        ),
                                      ),
                                  ]
                                : null,
                          ),
                          Tooltip(
                            message: team.name,
                            child: Cell(
                              ListenableBuilder(
                                listenable: entry,
                                builder: (BuildContext context, Widget? child) {
                                  return Text(
                                    '${team.number}',
                                    style: _styleFor(context, entry),
                                  );
                                },
                              ),
                            ),
                          ),
                          if (showComments)
                            TextEntryCell(
                              value: entry.nominator,
                              onChanged: (String value) {
                                entry.nominator = value;
                              },
                            ),
                          if (showComments)
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
  }
}

class RankCell extends StatefulWidget {
  RankCell({
    required this.entry,
    required this.foregroundColor,
    required this.maxRank,
    this.icons,
  }) : super(key: ObjectKey(entry));

  final ShortlistEntry entry;
  final Color foregroundColor;
  final int maxRank;
  final List<Widget>? icons;

  @override
  State<RankCell> createState() => _RankCellState();
}

class _RankCellState extends State<RankCell> {
  final TextEditingController _controller = TextEditingController();
  bool _error = false;

  String _rankAsString() => widget.entry.rank == null ? '' : widget.entry.rank.toString();

  @override
  void initState() {
    super.initState();
    widget.entry.addListener(_handleEntryUpdate);
    _controller.addListener(_handleTextFieldUpdate);
    _controller.text = _rankAsString();
    _updateError();
  }

  @override
  void didUpdateWidget(RankCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.entry == oldWidget.entry);
    _updateError();
  }

  @override
  void dispose() {
    widget.entry.removeListener(_handleEntryUpdate);
    super.dispose();
  }

  void _updateError() {
    _error = widget.entry.rank == null || widget.entry.rank! > widget.maxRank || widget.entry.rank! < 1;
  }

  void _handleEntryUpdate() {
    setState(() {
      final String newValue = _rankAsString();
      if (_controller.text != newValue) {
        _controller.text = newValue;
      }
      _updateError();
    });
  }

  void _handleTextFieldUpdate() {
    if (_controller.text == '') {
      widget.entry.rank = null;
    } else {
      widget.entry.rank = int.parse(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = _styleFor(context, widget.entry);
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
                style: _error || widget.entry.tied
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

TextStyle _styleFor(BuildContext context, ShortlistEntry entry) {
  TextStyle result = DefaultTextStyle.of(context).style;
  if (entry.tied || entry.rank == null) {
    result = result.copyWith(fontWeight: FontWeight.bold);
  }
  if (entry.lateEntry) {
    result = result.copyWith(fontStyle: FontStyle.italic);
  }
  return result;
}
