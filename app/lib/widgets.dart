import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'constants.dart';
import 'model/competition.dart';

Color textColorForColor(Color color) => color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

String placementDescriptor(int rank) {
  if (rank > 3 && rank <= 20) {
    return '${rank}th';
  }
  if (rank % 10 == 1) {
    return '${rank}st';
  }
  if (rank % 10 == 2) {
    return '${rank}nd';
  }
  if (rank % 10 == 3) {
    return '${rank}rd';
  }
  return '${rank}th';
}

class SelectableButton<T> extends StatefulWidget {
  const SelectableButton({
    super.key,
    required this.value,
    required this.selection,
    required this.onChanged,
    required this.child,
  });

  final T value;
  final T selection;
  final ValueSetter<T>? onChanged;
  final Widget child;

  bool get selected => value == selection;

  @override
  State<SelectableButton<T>> createState() => _SelectableButtonState<T>();
}

class _SelectableButtonState<T> extends State<SelectableButton<T>> {
  late final MaterialStatesController statesController;

  @override
  void initState() {
    super.initState();
    statesController = MaterialStatesController(
      <MaterialState>{
        if (widget.selected) MaterialState.selected,
      },
    );
  }

  @override
  void didUpdateWidget(SelectableButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      statesController.update(MaterialState.selected, widget.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    late final TextButton result;
    result = TextButton(
      statesController: statesController,
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return Theme.of(context).colorScheme.onPrimary;
            }
            return null; // defer to the defaults
          },
        ),
        backgroundColor: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return Theme.of(context).colorScheme.primary;
            }
            return null; // defer to the defaults
          },
        ),
      ),
      onPressed: widget.onChanged != null
          ? () {
              widget.onChanged!(widget.value);
            }
          : null,
      child: Builder(
        builder: (BuildContext context) {
          final TextStyle style = DefaultTextStyle.of(context).style;
          return DefaultTextStyle(
            style: style.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: style.color,
            ),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            child: widget.child,
          );
        },
      ),
    );
    return result;
  }
}

class PaneHeader extends StatelessWidget {
  const PaneHeader({
    super.key,
    required this.title,
    this.headerButtonLabel = 'Export (HTML)',
    required this.onHeaderButtonPressed,
  });

  final String title;
  final String headerButtonLabel;
  final VoidCallback? onHeaderButtonPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: indent),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: double.infinity), // makes Wrap as wide as container
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            Heading(
              title,
              padding: const EdgeInsets.fromLTRB(indent, 0.0, 0.0, 0.0),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, spacing),
              child: FilledButton(
                onPressed: onHeaderButtonPressed,
                child: Text(
                  headerButtonLabel,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Heading extends StatelessWidget {
  const Heading(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(indent, indent, indent, spacing),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 24.0,
        ),
      ),
    );
  }
}

class Cell extends StatelessWidget {
  const Cell(
    this.child, {
    super.key,
    this.prototype,
  });

  final Widget child;
  final Widget? prototype;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    if (prototype != null) {
      result = Stack(
        children: [
          Opacity(
            opacity: 0.0,
            child: prototype!,
          ),
          result
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(spacing),
      child: result,
    );
  }
}

class ConditionalText extends StatelessWidget {
  const ConditionalText(
    this.message, {
    super.key,
    required this.active,
  });

  final String message;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1.0 : 0.0,
      duration: animationDuration,
      curve: Curves.easeInOut,
      child: Text(message),
    );
  }
}

class _ForcedScrollbarScrollBehavior extends MaterialScrollBehavior {
  const _ForcedScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          child: child,
        );
      default:
        return super.buildScrollbar(context, child, details);
    }
  }
}

class HorizontalScrollbar extends StatelessWidget {
  const HorizontalScrollbar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _ForcedScrollbarScrollBehavior(),
      child: child,
    );
  }
}

class ShortlistCard extends StatelessWidget {
  const ShortlistCard({
    super.key,
    required this.award,
    required this.child,
  });

  final Award award;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AwardCard(
      award: award,
      child: child ??
          const Padding(
            padding: EdgeInsets.all(spacing),
            child: Text('No teams shortlisted.'),
          ),
    );
  }
}

class AwardCard extends StatelessWidget {
  const AwardCard({
    super.key,
    required this.award,
    this.showAwardRanks = false,
    required this.child,
  });

  final Award award;
  final bool showAwardRanks;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: award,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final Color foregroundColor = textColorForColor(award.color);
        return Card(
          elevation: teamListElevation,
          color: award.color,
          shape: teamListCardShape,
          child: FocusTraversalGroup(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foregroundColor),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(spacing),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (award.isSpreadTheWealth) TextSpan(text: '#${award.rank}: '),
                            TextSpan(text: award.name, style: bold),
                            if (award.category.isNotEmpty)
                              TextSpan(
                                text: ' (${award.category})',
                              ),
                          ],
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

typedef AwardWidgetBuilder = Widget Function(BuildContext context, Award award, Shortlist shortlist);

class AwardBuilder extends StatelessWidget {
  const AwardBuilder({
    super.key,
    required this.sortedAwards,
    required this.competition,
    required this.builder,
  });

  final List<Award> sortedAwards;
  final Competition competition;
  final AwardWidgetBuilder builder;

  List<Widget> _buildChildren() {
    final List<Widget> children = [];
    String? lastCategory = sortedAwards.last.category;
    for (final Award award in sortedAwards.reversed) {
      final bool needPadding = award.category != lastCategory;
      lastCategory = award.category;
      children.insert(
        0,
        Padding(
          padding: EdgeInsetsDirectional.only(end: needPadding ? indent : 0.0),
          child: ListenableBuilder(
            listenable: competition.shortlistsView[award]!,
            builder: (BuildContext context, Widget? child) {
              return builder(context, award, competition.shortlistsView[award]!);
            },
          ),
        ),
      );
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, spacing, 0.0, spacing),
      child: sortedAwards.isEmpty
          ? const Text('No awards loaded. Use the Setup pane to import an awards list.')
          : ScrollableWrap(
              children: _buildChildren(),
            ),
    );
  }
}

class AwardOrderSwitch extends StatelessWidget {
  const AwardOrderSwitch({
    super.key,
    required this.competition,
  });

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(indent, spacing, indent, indent),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Sort awards by rank',
                textAlign: TextAlign.end,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(spacing, 0.0, spacing, 0.0),
              child: ListenableBuilder(
                listenable: competition,
                builder: (BuildContext context, Widget? child) => Switch(
                  value: competition.awardOrder == AwardOrder.categories,
                  thumbIcon: MaterialStateProperty.all(const Icon(Symbols.trophy)),
                  onChanged: (bool value) {
                    competition.awardOrder = value ? AwardOrder.categories : AwardOrder.rank;
                  },
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'Sort awards by category',
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScrollableWrap extends StatelessWidget {
  const ScrollableWrap({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      return HorizontalScrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minimumReasonableWidth,
              maxWidth: math.max(minimumReasonableWidth, constraints.maxWidth),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, 0.0),
              child: Wrap(
                runSpacing: spacing,
                spacing: 0.0,
                children: children,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class ShortlistEditor extends StatefulWidget {
  const ShortlistEditor({
    super.key,
    required this.sortedAwards,
    required this.competition,
    required this.lateEntry,
  });

  final List<Award> sortedAwards;
  final Competition competition;
  final bool lateEntry;

  @override
  State<ShortlistEditor> createState() => _ShortlistEditorState();
}

class _ShortlistEditorState extends State<ShortlistEditor> {
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _nominatorController = TextEditingController();
  final FocusNode _teamFocusNode = FocusNode();
  final FocusNode _nominatorFocusNode = FocusNode();

  Award? _award;
  Team? _team;

  @override
  void initState() {
    super.initState();
    _teamController.addListener(_handleTeamTextChange);
    widget.competition.addListener(_markNeedsBuild);
  }

  @override
  void didUpdateWidget(covariant ShortlistEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.competition != oldWidget.competition) {
      oldWidget.competition.removeListener(_markNeedsBuild);
      widget.competition.addListener(_markNeedsBuild);
    }
  }

  @override
  void dispose() {
    widget.competition.removeListener(_markNeedsBuild);
    _teamController.dispose();
    _nominatorController.dispose();
    _teamFocusNode.dispose();
    _nominatorFocusNode.dispose();
    super.dispose();
  }

  void _markNeedsBuild() {
    setState(() {
      // build is depenendent on the competition object
    });
  }

  void _handleAwardSelection(Award award) {
    if (_award == award) {
      if (_teamController.text.isEmpty && _nominatorController.text.isEmpty) {
        setState(() {
          _award = null;
        });
      } else {
        _teamFocusNode.requestFocus();
      }
    } else {
      setState(() {
        _award = award;
        if (widget.competition.shortlistsView[award]!.entriesView.containsKey(_team)) {
          _team = null;
          _teamController.clear();
        }
      });
      _teamFocusNode.requestFocus();
    }
  }

  void _handleTeamChange(Team? team) {
    _nominatorFocusNode.requestFocus();
    setState(() {
      _team = team;
    });
  }

  void _handleTeamTextChange() {
    // Workaround for https://github.com/flutter/flutter/issues/143505
    if (_teamController.text != (_team != null ? "${_team!.number} ${_team!.name}" : "")) {
      Team? team = widget.competition.teamsView.cast<Team?>().singleWhere(
            (Team? team) => "${team!.number} ${team.name}" == _teamController.text,
            orElse: () => null,
          );
      setState(() {
        _team = team;
      });
    }
  }

  void _addTeamToShortlist() {
    widget.competition.addToShortlist(
      _award!,
      _team!,
      ShortlistEntry(
        nominator: _nominatorController.text,
        lateEntry: widget.lateEntry,
      ),
    );
    _teamController.clear();
    _nominatorController.clear();
    _teamFocusNode.requestFocus();
    setState(() {
      _team = null;
    });
  }

  static final Key _cardKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return ListBody(
      children: [
        if (widget.sortedAwards.isNotEmpty && widget.competition.teamsView.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Nominate for:'),
                for (final Award award in widget.sortedAwards)
                  if (!award.isInspire)
                    ListenableBuilder(
                      listenable: award,
                      child: Text(
                        award.name,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                      builder: (BuildContext context, Widget? child) {
                        return FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: award.color,
                              foregroundColor: textColorForColor(award.color),
                              side: award.color.computeLuminance() > 0.9 ? const BorderSide(color: Colors.black, width: 0.0) : null,
                            ),
                            onPressed: () => _handleAwardSelection(award),
                            child: child);
                      },
                    ),
              ],
            ),
          ),
        if (_award != null)
          Padding(
            key: _cardKey,
            padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
            child: ListenableBuilder(
              listenable: _award!,
              child: Card(
                child: Stack(
                  children: [
                    ListenableBuilder(
                      listenable: widget.competition.shortlistsView[_award]!,
                      builder: (BuildContext context, Widget? child) {
                        Set<Team> shortlistedTeams = widget.competition.shortlistsView[_award]!.entriesView.keys.toSet();
                        List<Team> remainingTeams = widget.competition.teamsView.where((Team team) => !shortlistedTeams.contains(team)).toList();
                        String awardRank, awardDescription, awardCategory;
                        if (_award!.isSpreadTheWealth) {
                          awardRank = 'rank ${_award!.rank} ';
                        } else {
                          awardRank = '';
                        }
                        if (_award!.isAdvancing) {
                          awardDescription = 'advancing award';
                        } else {
                          awardDescription = 'non-advancing award';
                        }
                        if (_award!.category.isNotEmpty) {
                          awardCategory = ' in the ${_award!.category} category';
                        } else {
                          awardCategory = '';
                        }
                        if (remainingTeams.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(indent, indent - spacing, indent + spacing, indent - spacing),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'All the teams have already been shortlisted for the '),
                                  TextSpan(text: _award!.name, style: bold),
                                  TextSpan(text: ' ($awardRank$awardDescription$awardCategory) award!'),
                                ],
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(indent, indent - spacing, indent, indent),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(text: 'Nominate team for '),
                                    TextSpan(text: _award!.name, style: bold),
                                    TextSpan(text: ' ($awardRank$awardDescription$awardCategory)${widget.lateEntry ? " as a late entry" : ""}:'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: spacing),
                              LayoutBuilder(
                                builder: (BuildContext context, BoxConstraints constraints) => HorizontalScrollbar(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                        maxWidth: math.max(
                                          constraints.maxWidth,
                                          minimumReasonableWidth,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DropdownMenu<Team>(
                                            focusNode: _teamFocusNode,
                                            controller: _teamController,
                                            onSelected: _handleTeamChange,
                                            requestFocusOnTap: true,
                                            enableFilter: true,
                                            menuStyle: MenuStyle(
                                              maximumSize: MaterialStatePropertyAll(
                                                Size(constraints.maxWidth, indent * 11.0),
                                              ),
                                            ),
                                            label: const Text(
                                              'Team',
                                              softWrap: false,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            dropdownMenuEntries: remainingTeams.map<DropdownMenuEntry<Team>>((Team team) {
                                              return DropdownMenuEntry<Team>(
                                                value: team,
                                                label: '${team.number} ${team.name}',
                                              );
                                            }).toList(),
                                          ),
                                          const SizedBox(width: indent),
                                          Expanded(
                                            child: TextField(
                                              controller: _nominatorController,
                                              focusNode: _nominatorFocusNode,
                                              decoration: const InputDecoration(
                                                label: Text(
                                                  'Nominator',
                                                  softWrap: false,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                border: OutlineInputBorder(),
                                              ),
                                              onSubmitted: (String value) {
                                                if (_team != null) {
                                                  _addTeamToShortlist();
                                                } else {
                                                  _teamFocusNode.requestFocus();
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: indent),
                                          IconButton.filledTonal(
                                            onPressed: _team != null ? _addTeamToShortlist : null,
                                            icon: const Icon(
                                              Symbols.heart_plus,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _award = null;
                            _team = null;
                            _teamController.clear();
                            _nominatorController.clear();
                          });
                        },
                        iconSize: DefaultTextStyle.of(context).style.fontSize,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
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

class ShortlistSummary extends StatefulWidget {
  const ShortlistSummary({super.key, required this.competition});

  final Competition competition;

  @override
  State<ShortlistSummary> createState() => _ShortlistSummaryState();
}

class _ShortlistSummaryState extends State<ShortlistSummary> {
  @override
  void initState() {
    super.initState();
    widget.competition.addListener(_updateSummary);
    _updateSummary();
  }

  @override
  void didUpdateWidget(covariant ShortlistSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.competition != oldWidget.competition) {
      oldWidget.competition.removeListener(_updateSummary);
      widget.competition.addListener(_updateSummary);
    }
  }

  @override
  void dispose() {
    widget.competition.removeListener(_updateSummary);
    super.dispose();
  }

  late String _summary;
  void _updateSummary() {
    setState(() {
      _summary = _generateSummary();
    });
  }

  String _generateSummary() {
    if (widget.competition.inspireAward == null) {
      return '';
    }
    final Map<int, Map<Team, Set<String>>> candidates = widget.competition.computeInspireCandidates();
    final List<String> categories = widget.competition.categories;
    final int targetCategories = categories.length;
    if (targetCategories == 0) {
      return '';
    }
    final String requiredAwards;
    if (targetCategories == 1) {
      final List<Award> inspireAwards = widget.competition.awardsView.where(Award.isInspireQualifyingPredicate).toList();
      if (inspireAwards.length == 1) {
        requiredAwards = 'the ${inspireAwards.single.name} award';
      } else {
        requiredAwards = 'any of the ${categories.single} category awards';
      }
    } else if (targetCategories == 2) {
      requiredAwards = 'awards in both advancing award categories';
    } else {
      requiredAwards = 'awards in all $targetCategories advancing award categories';
    }
    if (!candidates.containsKey(targetCategories)) {
      return 'No teams are nominated for $requiredAwards, '
          'and thus no teams yet fully qualify for the ${widget.competition.inspireAward!.name} award.';
    }
    final int nomineeTarget = widget.competition.inspireAward!.count;
    final int totalNomineeCount = candidates[targetCategories]!.length;
    final int qualifyingNomineeCount = candidates[targetCategories]!.keys.where((Team team) => team.inspireEligible).length;
    final int ineligibleCount = totalNomineeCount - qualifyingNomineeCount;
    final String nonqualifying = switch (ineligibleCount) {
      0 => '',
      1 => ' (one nominated team is ineligible)',
      _ => ' ($ineligibleCount nominated teams are ineligible)',
    };
    // If we get here we know at least one team is nominated for all the relevant categories.
    assert(totalNomineeCount > 0);
    if (qualifyingNomineeCount < nomineeTarget) {
      if (qualifyingNomineeCount == 0) {
        assert(ineligibleCount > 0);
        return 'No eligible team is nominated for $requiredAwards '
            'so no team qualifies for the ${widget.competition.inspireAward!.name} award'
            '$nonqualifying.';
      }
      assert(widget.competition.inspireAward!.count > 1);
      if (widget.competition.inspireAward!.count == 2) {
        return 'Insufficient teams are nominated for $requiredAwards '
            'to have winners for both places of the ${widget.competition.inspireAward!.name} award'
            '$nonqualifying.';
      }
      return 'Insufficient teams are nominated for $requiredAwards '
          'to have winners for all $nomineeTarget places of the ${widget.competition.inspireAward!.name} award'
          '$nonqualifying.';
    }
    if (qualifyingNomineeCount == 1) {
      return 'A team has qualified for the ${widget.competition.inspireAward!.name} award.';
    }
    return '$qualifyingNomineeCount teams qualify for the ${widget.competition.inspireAward!.name} award.';
  }

  @override
  Widget build(BuildContext context) {
    if (_summary.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
      child: Text(
        _summary,
        softWrap: true,
        overflow: TextOverflow.clip,
      ),
    );
  }
}

class VisitedCell extends StatefulWidget {
  VisitedCell({required this.team, this.label}) : super(key: ObjectKey(team));

  final Team team;
  final Widget? label;

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) widget.label!,
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
    );
  }
}

class ContinuousAnimationBuilder extends StatefulWidget {
  const ContinuousAnimationBuilder({
    super.key,
    required this.builder,
    this.min = 0.0,
    this.max = 1.0,
    this.reverse = false,
    required this.period,
    this.child,
  });

  final ValueWidgetBuilder<double> builder;
  final double min;
  final double max;
  final bool reverse;
  final Duration period;
  final Widget? child;

  @override
  State<ContinuousAnimationBuilder> createState() => _ContinuousAnimationBuilderState();
}

class _ContinuousAnimationBuilderState extends State<ContinuousAnimationBuilder> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant ContinuousAnimationBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.min != widget.min || oldWidget.max != widget.max || oldWidget.reverse != widget.reverse || oldWidget.period != widget.period) {
      _restart();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    _controller.repeat(min: widget.min, max: widget.max, reverse: widget.reverse, period: widget.period);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(valueListenable: _controller, builder: widget.builder, child: widget.child);
  }
}

/// Sizes the column according to the intrinsic dimensions of the
/// cell in the specified row of the relevant column.
///
/// The row is specified using [row].
///
/// This is an expensive way to size a column, compared to
/// [FixedColumnWidth], [FlexColumnWidth], or [FractionColumnWidth],
/// but is much cheaper than [IntrinsicColumnWidth] when the table has
/// a lot of rows.
///
/// A flex value can be provided. If specified (and non-null), the
/// column will participate in the distribution of remaining space
/// once all the non-flexible columns have been sized.
class IntrinsicCellWidth extends TableColumnWidth {
  /// Creates a column width based on intrinsic sizing of the column's cell in
  /// the specified [row] (which defaults to the first row, with index 0).
  ///
  /// The `flex` argument specifies the flex factor to apply to the column if
  /// there is any room left over when laying out the table. If `flex` is
  /// null (the default), the table will not distribute any extra space to the
  /// column.
  const IntrinsicCellWidth({this.row = 0, double? flex}) : _flex = flex;

  /// The row from which to obtain the cell to measure.
  ///
  /// If the table does not have enough rows, then the cell is assumed to
  /// have be of zero width.
  final int row;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    if (cells.length >= row) {
      result = math.max(result, cells.skip(row).first.getMinIntrinsicWidth(double.infinity));
    }
    return result;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    if (cells.length >= row) {
      result = math.max(result, cells.skip(row).first.getMaxIntrinsicWidth(double.infinity));
    }
    return result;
  }

  final double? _flex;

  @override
  double? flex(Iterable<RenderBox> cells) => _flex;

  @override
  String toString() => '${objectRuntimeType(this, 'IntrinsicCellWidth')}(flex: ${_flex?.toStringAsFixed(1)})';
}

class RemoveFromShortlistCell extends StatelessWidget {
  const RemoveFromShortlistCell({
    super.key,
    required this.competition,
    required this.team,
    required this.foregroundColor,
    required this.award,
  });

  final Competition competition;
  final Team team;
  final Color foregroundColor;
  final Award award;

  @override
  Widget build(BuildContext context) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: ListenableBuilder(
        listenable: competition,
        builder: (BuildContext context, Widget? child) => IconButton(
          onPressed: () {
            competition.removeFromShortlist(award, team);
          },
          padding: EdgeInsets.zero,
          iconSize: DefaultTextStyle.of(context).style.fontSize,
          visualDensity: VisualDensity.compact,
          color: foregroundColor,
          tooltip: competition.removingFromShortlistWillRemoveInspireRank(award, team)
              ? 'Unnominating team ${team.number} will remove them from the rankings for the ${competition.inspireAward!.name} award'
              : null,
          icon: const Icon(
            Symbols.heart_minus,
          ),
        ),
      ),
    );
  }
}
