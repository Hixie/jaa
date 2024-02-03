import 'package:flutter/material.dart';
import 'package:jaa/panes/shortlists.dart';
import 'package:jaa/panes/showthelove.dart';
import 'constants.dart';
import 'panes/setup.dart';
import 'model/competition.dart';
import 'widgets.dart';

void main() {
  runApp(MainApp(competition: Competition()));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.competition});

  final Competition competition;

  @override
  State<MainApp> createState() => _MainAppState();
}

enum Pane {
  configure,
  setup,
  shortlists,
  showTheLove,
  ranks,
  inspireCandidate,
  inspireWinners,
  awardFinalists,
  export,
}

class _MainAppState extends State<MainApp> {
  Pane _pane = Pane.setup;

  void _selectPane(Pane pane) {
    setState(() {
      _pane = pane;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
      ),
      home: FilledButtonTheme(
        data: const FilledButtonThemeData(
          style: ButtonStyle(
            shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(spacing / 2.0)),
              ),
            ),
          ),
        ),
        child: ColoredBox(
          color: background,
          child: DefaultTextStyle(
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: primaryText,
              fontSize: 14.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: accent,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        const SizedBox(width: indent),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth - indent * 2.0),
                          child: FilledButton(
                            onPressed: () => _selectPane(Pane.configure),
                            child: const Text(
                              'Configure',
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: indent),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(0.0, spacing, indent, spacing),
                            child: Text(
                              'FTC Weekend Support # 1-800-555-1212', // TODO: replace this with something real
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: widget.competition,
                  child: Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        indent,
                        headingStyle.fontSize!,
                        indent,
                        headingStyle.fontSize!,
                      ),
                      child: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'FIRST',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                            TextSpan(
                              text: ' Tech Challenge Judge Advisor Assistant',
                            ),
                          ],
                          style: headingStyle,
                        ),
                      ),
                    ),
                  ),
                  builder: (BuildContext content, Widget? child) => LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) => Row(
                      children: [
                        child!,
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(indent, spacing, indent * 2.0, spacing),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.competition.teamsView.isNotEmpty)
                                  Text(
                                    '${widget.competition.teamsView.length} Teams.',
                                    style: bold,
                                  ),
                                if (widget.competition.awardsView.isNotEmpty)
                                  Text(
                                    '${widget.competition.advancingAwardsView.length} Advancing Awards; '
                                    '${widget.competition.nonAdvancingAwardsView.length} Non-Advancing Awards.',
                                    style: bold,
                                  ),
                                if (widget.competition.previousInspireWinnersView.isNotEmpty)
                                  Text(
                                    'Previous Inspire Winners: ${formTeamList(widget.competition.previousInspireWinnersView)}.',
                                    style: bold,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ColoredBox(
                  color: control,
                  child: HorizontalScrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableButton<Pane>(
                            value: Pane.setup,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('1. Setup'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.shortlists,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('2. Shortlists'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.showTheLove,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('3. Show The Love'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.ranks,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('4. Ranks'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.inspireCandidate,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('5. Inspire Candidate'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.inspireWinners,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('6. Inspire Winners'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.awardFinalists,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('7. Award Finalists'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.export,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('8. Export'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: animationDuration,
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
                        key: ValueKey<Pane>(_pane),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight, minWidth: constraints.maxWidth, maxWidth: constraints.maxWidth),
                          child: switch (_pane) {
                            Pane.configure => ConfigurePane(competition: widget.competition),
                            Pane.setup => SetupPane(competition: widget.competition),
                            Pane.shortlists => ShortlistsPane(competition: widget.competition),
                            Pane.showTheLove => ShowTheLovePane(competition: widget.competition),
                            Pane.ranks => RanksPane(competition: widget.competition),
                            Pane.inspireCandidate => InspireCandidatePane(competition: widget.competition),
                            Pane.inspireWinners => InspireWinnersPane(competition: widget.competition),
                            Pane.awardFinalists => AwardFinalistsPane(competition: widget.competition),
                            Pane.export => ExportPane(competition: widget.competition),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConfigurePane extends StatelessWidget {
  const ConfigurePane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return const ListBody(
      children: [
        Heading('Configuration'),
        Text('There is nothing to configure currently.'),
      ],
    );
  }
}

class RanksPane extends StatelessWidget {
  const RanksPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class InspireCandidatePane extends StatelessWidget {
  const InspireCandidatePane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class InspireWinnersPane extends StatelessWidget {
  const InspireWinnersPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class AwardFinalistsPane extends StatelessWidget {
  const AwardFinalistsPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ExportPane extends StatelessWidget {
  const ExportPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
