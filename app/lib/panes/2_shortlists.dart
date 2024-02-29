import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../constants.dart';
import '../io.dart';
import '../model/competition.dart';
import '../widgets/awards.dart';
import '../widgets/cells.dart';
import '../widgets/shortlists.dart';
import '../widgets/widgets.dart';

class ShortlistsPane extends StatefulWidget {
  const ShortlistsPane({super.key, required this.competition});

  final Competition competition;

  @override
  State<ShortlistsPane> createState() => _ShortlistsPaneState();

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
            final ShortlistEntry entry = competition.shortlistsView[award]!.entriesView[team]!;
            page.writeln(
              '<li>' '${team.number} <i>${escapeHtml(team.name)}</i>' '${entry.nominator.isEmpty ? "" : " (nominated by ${escapeHtml(entry.nominator)})"}',
            );
            if (entry.comment.isNotEmpty) {
              page.writeln('<br><i>${escapeHtml(entry.comment)}</i>');
            }
          }
          page.writeln('</ul>');
        }
      }
    }
    return exportHTML(competition, 'shortlists', now, page.toString());
  }
}

class _ShortlistsPaneState extends State<ShortlistsPane> {
  bool _showComments = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) {
        final List<Award> awards = widget.competition.awardsView.where(Award.isNotInspirePredicate).toList()..sort(widget.competition.awardSorter);
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaneHeader(
              title: '2. Enter Shortlists',
              onHeaderButtonPressed: () => ShortlistsPane.exportShortlistsHTML(context, widget.competition),
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
                competition: widget.competition,
                lateEntry: false,
              ),
            if (widget.competition.teamsView.isNotEmpty)
              ShortlistSummary(
                competition: widget.competition,
              ),
            if (awards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Current shortlists:', style: bold),
              ),
            if (awards.isNotEmpty)
              CheckboxRow(
                checked: _showComments,
                onChanged: (bool value) {
                  setState(() {
                    _showComments = value;
                  });
                },
                label: 'Show nomination comments.',
              ),
            if (awards.isNotEmpty)
              ShortlistTables(
                sortedAwards: awards,
                competition: widget.competition,
                showComments: _showComments,
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

class ShortlistTables extends StatelessWidget {
  const ShortlistTables({
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
                    1: const IntrinsicCellWidth(flex: 1),
                    if (showComments) 2: const IntrinsicCellWidth(flex: 1),
                    (showComments ? 3 : 2): FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! + spacing * 2),
                  },
                  defaultColumnWidth: const IntrinsicCellWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    TableRow(
                      children: [
                        const Cell(Text('#', style: bold), prototype: Text('000000')),
                        const Cell(Text('Nominator ✎_', style: bold), prototype: Text('Judging Panel')),
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
                          Tooltip(
                            message: team.name,
                            child: Cell(
                              Text('${team.number}'),
                            ),
                          ),
                          ListenableBuilder(
                            listenable: entry,
                            builder: (BuildContext context, Widget? child) => TextEntryCell(
                              value: entry.nominator,
                              onChanged: (String value) {
                                entry.nominator = value;
                              },
                              icons: !showComments && entry.comment.isNotEmpty
                                  ? [
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
