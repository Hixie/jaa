import 'package:elapsed_time_display/elapsed_time_display.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import 'io.dart';
import 'model/competition.dart';
import 'panes/1_setup.dart';
import 'panes/2_shortlists.dart';
import 'panes/3_pitvisits.dart';
import 'panes/4_ranks.dart';
import 'panes/5_inspire.dart';
import 'panes/6_finalists.dart';
import 'panes/7_script.dart';
import 'panes/8_export.dart';
import 'widgets/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MainApp(
    competition: Competition(
      autosaveDirectory: await getApplicationDocumentsDirectory(),
      exportDirectoryBuilder: () async => await (await getDownloadsDirectory())!.createTemp('jaa.'),
    ),
  ));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.competition});

  final Competition competition;

  @override
  State<MainApp> createState() => _MainAppState();
}

enum Pane {
  about,
  autosaveAvailable,
  setup,
  shortlists,
  pitVisits,
  ranks,
  inspire,
  awardFinalists,
  script,
  export,
}

class _MainAppState extends State<MainApp> {
  Pane _pane = Pane.setup;

  @override
  void initState() {
    super.initState();
    if (widget.competition.hasAutosave) {
      _pane = Pane.autosaveAvailable;
    }
  }

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
                            onPressed: () => _selectPane(Pane.about),
                            child: const Text(
                              'About',
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: spacing),
                        if (constraints.maxWidth >= minimumReasonableWidth)
                          ListenableBuilder(
                            listenable: widget.competition,
                            builder: (BuildContext context, Widget? child) {
                              if (widget.competition.autosaveScheduled) {
                                return Tooltip(
                                  message: 'Changes will be autosaved shortly.',
                                  child: Text(
                                    'Changed',
                                    style: TextStyle(color: DefaultTextStyle.of(context).style.color!.withOpacity(0.25)),
                                  ),
                                );
                              }
                              if (widget.competition.loading) {
                                return Text(
                                  'Loading...',
                                  style: TextStyle(color: DefaultTextStyle.of(context).style.color!.withOpacity(0.25)),
                                );
                              }
                              if (widget.competition.dirty) {
                                return Tooltip(
                                  message: widget.competition.lastAutosaveMessage,
                                  child: ContinuousAnimationBuilder(
                                    period: const Duration(seconds: 2),
                                    reverse: true,
                                    builder: (BuildContext context, double value, Widget? child) => Text(
                                      'Autosave failed.',
                                      style: TextStyle(
                                        color: Colors.red.withOpacity(0.25 + value * 0.75),
                                        fontVariations: [FontVariation.weight(1 + value * 999.0)],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (widget.competition.lastAutosave != null) {
                                return Tooltip(
                                  message: widget.competition.lastAutosaveMessage,
                                  child: Text(
                                    'Saved',
                                    style: TextStyle(color: DefaultTextStyle.of(context).style.color!.withOpacity(0.25)),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        if (constraints.maxWidth >= minimumReasonableWidth) const SizedBox(width: indent),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(0.0, spacing, indent, spacing),
                            child: Text(currentHelp, textAlign: TextAlign.right),
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
                                    '${widget.competition.eventName.isEmpty ? "" : "${widget.competition.eventName}. "}${widget.competition.teamsView.length} Teams.',
                                    style: bold,
                                  ),
                                if (widget.competition.awardsView.isNotEmpty)
                                  Text(
                                    '${widget.competition.advancingAwardsView.length} Advancing Awards; '
                                    '${widget.competition.nonAdvancingAwardsView.length} Non-Advancing Awards.',
                                    style: bold,
                                  ),
                                if (widget.competition.teamsView.isNotEmpty)
                                  if (widget.competition.inspireIneligibleTeamsView.isEmpty)
                                    const Text(
                                      'All teams are eligible for the Inspire award.',
                                      style: bold,
                                    )
                                  else
                                    Text(
                                      'Inspire-ineligible teams: ${formTeamList(widget.competition.inspireIneligibleTeamsView)}.',
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
                            value: Pane.pitVisits,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('3. Pit Visits'),
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
                            value: Pane.inspire,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('5. Inspire'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.awardFinalists,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('6. Award Finalists'),
                          ),
                          const SizedBox(width: spacing),
                          SelectableButton<Pane>(
                            value: Pane.script,
                            selection: _pane,
                            onChanged: _selectPane,
                            child: const Text('7. Script'),
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
                            Pane.about => AboutPane(competition: widget.competition),
                            Pane.autosaveAvailable => AutosaveAvailablePane(
                                competition: widget.competition,
                                onClosed: () {
                                  setState(() {
                                    _pane = Pane.setup;
                                  });
                                },
                              ),
                            Pane.setup => SetupPane(competition: widget.competition),
                            Pane.shortlists => ShortlistsPane(competition: widget.competition),
                            Pane.pitVisits => PitVisitsPane(competition: widget.competition),
                            Pane.ranks => RanksPane(competition: widget.competition),
                            Pane.inspire => InspirePane(competition: widget.competition),
                            Pane.awardFinalists => AwardFinalistsPane(competition: widget.competition),
                            Pane.script => ScriptPane(competition: widget.competition),
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

class AboutPane extends StatelessWidget {
  const AboutPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: 'About'),
        const Padding(
          padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
          child: Text(currentHelp),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
          child: ListenableBuilder(
            listenable: competition,
            builder: (BuildContext context, Widget? child) => ListBody(
              children: [
                Text(
                  competition.lastAutosaveMessage,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
                if (competition.lastAutosave != null && competition.dirty)
                  Wrap(
                    children: [
                      const Text('Time since last autosave: '),
                      ElapsedTimeDisplay(startTime: competition.lastAutosave!),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
          child: FilledButton(
            child: const Text(
              'Show Licenses',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () {
              showLicensePage(
                context: context,
                applicationName: 'FIRST Tech Challenge Judge Advisor Assistant',
                applicationVersion: 'Version 1.0.0',
                applicationLegalese: 'Created for Playing at Learning\n© copyright 2024 Ian Hickson',
              );
            },
          ),
        ),
      ],
    );
  }
}

class AutosaveAvailablePane extends StatefulWidget {
  const AutosaveAvailablePane({super.key, required this.competition, required this.onClosed});

  final Competition competition;
  final VoidCallback onClosed;

  @override
  State<AutosaveAvailablePane> createState() => _AutosaveAvailablePaneState();
}

class _AutosaveAvailablePaneState extends State<AutosaveAvailablePane> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'An autosave file is available.',
            textAlign: TextAlign.center,
            softWrap: true,
            overflow: TextOverflow.clip,
          ),
          const SizedBox(height: indent),
          FilledButton(
            onPressed: () async {
              final PlatformFile zipFile = widget.competition.autosaveFile;
              await showProgress(
                context, // ignore: use_build_context_synchronously
                message: 'Importing event state...',
                task: () => widget.competition.importEventState(zipFile),
              );
              widget.onClosed();
            },
            child: const Text(
              'Import event state from autosave file',
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ),
          const SizedBox(height: spacing),
          FilledButton(
            onPressed: widget.onClosed,
            child: const Text(
              'Abandon autosaved event state',
              textAlign: TextAlign.center,
              softWrap: true,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}
