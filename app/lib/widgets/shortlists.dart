import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/constants.dart';
import '../model/competition.dart';
import 'awards.dart';
import 'widgets.dart';

class TriggerNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
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
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _teamFocusNode = FocusNode();
  final FocusNode _nominatorFocusNode = FocusNode();
  final FocusNode _commentFocusNode = FocusNode();
  final TriggerNotifier _addedTrigger = TriggerNotifier();

  Award? _award;
  Team? _team;

  @override
  void initState() {
    super.initState();
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
    _commentController.dispose();
    _teamFocusNode.dispose();
    _nominatorFocusNode.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _markNeedsBuild() {
    setState(() {
      // build is dependent on the competition object
    });
  }

  void _handleAwardSelection(Award award) {
    if (_award == award) {
      if (_teamController.text.isEmpty && _nominatorController.text.isEmpty && _commentController.text.isEmpty) {
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

  void _addTeamToShortlist() {
    widget.competition.addToShortlist(
      _award!,
      _team!,
      ShortlistEntry(
        nominator: _nominatorController.text,
        comment: _commentController.text,
        lateEntry: widget.lateEntry,
      ),
    );
    _addedTrigger.trigger();
    _teamController.clear();
    // we intentionally don't clear the nominator field
    _commentController.clear();
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
            child: AwardSelector(
              label: 'Nominate for:',
              awards: widget.sortedAwards,
              onPressed: _handleAwardSelection,
            ),
          ),
        if (_award != null)
          TriggerAnimation(
            trigger: _addedTrigger,
            child: Padding(
              key: _cardKey,
              padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
              child: ListenableBuilder(
                listenable: _award!,
                child: ListenableBuilder(
                  listenable: widget.competition.shortlistsView[_award]!,
                  builder: (BuildContext context, Widget? child) {
                    final Set<Team> shortlistedTeams = widget.competition.shortlistsView[_award]!.entriesView.keys.toSet();
                    final List<Team> remainingTeams = widget.competition.teamsView.where((Team team) => !shortlistedTeams.contains(team)).toList();
                    return InlineScrollableCard(
                      children: remainingTeams.isEmpty
                          ? [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(text: 'All the teams have already been shortlisted for the '),
                                    TextSpan(text: _award!.name, style: bold),
                                    TextSpan(text: ' (${_award!.description}) award!'),
                                  ],
                                ),
                              ),
                            ]
                          : [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(text: 'Nominate team for '),
                                    TextSpan(text: _award!.name, style: bold),
                                    TextSpan(text: ' (${_award!.description})${widget.lateEntry ? " as a late entry" : ""}:'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: spacing),
                              LayoutBuilder(
                                builder: (BuildContext context, BoxConstraints constraints) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: constraints.maxWidth - indent * 7 - spacing),
                                      child: DropdownList<Team>(
                                        focusNode: _teamFocusNode,
                                        controller: _teamController,
                                        onSelected: _handleTeamChange,
                                        label: 'Team',
                                        values: Map<Team, String>.fromIterable(
                                          widget.competition.teamsView.where((Team team) => !team.shortlistsView.containsKey(_award)),
                                          value: (dynamic team) => '${team.number} ${team.name}',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: spacing),
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
                                          if (_team == null) {
                                            _teamFocusNode.requestFocus();
                                          } else if (_commentController.text.isEmpty) {
                                            _commentFocusNode.requestFocus();
                                          } else {
                                            _addTeamToShortlist();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: spacing),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _commentController,
                                      focusNode: _commentFocusNode,
                                      decoration: const InputDecoration(
                                        label: Text(
                                          'Comment',
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
                                  const SizedBox(width: spacing),
                                  IconButton.filledTonal(
                                    onPressed: _team != null ? _addTeamToShortlist : null,
                                    icon: const Icon(
                                      Symbols.heart_plus,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                      onClosed: () {
                        setState(() {
                          _award = null;
                          _team = null;
                          _teamController.clear();
                          _nominatorController.clear();
                        });
                      },
                    );
                  },
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

class RemoveFromShortlistCell extends StatelessWidget {
  const RemoveFromShortlistCell({
    super.key,
    required this.competition,
    required this.team,
    required this.award,
    required this.foregroundColor,
  });

  final Competition competition;
  final Team team;
  final Award award;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: ListenableBuilder(
        listenable: competition,
        builder: (BuildContext context, Widget? child) {
          if (competition.awardIsAutonominated(award, team)) {
            return Tooltip(
              message: 'Team is currently autonominated for this award.',
              child: IconTheme.merge(
                data: IconThemeData(
                  size: DefaultTextStyle.of(context).style.fontSize,
                  color: foregroundColor,
                ),
                child: const Icon(
                  Symbols.smart_toy,
                ),
              ),
            );
          }
          return IconButton(
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
          );
        },
      ),
    );
  }
}
