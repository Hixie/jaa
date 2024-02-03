import 'package:flutter/material.dart';

import '../constants.dart';
import '../model/competition.dart';
import '../widgets.dart';

class ShowTheLovePane extends StatelessWidget {
  const ShowTheLovePane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final List<Team> teams =
            competition.teamsView.where((Team team) => !team.shortlistsView.any((Award award) => award.pitVisits == PitVisit.yes)).toList();
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: competition.awardsView.isEmpty || competition.teamsView.isEmpty || teams.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(indent, indent, 0.0, 0.0),
                    child: Heading('3. Show The Love (STL)'),
                  ),
                  if (competition.teamsView.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(indent, indent, indent, 0.0),
                      child: Text('No teams loaded. Use the Setup pane to import a teams list.'),
                    ),
                  if (competition.awardsView.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(indent, indent, indent, 0.0),
                      child: Text('No awards loaded. Use the Setup pane to import an awards list.'),
                    ),
                  if (competition.teamsView.isNotEmpty && competition.awardsView.isNotEmpty && teams.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(indent, indent, indent, 0.0),
                      child: Text('All of the teams have been shortlisted for awards that involve pit visits.'),
                    ),
                ]
              : [
                  const SizedBox(height: indent),
                  ConstrainedBox(
                    // This stretches the Wrap across the Column as if the mainAxisAlignment was MainAxisAlignment.stretch.
                    constraints: const BoxConstraints(minWidth: double.infinity),
                    child: const Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(indent, 0.0, 0.0, 0.0),
                          child: Heading('3. Show The Love (STL)'),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(indent, 0.0, indent, spacing),
                          child: FilledButton(
                            onPressed: null, // TODO: exports the show the love table
                            child: Text(
                              'Export (HTML)',
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (competition.teamsView.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(indent, 0.0, 0.0, indent),
                      child: HorizontalScrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
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
                                  for (final Award award in competition.awardsView.where(Award.needsShowTheLove)) Cell(Text(award.name, style: bold)),
                                  const Cell(Text('Visited?', style: bold)),
                                ],
                              ),
                              for (final Team team in competition.teamsView)
                                TableRow(
                                  children: [
                                    Tooltip(
                                      message: team.name,
                                      child: Cell(
                                        Text('${team.number}'),
                                      ),
                                    ),
                                    for (final Award award in competition.awardsView.where(Award.needsShowTheLove))
                                      Cell(Text(team.shortlistsView.contains(award) ? 'Yes' : '')),
                                    VisitedCell(team),
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
    );
  }
}

class VisitedCell extends StatefulWidget {
  VisitedCell(this.team) : super(key: ObjectKey(team));

  final Team team;

  @override
  State<VisitedCell> createState() => _VisitedCellState();
}

class _VisitedCellState extends State<VisitedCell> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.team.addListener(_handleTeamUpdate);
    _controller.addListener(_handleTextFieldUpdate);
    _controller.text = widget.team.visitingJudgesNotes;
  }

  @override
  void didUpdateWidget(VisitedCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.team == oldWidget.team);
  }

  @override
  void dispose() {
    widget.team.removeListener(_handleTeamUpdate);
    super.dispose();
  }

  void _handleTeamUpdate() {
    setState(() {
      if (_controller.text != widget.team.visitingJudgesNotes) {
        _controller.text = widget.team.visitingJudgesNotes;
      }
    });
  }

  void _handleTextFieldUpdate() {
    widget.team.visitingJudgesNotes = _controller.text;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: widget.team.visited,
            onChanged: (bool? value) {
              widget.team.visited = value!;
            },
          ),
          SizedBox(
            width: 200.0,
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration.collapsed(
                hintText: 'no judging team assigned',
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                ),
              ),
              style: DefaultTextStyle.of(context).style,
            ),
          ),
        ],
      ),
    );
  }
}
