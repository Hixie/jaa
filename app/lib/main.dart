import 'package:elapsed_time_display/elapsed_time_display.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'utils/constants.dart';
import 'utils/io.dart';
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

late final PackageInfo appInfo;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appInfo = await PackageInfo.fromPlatform();
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
  double _zoom = 1.0;
  Pane _pane = Pane.setup;

  @override
  void initState() {
    super.initState();
    ServicesBinding.instance.keyboard.addHandler(_handleKey);
    if (widget.competition.hasAutosave) {
      _pane = Pane.autosaveAvailable;
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.equal
        && (ServicesBinding.instance.keyboard.isMetaPressed || ServicesBinding.instance.keyboard.isControlPressed)) {
      setState(() {
        _zoom *= 1.2;
      });
      return true;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.minus
        && (ServicesBinding.instance.keyboard.isMetaPressed || ServicesBinding.instance.keyboard.isControlPressed)) {
      setState(() {
        _zoom /= 1.2;
      });
      return true;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.digit0
        && (ServicesBinding.instance.keyboard.isMetaPressed || ServicesBinding.instance.keyboard.isControlPressed)) {
      setState(() {
        _zoom = 1.0;
      });
      return true;
    }
    return false;
  }

  void _selectPane(Pane pane) {
    setState(() {
      _pane = pane;
    });
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_handleKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return FittedBox(
              child: SizedBox.fromSize(
                size: constraints.biggest / _zoom,
                child: MaterialApp(
                  theme: ThemeData.from(
                    colorScheme: ColorScheme.fromSeed(seedColor: seasonColors[widget.competition.ruleset]!),
                  ),
                  home: FilledButtonTheme(
                    data: const FilledButtonThemeData(
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(
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
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: textColor,
                          fontSize: 14.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Builder(
                              builder: (BuildContext context) {
                                return ColoredBox(
                                  color: Theme.of(context).colorScheme.secondaryContainer,
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
                                                    style: TextStyle(color: DefaultTextStyle.of(context).style.color!.withValues(alpha: 0.25)),
                                                  ),
                                                );
                                              }
                                              if (widget.competition.loading) {
                                                return Text(
                                                  'Loading...',
                                                  style: TextStyle(color: DefaultTextStyle.of(context).style.color!.withValues(alpha: 0.25)),
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
                                                        color: Colors.red.withValues(alpha: 0.25 + value * 0.75),
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
                                                    style: TextStyle(color: DefaultTextStyle.of(context).style.color!.withValues(alpha: 0.25)),
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
                                            child: Text(eventHelp, textAlign: TextAlign.right),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
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
                                  child: Text.rich(
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
                              builder: (BuildContext content, Widget? child) {
                                final List<Team> inspireIneligibleTeams = widget.competition.teamsView.where((Team team) => team.inspireStatus == InspireStatus.ineligible).toList();
                                return LayoutBuilder(
                                  builder: (BuildContext context, BoxConstraints constraints) {
                                    final int advancingAwardsCount = widget.competition.awardsWithKind(const <AwardKind>{AwardKind.inspire, AwardKind.advancingInspire, AwardKind.advancingIndependent});
                                    final int nonAdvancingAwardCount = widget.competition.awardsWithKind(const <AwardKind>{AwardKind.nonAdvancing});
                                    return Row(
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
                                                    '${widget.competition.eventName.isEmpty ? "" : "${widget.competition.eventName}. "}${count(widget.competition.teamsView.length, "Team")}.',
                                                    style: bold,
                                                  ),
                                                if (widget.competition.awardsView.isNotEmpty)
                                                  Text(
                                                    (advancingAwardsCount > 0 && nonAdvancingAwardCount > 0)
                                                      ? '${count(advancingAwardsCount, "Advancing Award")}; '
                                                        '${count(nonAdvancingAwardCount, "Non-Advancing Award")}.'
                                                      : (advancingAwardsCount > 0)
                                                      ? '${count(advancingAwardsCount, "Advancing Award")}.'
                                                      : '${count(nonAdvancingAwardCount, "Non-Advancing Award")}.',
                                                    style: bold,
                                                  ),
                                                if (widget.competition.teamsView.isNotEmpty)
                                                  if (inspireIneligibleTeams.isEmpty)
                                                    const Text(
                                                      'All teams are eligible for the Inspire award.',
                                                      style: bold,
                                                    )
                                                  else
                                                    Text(
                                                      'Inspire-ineligible teams: ${formTeamList(inspireIneligibleTeams)}.',
                                                      style: bold,
                                                    ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
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
                ),
              ),
            );
          }
        );
      }
    );
  }
}

class AboutPane extends StatelessWidget {
  const AboutPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Heading(title: 'About'),
          Padding(
            padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: Text('${appInfo.appName} $bullet Version ${appInfo.version}'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: Text(eventHelp),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: Text(appHelp),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(indent, indent, indent, spacing),
            child: Text(
              'Save state:',
              softWrap: true,
              overflow: TextOverflow.clip,
              style: bold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: spacing * 5.0),
              child: ListBody(
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
          const Padding(
            padding: EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: Text(
              'Ruleset:',
              softWrap: true,
              overflow: TextOverflow.clip,
              style: bold,
            ),
          ),
          RadioGroup(
            groupValue: competition.ruleset,
            onChanged: (Ruleset? value) {
              competition.ruleset = value!;
            },
            child: ListBody(
              children: [
                RadioRow<Ruleset>(
                  value: Ruleset.rules2024,
                  label: '2024-2025 season.\nAwards are ranked, finalists are automatically assigned, and Inspire winners are ineligible for any additional Inspire awards.',
                ),
                RadioRow<Ruleset>(
                  value: Ruleset.rules2025,
                  label: '2025-2026 season.\nFinalists are selected manually. Teams who won the Inspire award in previous competitions are still eligible for second place Inspire awards.',
                ),
              ],
            )
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, spacing * 4.0, indent, spacing),
            child: FilledButton(
              child: const Text(
                'Show Licenses',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: appInfo.appName,
                  applicationVersion: appInfo.version,
                  applicationLegalese: 'Created for Playing at Learning\n© copyright 2025 Ian Hickson',
                );
              },
            ),
          ),
        ],
      ),
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
