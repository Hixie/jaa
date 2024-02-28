import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../io.dart';
import '../model/competition.dart';
import '../widgets/cells.dart';
import '../widgets/widgets.dart';

class InspirePane extends StatelessWidget {
  const InspirePane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final Map<int, Map<Team, Set<String>>> candidates = competition.computeInspireCandidates();
        final List<String> categories = competition.categories;
        final List<int> categoryCounts = (candidates.keys.toList()..sort()).reversed.take(competition.minimumInspireCategories).toList();
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaneHeader(
              title: '5. Inspire',
              onHeaderButtonPressed: () => exportInspireHTML(context, competition),
            ),
            if (competition.teamsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: Text(
                  'No teams loaded. Use the Setup pane to import a teams list.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (competition.awardsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: Text(
                  'No awards loaded. Use the Setup pane to import an awards list.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (competition.inspireAward == null)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: Text(
                  'No Inspire award defined. Use the Setup pane to import an awards list with an Inspire award.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: Text(
                  'No teams shortlisted for sufficient advancing award categories. Use the Shortlists pane to nominate teams.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (categoryCounts.first < categories.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No teams are shortlisted for ${categories.length == 2 ? 'both' : 'all ${categories.length}'} categories.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (competition.inspireAward != null)
              for (final int categoryCount in categoryCounts)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0.0, spacing, 0.0, indent),
                  child: HorizontalScrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(indent, 0.0, 0.0, indent),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Candidates in $categoryCount categories'
                              '${categoryCount < competition.minimumInspireCategories ? " (insufficient to qualify for ${competition.inspireAward!.name} award)" : ""}:',
                            ),
                            const SizedBox(height: spacing),
                            Table(
                              border: TableBorder.symmetric(
                                inside: const BorderSide(),
                              ),
                              defaultColumnWidth: const IntrinsicCellWidth(),
                              defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                TableRow(
                                  children: [
                                    const Cell(Text('#', style: bold), prototype: Text('000000')),
                                    for (final String category in categories)
                                      Cell(
                                        Text(category, style: bold),
                                        prototype: const Text('unranked'),
                                      ),
                                    const Cell(Text('Rank Score', style: bold), prototype: Text('000')),
                                    if (categoryCount >= competition.minimumInspireCategories)
                                      const Cell(Text('Inspire Placement ✎_', style: bold), prototype: Text('Not eligible')),
                                  ],
                                ),
                                for (final Team team in candidates[categoryCount]!.keys.toList()..sort(Team.inspireCandidateComparator))
                                  TableRow(
                                    children: [
                                      Tooltip(
                                        message: team.name,
                                        child: Cell(Text('${team.number}')),
                                      ),
                                      for (final String category in categories) Cell(Text(team.bestRankFor(category, 'unranked', ''))),
                                      Cell(Text('${team.rankScore ?? ""}')),
                                      if (categoryCount >= competition.minimumInspireCategories)
                                        if (!team.inspireEligible)
                                          const Cell(Text('Not eligible'))
                                        else
                                          InspirePlacementCell(
                                            competition: competition,
                                            team: team,
                                            award: competition.inspireAward!,
                                          ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  static Future<void> exportInspireHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    StringBuffer page = createHtmlPage('Inspire', now);
    final Map<int, Map<Team, Set<String>>> candidates = competition.computeInspireCandidates();
    final List<String> categories = competition.categories;

    if (categories.isEmpty) {
      page.writeln('<p>No team qualify for the Inspire award.');
    } else {
      for (final int categoryCount in (candidates.keys.toList()..sort()).reversed) {
        page.writeln('<h2>Candidates in $categoryCount categories</h2>');
        page.writeln('<table>');
        page.writeln('<thead>');
        page.writeln('<tr>');
        page.writeln('<th>Team');
        for (final String category in categories) {
          page.writeln('<th>${escapeHtml(category)}');
        }
        page.writeln('<th>Rank Score');
        page.writeln('<th>Inspire Placement');
        page.writeln('<tbody>');
        for (final Team team in candidates[categoryCount]!.keys.toList()..sort(Team.inspireCandidateComparator)) {
          page.writeln('<tr>');
          page.writeln('<td>${team.number} <i>${escapeHtml(team.name)}</i>');
          for (final String category in categories) {
            page.writeln('<td>${escapeHtml(team.bestRankFor(category, 'unranked', ''))}');
          }
          page.writeln('<td>${team.rankScore ?? ""}');
          if (team.inspireEligible) {
            page.writeln('<td>${team.shortlistsView[competition.inspireAward!]?.rank ?? "<i>Not placed</i>"}');
          } else {
            page.writeln('<td><i>Not eligible</i>');
          }
        }
        page.writeln('</table>');
      }
    }
    return exportHTML(competition, 'inspire', now, page.toString());
  }
}

@immutable
class _InspirePlacementIdentity {
  const _InspirePlacementIdentity(
    this.competition,
    this.team,
    this.award,
  );

  final Competition competition;
  final Team team;
  final Award award;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _InspirePlacementIdentity && other.competition == competition && other.team == team && other.award == award;
  }

  @override
  int get hashCode => Object.hash(competition, team, award);
}

class InspirePlacementCell extends StatefulWidget {
  InspirePlacementCell({
    required this.competition,
    required this.team,
    required this.award,
  }) : super(key: ValueKey(_InspirePlacementIdentity(competition, team, award)));

  final Competition competition;
  final Team team;
  final Award award;

  @override
  State<InspirePlacementCell> createState() => _InspirePlacementCellState();
}

class _InspirePlacementCellState extends State<InspirePlacementCell> {
  final TextEditingController _controller = TextEditingController();
  ShortlistEntry? _entry;
  bool _error = false;

  String _placementAsString() {
    if (_entry == null) {
      return '';
    }
    if (_entry!.rank == null) {
      return '';
    }
    return '${_entry!.rank!}';
  }

  @override
  void initState() {
    super.initState();
    widget.competition.addListener(_updateError);
    widget.team.addListener(_handleTeamUpdate);
    _handleTeamUpdate();
    _controller.addListener(_handleTextFieldUpdate);
    _controller.text = _placementAsString();
    _updateError();
  }

  @override
  void didUpdateWidget(InspirePlacementCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.competition == oldWidget.competition);
    assert(widget.team == oldWidget.team);
    assert(widget.award == oldWidget.award);
    _updateError();
  }

  @override
  void dispose() {
    _entry?.removeListener(_handleEntryUpdate);
    widget.team.removeListener(_handleTeamUpdate);
    widget.competition.removeListener(_updateError);
    _controller.dispose();
    super.dispose();
  }

  void _updateError() {
    setState(() {
      _error = _entry == null || _entry!.rank == null || _entry!.rank! <= 0 || _entry!.rank! > widget.competition.teamsView.length;
    });
  }

  void _handleTeamUpdate() {
    setState(() {
      if (_entry == null) {
        _entry = widget.team.shortlistsView[widget.award];
        _entry?.addListener(_handleEntryUpdate);
      } else {
        if (!widget.team.shortlistsView.containsKey(widget.award)) {
          _entry!.removeListener(_handleTeamUpdate);
          _entry = null;
        }
      }
      _handleEntryUpdate();
    });
  }

  void _handleTextFieldUpdate() {
    if (_controller.text == '') {
      if (_entry != null) {
        widget.competition.removeFromShortlist(widget.award, widget.team);
      }
    } else {
      if (_entry == null) {
        widget.competition.addToShortlist(widget.award, widget.team, ShortlistEntry(lateEntry: false, rank: int.parse(_controller.text)));
        assert(_entry != null); // set by _handleTeamUpdate
      } else {
        _entry!.rank = int.parse(_controller.text);
      }
    }
  }

  void _handleEntryUpdate() {
    final String newValue = _placementAsString();
    if (_controller.text != newValue) {
      _controller.text = newValue;
    }
    _updateError();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = DefaultTextStyle.of(context).style;
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: spacing),
        child: SizedBox(
          width: DefaultTextStyle.of(context).style.fontSize! * 4.0,
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration.collapsed(
              hintText: 'Not placed',
              hintStyle: TextStyle(
                fontStyle: FontStyle.italic,
              ),
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
    );
  }
}
