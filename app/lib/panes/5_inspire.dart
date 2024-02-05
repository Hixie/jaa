import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../model/competition.dart';
import '../widgets.dart';

class InspirePane extends StatelessWidget {
  const InspirePane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: competition,
        builder: (BuildContext context, Widget? child) {
          final Map<int, Map<Team, Set<String>>> candidates = <int, Map<Team, Set<String>>>{};
          for (final Team team in competition.teamsView) {
            final Set<String> categories = team.shortlistedAdvancingCategories;
            if (categories.length > 1) {
              final Map<Team, Set<String>> group = candidates.putIfAbsent(categories.length, () => <Team, Set<String>>{});
              group[team] = categories;
            }
          }
          final List<String> categories = competition.awardsView.where(Award.isRankedPredicate).map((Award award) => award.category).toSet().toList()..sort();
          final Award inspireAward = competition.awardsView.firstWhere((Award award) => award.isInspire);
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const PaneHeader(
                title: '5. Inspire',
                onHeaderButtonPressed: null, // TODO: exports the candidates table
              ),
              if (competition.teamsView.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                  child: Text('No teams loaded. Use the Setup pane to import a teams list.'),
                ),
              if (competition.awardsView.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                  child: Text('No awards loaded. Use the Setup pane to import an awards list.'),
                ),
              if (competition.teamsView.isNotEmpty && competition.awardsView.isNotEmpty && candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                  child: Text('No teams shortlisted for multiple advancing award categories. Use the Shortlists pane to nominate teams.'),
                ),
              if (candidates.isNotEmpty)
                for (final int categoryCount in (candidates.keys.toList()..sort()).reversed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(indent, spacing, 0.0, indent),
                    child: HorizontalScrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Candidates in $categoryCount categories:'),
                            const SizedBox(height: spacing),
                            Table(
                              border: TableBorder.symmetric(
                                inside: const BorderSide(),
                              ),
                              defaultColumnWidth: const IntrinsicColumnWidth(),
                              defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                TableRow(
                                  children: [
                                    const Cell(Text('#', style: bold)),
                                    for (final String category in categories)
                                      Cell(
                                        Text(category, style: bold),
                                      ),
                                    const Cell(Text('Rank Score', style: bold)),
                                    const Cell(Text('Inspire Placement ✎_', style: bold)),
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
                                      if (team.inspireEligible)
                                        InspirePlacementCell(
                                          competition: competition,
                                          team: team,
                                          award: inspireAward,
                                        )
                                      else
                                        const Cell(Text('Not eligible')),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
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
    _controller.dispose();
    super.dispose();
  }

  void _updateError() {
    _error = _entry == null || _entry!.rank == null;
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
    return Padding(
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
    );
  }
}
