import 'package:flutter/material.dart';

import '../constants.dart';
import '../io.dart';
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
        final List<Team> teams = computeAffectedTeams(competition);
        final List<Award> showTheLoveAwards = computeAffectedAwards(competition);
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaneHeader(
              title: '3. Show The Love (STL)',
              onHeaderButtonPressed: () => exportShowTheLoveHTML(context, competition),
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
            if (competition.teamsView.isNotEmpty && competition.awardsView.isNotEmpty && teams.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text('All of the teams have been shortlisted for awards that involve pit visits.'),
              ),
            if (teams.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text('The following teams have not been shortlisted for any awards that always involve pit visits:'),
              ),
            if (teams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, 0.0, indent),
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
                            for (final Award award in showTheLoveAwards)
                              ColoredBox(
                                color: award.color,
                                child: Cell(
                                  Text(
                                    award.name,
                                    style: bold.copyWith(
                                      color: textColorForColor(award.color),
                                    ),
                                  ),
                                ),
                              ),
                            const Cell(Text('Visited? ✎_', style: bold)),
                          ],
                        ),
                        for (final Team team in teams)
                          TableRow(
                            children: [
                              Tooltip(
                                message: team.name,
                                child: Cell(
                                  Text('${team.number}'),
                                ),
                              ),
                              for (final Award award in showTheLoveAwards) Cell(Text(team.shortlistsView.keys.contains(award) ? 'Yes' : '')),
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

  static List<Team> computeAffectedTeams(Competition competition) {
    return competition.teamsView
        .where((Team team) => !team.shortlistsView.keys.any(
              (Award award) => award.pitVisits == PitVisit.yes,
            ))
        .toList();
  }

  static List<Award> computeAffectedAwards(Competition competition) {
    return competition.awardsView.where(Award.needsShowTheLovePredicate).toList();
  }

  static Future<void> exportShowTheLoveHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    final List<Award> showTheLoveAwards = computeAffectedAwards(competition);
    final StringBuffer page = createHtmlPage('Show The Love', now);
    page.writeln('<table>');
    page.writeln('<thead>');
    page.writeln('<tr>');
    page.writeln('<th>Team');
    for (final Award award in showTheLoveAwards) {
      page.writeln('<th>${escapeHtml(award.name)}');
    }
    page.writeln('<th>Notes');
    page.writeln('<tbody>');
    for (final Team team in computeAffectedTeams(competition)) {
      page.writeln('<tr>');
      page.writeln('<td>${team.number} <i>${escapeHtml(team.name)}</i>');

      for (final Award award in showTheLoveAwards) {
        page.writeln('<td>${team.shortlistsView.keys.contains(award) ? "Yes" : ""}');
      }
      page.writeln('<td>${team.visited ? "Visited." : ""} ${escapeHtml(team.visitingJudgesNotes)}');
    }
    page.writeln('</table>');
    return exportHTML(competition, 'show_the_love', now, page.toString());
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
            width: DefaultTextStyle.of(context).style.fontSize! * 15.0,
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
