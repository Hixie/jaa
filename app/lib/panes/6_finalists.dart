import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/constants.dart';
import '../utils/io.dart';
import '../model/competition.dart';
import '../widgets/awards.dart';
import '../widgets/cells.dart';
import '../widgets/widgets.dart';
import '../widgets/selectors.dart';

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
        for (final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) in entry) {
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
        bool multipleWinners = !award.isPlacement && entry.length > 1;
        // ignore: unused_local_variable
        for (final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) in entry.reversed) {
          final bool winner = team != null && otherAward == null && rank <= award.count;
          if (winner) {
            if (!includedHeader) {
              page.writeln(
                '<h2>${award.spreadTheWealth != SpreadTheWealth.no ? "#${award.rank}: " : ""}'
                '${escapeHtml(award.name)} award${multipleWinners ? "s" : ""}'
                '${award.category.isNotEmpty ? " (${award.category} category)" : ""}</h2>',
              );
              includedHeader = true;
            }
            if (!award.isPlacement) {
              page.writeln('<h3>${escapeHtml(team.awardSubnamesView[award] ?? award.name)}</h3>');
            }
            if (team.blurbsView.containsKey(award)) {
              page.writeln('<blockquote>${team.blurbsView[award]}</blockquote>');
            }
            page.writeln(
              '<p>'
              '${tied ? "Tied for " : ""}${escapeHtml(award.isPlacement ? placementDescriptor(rank) : "Win")}: '
              '${team.number} <i>${escapeHtml(team.name)}</i> from ${escapeHtml(team.location)}',
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
        final Set<Award> invalidAwards = {};
        final bool canShowOverrides = widget.competition.teamsView.isNotEmpty && widget.competition.awardsView.isNotEmpty;
        final int highestRank = widget.competition.awardsView.map((Award award) => award.count).fold<int>(0, math.max);
        final Map<int, Map<Team, Set<Award>>> awardCandidates = {};
        final Map<Award, Set<Team>> awardWinners = {};
        final Map<Team, Set<Award>> wealthWinners = {}; // teams who are no longer eligible for spread-the-wealth awards
        bool haveAssignableWinners = false;
        int? assignPlace;
        final Map<Award, List<Team?>> finalistsAsMap = {};
        final Map<Award, List<Set<Team>>> shortlists = {};
        if (!widget.competition.applyFinalistsByAwardRanking) {
          finalists.sort(((Award, List<AwardFinalistEntry>) a, (Award, List<AwardFinalistEntry>) b) => widget.competition.awardSorter(a.$1, b.$1));

          // prepare the result map
          for (int rank = 1; rank <= highestRank; rank += 1) {
            awardCandidates[rank] = <Team, Set<Award>>{};
          }
          // prepare a map where, for each award, we record the ranks that already have an assigned winner
          final Map<Award, Set<int>> claimedAwards = {};
          for (final Award award in widget.competition.awardsView) {
            claimedAwards[award] = <int>{};
          }
          // record the teams who have already been assigned an award (either automatically, manually, or via override)
          for (final (Award award, List<AwardFinalistEntry> awardFinalists) in finalists) {
            finalistsAsMap[award] = <Team?>[];
            // ignore: unused_local_variable
            for (final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) in awardFinalists) {
              if (team != null && otherAward == null) {
                claimedAwards[award]!.add(rank);
                finalistsAsMap[award]!.add(team);
                if ((award.spreadTheWealth == SpreadTheWealth.allPlaces)
                    || (award.spreadTheWealth == SpreadTheWealth.winnerOnly && rank == 1)) {
                  wealthWinners.putIfAbsent(team, () => <Award>{}).add(award);
                }
              } else {
                finalistsAsMap[award]!.add(null);
              }
            }
          }
          // get the waitlists ready (which teams are next eligible for each award)
          for (final Award award in widget.competition.awardsView) {
            shortlists[award] = widget.competition.shortlistsView[award]?.asRankedList() ?? <Set<Team>>[];
          }
          // remove empty groups
          for (final Award award in shortlists.keys) {
            for (int index = 0; index < shortlists[award]!.length; index += 1) {
              if (award.spreadTheWealth != SpreadTheWealth.no) {
                shortlists[award]![index].removeAll(wealthWinners.keys);
              } else {
                shortlists[award]![index].removeAll(awardWinners[award]!);
              }
            }
          }

          // compute which teams are eligible for which awards at which ranks (excluding teams who have already won an award)
          // this is teams listed at the nth non-empty group for this award, when you remove the winners
          for (int rank = 1; rank <= highestRank; rank += 1) {
            for (final Award award in widget.competition.awardsView) {
              if ((award.count < rank) || // award doesn't have this many ranks
                  claimedAwards[award]!.contains(rank) || // award already has a winner at this rank
                  (shortlists[award]!.length < rank)) { // award doesn't have this many shortlisted teams
                continue;
              }
              int count = claimedAwards[award]!.where((int candidate) => candidate < rank).length;
              int index = 0;
              while (count < rank && index < shortlists[award]!.length) {
                final Set<Team> candidates = shortlists[award]![index];
                if (candidates.isNotEmpty) {
                  count += 1;
                  for (Team team in candidates) {
                    awardCandidates[rank]!.putIfAbsent(team, () => <Award>{}).add(award);
                    haveAssignableWinners = true;
                  }
                }
                index += 1;
              }
            }
          }
          for (int place = 1; place <= highestRank; place += 1) {
            if (awardCandidates[place]!.isNotEmpty) {
              assignPlace = place;
              break;
            }
          }
          assert(haveAssignableWinners == (assignPlace != null));
        }
        // Remove non-winning finalists if necessary.
        if (!widget.competition.showWorkings && widget.competition.applyFinalistsByAwardRanking) {
          // ignore: unused_local_variable
          for (final (Award award, List<AwardFinalistEntry> results) in finalists) {
            results.removeWhere((AwardFinalistEntry entry) {
              // ignore: unused_local_variable
              final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) = entry;
              return (otherAward != null || (award.isInspire && rank > 1));
            });
          }
        }
        // Check the currently assigned awards for issues.
        for (final (Award award, List<AwardFinalistEntry> results) in finalists) {
          bool hasAny = false;
          // ignore: unused_local_variable
          for (final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) in results) {
            if (team != null && otherAward == null) {
              hasAny = true;
              awardWinners.putIfAbsent(award, () => <Team>{}).add(team);
              if (award.needsPortfolio && !team.hasPortfolio) {
                invalidAwards.add(award);
              }
              if (team.inspireStatus == InspireStatus.exhibition) {
                invalidAwards.add(award);
              }
            }
            if (tied) {
              tiedAwards.add(award);
            }
            if (kind != FinalistKind.automatic) {
              overriddenAwards.add(award);
            }
            if (team == null) {
              incompleteAwards.add(award);
            }
          }
          if (!hasAny && (widget.competition.applyFinalistsByAwardRanking || shortlists[award]!.every((Set<Team> group) => group.isEmpty))) {
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
                  'Some awards have no ranked qualifying teams. Use the Ranks pane to assign ranks for teams in award shortlists.\n'
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
                  'Not all awards have had teams selected for all available places.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (invalidAwards.length == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'The ${invalidAwards.single.name} award is currently assigned to an ineligible team!',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (invalidAwards.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'Some awards are currently assigned to ineligible teams!\n'
                  'The following awards are affected: ${invalidAwards.map((Award award) => award.name).join(", ")}.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (finalists.isNotEmpty && (emptyAwards.isNotEmpty || incompleteAwards.isNotEmpty || invalidAwards.isNotEmpty))
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'For advice with handling difficult cases, consider calling FIRST: '
                  '${eventHelp.replaceAll(' ', '\u00A0')}',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (canShowOverrides && _showOverride) OverrideEditor(competition: widget.competition),
            if (widget.competition.applyFinalistsByAwardRanking && overriddenAwards.isNotEmpty)
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
                padding: const EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Finalists:', style: bold),
              ),
            if (finalists.isNotEmpty && widget.competition.applyFinalistsByAwardRanking)
              CheckboxRow(
                checked: widget.competition.showWorkings,
                onChanged: (bool? value) {
                  widget.competition.showWorkings = value!;
                },
                tristate: false,
                label: 'Show finalists that did not win (e.g. by virtue of winning a higher-tier award).',
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
                                      Cell(Text('#', style: bold), prototype: Text('${widget.competition.teamsView.last.number} WW')), // longest team number plus icon(s)
                                      Cell(Text('Award', style: bold), prototype: const Text('Invalid 2nd WW')),
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
                                  for (final (Team? team, Award? otherAward, int rank, tied: bool tied, kind: FinalistKind kind) in awardFinalists)
                                    TableRow(
                                      children: [
                                        if (team != null)
                                          Tooltip(
                                            message: team.name,
                                            child: Cell(
                                              Text(
                                                '${team.number}',
                                                style: otherAward != null || (award.isInspire && rank > 1) ? null : bold,
                                              ),
                                            ),
                                          )
                                        else
                                          const ErrorCell(message: 'missing'),
                                        if (team != null &&
                                            (team.inspireStatus == InspireStatus.exhibition ||
                                             (award.isInspire && team.inspireStatus == InspireStatus.ineligible) ||
                                             (award.needsPortfolio && !team.hasPortfolio)))
                                          ErrorCell(
                                            message: award.isPlacement
                                                  ? 'Invalid ${placementDescriptor(rank)}'
                                                  : rank <= award.count
                                                      ? 'Invalid Win'
                                                      : 'Invalid Runner-Up',
                                            icons: <Widget>[
                                              if (team.inspireStatus == InspireStatus.ineligible)
                                                Tooltip(
                                                  message: 'Team has already won the Inspire award this season!',
                                                  child: Icon(
                                                    Symbols.social_leaderboard, // medal
                                                  ),
                                                ),
                                              if (team.inspireStatus == InspireStatus.exhibition)
                                                Tooltip(
                                                  message: 'Team is an exhibition team and is not eligible for any awards!',
                                                  child: Icon(
                                                    Symbols.cruelty_free, // bunny
                                                  ),
                                                ),
                                              if (award.needsPortfolio && !team.hasPortfolio)
                                                Tooltip(
                                                  message: 'Team is missing a portfolio!',
                                                  child: Icon(
                                                    Symbols.content_paste_off, // clipboard crossed out
                                                  ),
                                                ),
                                            ]
                                          )
                                        else if (tied)
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
                                          kind != FinalistKind.automatic
                                              ? RemoveOverrideCell(
                                                  competition: widget.competition,
                                                  award: award,
                                                  team: team!,
                                                  rank: rank,
                                                  kind: kind,
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
            if (!widget.competition.applyFinalistsByAwardRanking && haveAssignableWinners)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Assign winners for place $assignPlace:', style: bold),
              ),
            if (!widget.competition.applyFinalistsByAwardRanking && haveAssignableWinners)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: TeamOrderSelector(
                  value: widget.competition.finalistsSortOrder,
                  onChange: (TeamComparatorCallback newValue) {
                    widget.competition.finalistsSortOrder = newValue;
                  },
                ),
              ),
            if (!widget.competition.applyFinalistsByAwardRanking && incompleteAwards.isNotEmpty && !haveAssignableWinners)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text('Use the Ranks pane to assign ranks for teams in award shortlists.', style: italic),
              ),
            if (!widget.competition.applyFinalistsByAwardRanking && haveAssignableWinners)
              HorizontalScrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, 0.0),
                    child: Table(
                      border: const TableBorder.symmetric(
                        inside: BorderSide(),
                      ),
                      defaultColumnWidth: const IntrinsicCellWidth(),
                      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        TableRow(
                          children: [
                            Cell(
                              Text('#', style: bold),
                              prototype: Text('${widget.competition.teamsView.last.number} WW'), // longest team number plus icon(s)
                              highlight: widget.competition.finalistsSortOrder == Team.teamNumberComparator,
                            ),
                            // ignore: unused_local_variable
                            for (final (Award award, List<AwardFinalistEntry> awardFinalists) in finalists)
                              ListenableBuilder(
                                listenable: award,
                                builder: (BuildContext context, Widget? child) {
                                  final Color foregroundColor = textColorForColor(award.color);
                                  return ColoredBox(
                                    color: award.color,
                                    child: Cell(
                                      alignment: Alignment.center,
                                      Text(
                                        award.name,
                                        style: bold.copyWith(
                                          color: textColorForColor(award.color),
                                        ),
                                      ),
                                      icons: award.comment == '' ? null : <Widget>[
                                        Padding(
                                          padding: const EdgeInsetsDirectional.only(start: spacing),
                                          child: Tooltip(
                                            message: award.comment,
                                            child: Icon(
                                              Symbols.emoji_objects,
                                              size: DefaultTextStyle.of(context).style.fontSize,
                                              color: foregroundColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                      prototype: const Text('0000 XX'),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        for (Team team in awardCandidates[assignPlace]!.keys.toList()..sort(widget.competition.finalistsSortOrder))
                          buildTeamAwardAssignmentRow(
                            context,
                            competition: widget.competition,
                            place: assignPlace!,
                            team: team,
                            awardCandidates: awardCandidates,
                            finalists: finalistsAsMap,
                            winningTeams: wealthWinners,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!widget.competition.applyFinalistsByAwardRanking && haveAssignableWinners)
              // if all assignable winners are only eligible for one award at this place, autoassign all such winners
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, 0.0),
                child: AutoAssignButton(
                  competition: widget.competition,
                  place: assignPlace!,
                  awardCandidates: awardCandidates,
                ),
              ),
            AwardOrderSwitch(
              competition: widget.competition,
            ),
          ],
        );
      },
    );
  }

  static TableRow buildTeamAwardAssignmentRow(BuildContext context, {
    required Competition competition,
    required int place,
    required Team team,
    required Map<int, Map<Team, Set<Award>>> awardCandidates,
    required Map<Award, List<Team?>> finalists,
    required Map<Team, Set<Award>> winningTeams,
  }) {
    final Set<Award> awards = awardCandidates[place]![team]!;
    final Map<Award, String> tooltips = {};
    for (Award award in awards) {
      for (int index = place; index < finalists[award]!.length; index += 1) {
        if (finalists[award]![index] != null && finalists[award]![index]!.shortlistsView[award]!.rank! < team.shortlistsView[award]!.rank!) {
          final Team other = finalists[award]![index]!;
          tooltips[award] = 'Team #${other.number} ${team.name} was shortlisted for rank #${other.shortlistsView[award]!.rank} and has been assigned position #${index + 1}; assigning ${team.number} ${team.name} ahead of them would inverse the shortlisted positions.';
          break;
        }
      }
    }
    final Map<Award, Widget> labels = {};
    for (final Award award in competition.awardsView) {
      if (team.shortlistsView[award] != null) {
        if (team.shortlistsView[award]!.rank == null) {
          labels[award] = Text(bullet);
          assert(!tooltips.containsKey(award));
          tooltips[award] = 'Team was nominated but not ranked for this award.';
        } else {
          labels[award] = Text('#${team.shortlistsView[award]!.rank}${tooltips[award] != null ? " ⚠" : ""}');
          if (!awards.contains(award) && !tooltips.containsKey(award)) {
            // button is disabled but we haven't yet figured out why
            if (finalists[award]!.length >= place && finalists[award]![place - 1] != null) {
              Team team = finalists[award]![place - 1]!;
              tooltips[award] = 'Winner for place #$place is already assigned (#${team.number} ${team.name}).';
            } else if (winningTeams.containsKey(team) && award.spreadTheWealth != SpreadTheWealth.no) {
              final String which = (winningTeams[team]!.toList()..sort(competition.awardSorter)).map((Award award) => award.name).join(", ");
              tooltips[award] = 'Team was ranked for this award but has already been assigned another Spread-The-Wealth award ($which).';
            } else if (finalists[award]!.where((Team? element) => element != null).length >= award.count) {
              final String who = finalists[award]!.where((Team? element) => element != null).map((Team? team) => '#${team!.number} ${team.name}').join(", ");
              tooltips[award] = 'Team was ranked for this award but all available places have already been assigned ($who).';
            } else {
              List<Team> actualCandidates = awardCandidates[place]!.keys.where((Team other) => awardCandidates[place]![other]!.contains(award)).toList();
              if (actualCandidates.isNotEmpty) {
                actualCandidates.sort(Team.teamNumberComparator);
                final String who = actualCandidates.map((Team team) => '#${team.number} ${team.name}').join(", ");
                tooltips[award] = 'There are better-ranked teams for this award ($who).';
              }
            }
          }
        }
      }
    }
    return TableRow(
      children: [
        Cell(Text('${team.number}')),
        for (final Award award in competition.awardsView.toList()..sort(competition.awardSorter))
          Cell(
            team.shortlistsView[award] == null
              ? SizedBox.shrink()
              : Tooltip(
                  message: tooltips[award] ?? '',
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: award.color,
                      foregroundColor: textColorForColor(award.color),
                      side: award.color.computeLuminance() > 0.9 ? const BorderSide(color: Colors.black, width: 0.0) : null,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: awards.contains(award) ? () {
                      competition.addOverride(
                        award,
                        team,
                        place,
                        FinalistKind.manual,
                      );
                    } : null,
                    child: (!award.needsPortfolio || team.hasPortfolio) && (team.inspireStatus != InspireStatus.exhibition)
                        ? labels[award]!
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              labels[award]!,
                              const SizedBox(width: spacing),
                              if (team.inspireStatus == InspireStatus.exhibition)
                                Tooltip(
                                  message: 'Team is an exhibition team and is not eligible for any awards!',
                                  child: Icon(
                                    Symbols.cruelty_free, // bunny
                                    size: DefaultTextStyle.of(context).style.fontSize,
                                  ),
                                ),
                              if (award.needsPortfolio && !team.hasPortfolio)
                                Tooltip(
                                  message: 'Team is missing a portfolio!',
                                  child: Icon(
                                    Symbols.content_paste_off, // clipboard crossed out
                                    size: DefaultTextStyle.of(context).style.fontSize,
                                  ),
                                ),
                            ],
                        ),
                  ),
            ),
          ),
      ],
    );
  }
}

class ErrorCell extends StatelessWidget {
  const ErrorCell({
    super.key,
    required this.message,
    this.icons,
  });

  final String message;
  final List<Widget>? icons;

  @override
  Widget build(BuildContext context) {
    Widget body = Text(
      message,
      style: const TextStyle(
        color: Colors.white,
      ),
    );
    if (icons != null) {
      body = IconTheme(
        data: IconThemeData(
          size: DefaultTextStyle.of(context).style.fontSize,
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(child: body),
            const SizedBox(width: spacing),
            ...icons!,
          ],
        ),
      );
    }
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: ColoredBox(
        color: Colors.red,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: spacing),
          child: Align(
            alignment: Alignment.centerLeft,
            child: body,
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
      FinalistKind.override,
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
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double rankWidth = DefaultTextStyle.of(context).style.fontSize! * 6.0;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: constraints.maxWidth - spacing - rankWidth - spacing - kMinInteractiveDimension),
                              child: DropdownList<Team>(
                                focusNode: _teamFocusNode,
                                controller: _teamController,
                                onSelected: _handleTeamChange,
                                label: 'Team',
                                values: Map<Team, String>.fromIterable(widget.competition.teamsView, value: (dynamic team) => '${team.number} ${team.name}'),
                              ),
                            ),
                            const SizedBox(width: spacing),
                            SizedBox(
                              width: rankWidth,
                              child: TextField(
                                controller: _rankController,
                                focusNode: _rankFocusNode,
                                decoration: InputDecoration(
                                  labelText: 'Award',
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
                        );
                      },
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
    required this.kind,
    required this.foregroundColor,
  });

  final Competition competition;
  final Award award;
  final Team team;
  final int rank;
  final FinalistKind kind;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: IconButton(
        tooltip: switch (kind) {
          FinalistKind.automatic => throw StateError('Cannot remove automatic finalist'),
          FinalistKind.manual => 'Unassign team',
          FinalistKind.override => 'Remove override',
        },
        onPressed: () {
          competition.removeOverride(award, team, rank);
        },
        padding: EdgeInsets.zero,
        iconSize: DefaultTextStyle.of(context).style.fontSize,
        visualDensity: VisualDensity.compact,
        color: foregroundColor,
        icon: Icon(
          switch (kind) {
            FinalistKind.automatic => throw StateError('Cannot remove automatic finalist'),
            FinalistKind.manual => Symbols.playlist_remove,
            FinalistKind.override => Symbols.playlist_remove,
          },          
        ),
      ),
    );
  }
}

class AutoAssignButton extends StatelessWidget {
  const AutoAssignButton({super.key,
    required this.competition,
    required this.place,
    required this.awardCandidates,
  });

  final Competition competition;
  final int place;
  final Map<int, Map<Team, Set<Award>>> awardCandidates;

  @override
  Widget build(BuildContext context) {
    bool canAutoassign = true;
    for (final Team team in awardCandidates[place]!.keys) {
      if (team.inspireStatus == InspireStatus.exhibition ||
          awardCandidates[place]![team]!.length > 1) {
        canAutoassign = false;
        break;
      }
      assert(awardCandidates[place]![team]!.isNotEmpty);
      final Award award = awardCandidates[place]![team]!.single;
      if (award.needsPortfolio && !team.hasPortfolio) {
        canAutoassign = false;
        break;
      }
    }
    return FilledButton.icon(
      onPressed: canAutoassign ? () {
        for (final Team team in awardCandidates[place]!.keys) {
          assert(awardCandidates[place]![team]!.length == 1);
          final Award award = awardCandidates[place]![team]!.single;
          competition.addOverride(
            award,
            team,
            place,
            FinalistKind.manual,
          );
        }
      } : null,
      icon: const Icon(Symbols.wand_stars),
      label: Text('Assign each remaining winner to their only eligible award.'),
    );
  }
}