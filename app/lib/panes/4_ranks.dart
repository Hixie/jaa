import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../io.dart';
import '../widgets.dart';
import '../model/competition.dart';

class RanksPane extends StatelessWidget {
  const RanksPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final List<Award> awards = competition.awardsView.where(Award.isNotInspirePredicate).toList()..sort(Award.categoryBasedComparator);
        final int lowRoughRank = (competition.teamsView.length * 5.0 / 6.0).round();
        final int middleRoughRank = (competition.teamsView.length * 3.0 / 6.0).round();
        final int highRoughRank = (competition.teamsView.length * 1.0 / 6.0).round();
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaneHeader(
              title: '4. Rank Lists',
              onHeaderButtonPressed: () => exportRanksHTML(context, competition),
            ),
            ShortlistEditor(
              competition: competition,
              sortedAwards: awards,
              lateEntry: true,
            ),
            if (awards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Rankings:'),
              ),
            AwardBuilder(
              sortedAwards: awards,
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
                          defaultColumnWidth: const IntrinsicColumnWidth(),
                          defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            TableRow(
                              children: [
                                const Cell(Text('Rank ✎_', style: bold)),
                                const Cell(Text('#', style: bold)),
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
                                          }),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                    child: IconButton(
                                      onPressed: () {
                                        competition.removeFromShortlist(award, team);
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
                );
              },
            ),
            if (awards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, indent),
                child: Text(
                  'Rough ranks: high=$highRoughRank, middle=$middleRoughRank, low=$lowRoughRank.\n'
                  'Red ranks indicates invalid or duplicate ranks. '
                  'Bold team numbers indicate missing or duplicate ranks. '
                  'Italics indicates late entry nominations.',
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
          ],
        );
      },
    );
  }

  static Future<void> exportRanksHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    final StringBuffer page = createHtmlPage('Ranks', now);
    for (final Award award in competition.awardsView.where(Award.isNotInspirePredicate)) {
      page.writeln('<h2>${award.isSpreadTheWealth ? "#${award.rank}: " : ""}${escapeHtml(award.name)} award</h2>');
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
    return exportHTML(competition, 'ranks', now, page.toString());
  }
}

class RankCell extends StatefulWidget {
  RankCell({
    required this.entry,
    required this.foregroundColor,
    required this.maxRank,
  }) : super(key: ObjectKey(entry));

  final ShortlistEntry entry;
  final Color foregroundColor;
  final int maxRank;

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
