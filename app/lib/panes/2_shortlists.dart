import 'package:flutter/material.dart';

import '../constants.dart';
import '../io.dart';
import '../model/competition.dart';
import '../widgets/awards.dart';
import '../widgets/cells.dart';
import '../widgets/shortlists.dart';
import '../widgets/widgets.dart';

class ShortlistsPane extends StatelessWidget {
  const ShortlistsPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final List<Award> awards = competition.awardsView.where(Award.isNotInspirePredicate).toList()..sort(competition.awardSorter);
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaneHeader(
              title: '2. Enter Shortlists',
              onHeaderButtonPressed: () => exportShortlistsHTML(context, competition),
            ),
            if (competition.teamsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No teams loaded. Use the Setup pane to import a teams list.',
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            if (awards.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No awards loaded. Use the Setup pane to import an awards list.',
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            if (awards.isNotEmpty)
              ShortlistEditor(
                sortedAwards: awards,
                competition: competition,
                lateEntry: false,
              ),
            if (competition.teamsView.isNotEmpty) ShortlistSummary(competition: competition),
            if (awards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Current shortlists:'),
              ),
            if (awards.isNotEmpty)
              ShortlistTables(
                sortedAwards: awards,
                competition: competition,
              ),
            if (awards.isNotEmpty) AwardOrderSwitch(competition: competition),
          ],
        );
      },
    );
  }

  static Future<void> exportShortlistsHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    final StringBuffer page = createHtmlPage('Shortlists', now);
    if (competition.awardsView.isEmpty) {
      page.writeln('<p>No awards loaded.');
    } else {
      for (final Award award in competition.awardsView) {
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
        List<Team> teams = competition.shortlistsView[award]!.entriesView.keys.toList();
        if (teams.isEmpty) {
          page.writeln('<p>No nominees.</p>');
        } else {
          page.writeln('<h3>Nominees:</h3>');
          page.writeln('<ul>');
          for (final Team team in teams) {
            final String nominator = competition.shortlistsView[award]!.entriesView[team]!.nominator;
            page.writeln(
              '<li>' '${team.number} <i>${escapeHtml(team.name)}</i>' '${nominator.isEmpty ? "" : " (nominated by ${escapeHtml(nominator)})"}',
            );
          }
          page.writeln('</ul>');
        }
      }
    }
    return exportHTML(competition, 'shortlists', now, page.toString());
  }
}

class ShortlistTables extends StatelessWidget {
  const ShortlistTables({
    super.key,
    required this.sortedAwards,
    required this.competition,
  });

  final List<Award> sortedAwards;
  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return AwardBuilder(
      sortedAwards: sortedAwards,
      competition: competition,
      builder: (BuildContext context, Award award, Shortlist shortlist) {
        final Color foregroundColor = textColorForColor(award.color);
        final List<MapEntry<Team, ShortlistEntry>> entries = shortlist.entriesView.entries.toList();
        entries.sort((MapEntry<Team, ShortlistEntry> a, MapEntry<Team, ShortlistEntry> b) {
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
                  columnWidths: {1: const IntrinsicCellWidth(flex: 1), 2: FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! + spacing * 2)},
                  defaultColumnWidth: const IntrinsicCellWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    TableRow(
                      children: [
                        const Cell(Text('#', style: bold), prototype: Text('000000')),
                        const Cell(Text('Nominator ✎_', style: bold), prototype: Text('Judging Panel')),
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
                          NominatorCell(entry),
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

class NominatorCell extends StatefulWidget {
  NominatorCell(this.entry) : super(key: ObjectKey(entry));

  final ShortlistEntry entry;

  @override
  State<NominatorCell> createState() => _NominatorCellState();
}

class _NominatorCellState extends State<NominatorCell> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.entry.addListener(_handleTeamUpdate);
    _controller.addListener(_handleTextFieldUpdate);
    _controller.text = widget.entry.nominator;
  }

  @override
  void didUpdateWidget(NominatorCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.entry == oldWidget.entry);
  }

  @override
  void dispose() {
    widget.entry.removeListener(_handleTeamUpdate);
    super.dispose();
  }

  void _handleTeamUpdate() {
    setState(() {
      if (_controller.text != widget.entry.nominator) {
        _controller.text = widget.entry.nominator;
      }
    });
  }

  void _handleTextFieldUpdate() {
    widget.entry.nominator = _controller.text;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = DefaultTextStyle.of(context).style;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacing),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: DefaultTextStyle.of(context).style.fontSize! * 4.0),
        child: TextField(
          controller: _controller,
          decoration: InputDecoration.collapsed(
            hintText: 'none',
            hintStyle: textStyle.copyWith(fontStyle: FontStyle.italic),
          ),
          style: textStyle,
          cursorColor: textStyle.color,
        ),
      ),
    );
  }
}
