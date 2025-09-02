import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/constants.dart';
import '../utils/io.dart';
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
            const Heading(
              title: '2. Enter Shortlists',
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
            if (competition.teamsView.isNotEmpty)
              ShortlistSummary(
                competition: competition,
              ),
            if (awards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Current shortlists:', style: bold),
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
              ShortlistTables(
                sortedAwards: awards,
                competition: competition,
                showComments: competition.showNominationComments,
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

  static Future<void> exportShortlistsHTML(BuildContext context, Competition competition, List<Award> awards) async {
    final DateTime now = DateTime.now();
    final StringBuffer page = createHtmlPage(competition, 'Shortlists', now);
    if (awards.isEmpty) {
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
          '${award.count} ${award.count == 1 ? "winner" : award.isPlacement ? 'ranked places' : 'equal winners'} to be awarded. '
          'Judging ${escapeHtml(pitVisits)} a pit visit.'
          '</p>',
        );
        List<Team> teams = competition.shortlistsView[award]!.entriesView.keys.toList()..sort((Team a, Team b) => a.number - b.number);
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
    String suffix = awards.length == 1 ? escapeFilename(awards.single.name) : "all";
    return exportHTML(competition, 'shortlists.$suffix', now, page.toString());
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
  final Show showComments;

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
        bool includeCommentsColumn = (showComments == Show.all) ||
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
                    1: const IntrinsicCellWidth(flex: 1),
                    if (includeCommentsColumn) 2: const IntrinsicCellWidth(flex: 1),
                    (includeCommentsColumn ? 3 : 2): FixedColumnWidth(DefaultTextStyle.of(context).style.fontSize! + spacing * 2),
                  },
                  defaultColumnWidth: const IntrinsicCellWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    TableRow(
                      children: [
                        Cell(Text('#', style: bold), prototype: Text('000000${award.needsPortfolio ? ' (X)' : ''}')), // leaves space for no-portfolio icon
                        const Cell(Text('Nominator ✎_', style: bold), prototype: Text('Autonominated')),
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
                          Tooltip(
                            message: team.name,
                            child: Cell(
                              Text('${team.number}'),
                              icons: (award.needsPortfolio && !team.hasPortfolio) || (team.inspireStatus == InspireStatus.exhibition)
                                  ? [
                                      if (team.inspireStatus == InspireStatus.exhibition)
                                        Tooltip(
                                          message: 'Team is an exhibition team and is not eligible for any awards!',
                                          child: Icon(
                                            Symbols.cruelty_free, // bunny
                                            size: DefaultTextStyle.of(context).style.fontSize,
                                            color: foregroundColor,
                                          ),
                                        ),
                                      if (award.needsPortfolio && !team.hasPortfolio)
                                        Tooltip(
                                          message: 'Team is missing a portfolio!',
                                          child: Icon(
                                            Symbols.content_paste_off, // clipboard crossed out
                                            size: DefaultTextStyle.of(context).style.fontSize,
                                            color: foregroundColor,
                                          ),
                                        ),
                                    ]
                                  : null,
                            ),
                          ),
                          ListenableBuilder(
                            listenable: entry,
                            builder: (BuildContext context, Widget? child) => TextEntryCell(
                              value: entry.nominator,
                              onChanged: (String value) {
                                entry.nominator = value;
                              },
                              icons: !includeCommentsColumn && entry.comment.isNotEmpty
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
  }
}
