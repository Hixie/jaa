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
  bool? _hasPortfolio;

  bool _bulk = false;
  List<(Team?, String)>? _parsedBulk;
  bool _bulkValid = false;

  @override
  void initState() {
    super.initState();
    widget.competition.addListener(_markNeedsBuild);
    _teamController.addListener(_handleTeamTextChange);
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
          _hasPortfolio = null;
          _teamController.clear();
          _parsedBulk = null;
          _bulkValid = false;
        }
      });
      _teamFocusNode.requestFocus();
    }
  }

  void _handleTeamChange(Team? team) {
    _nominatorFocusNode.requestFocus();
    setState(() {
      _team = team;
      _hasPortfolio = _team?.hasPortfolio;
    });
  }

  void _handleTeamTextChange() {
    if (_bulk) {
      setState(() {
        _parsedBulk = _parseBulk(_teamController.text);
        _bulkValid = _parsedBulk!.isNotEmpty && _parsedBulk!.every((final (Team? team, String comment) entry) => entry.$1 != null && entry.$2.isEmpty);
      });
    } else {
      _parsedBulk = null;
      _bulkValid = false;
    }
  }

  void _addTeamToShortlist() {
    if (_bulk) {
      throw StateError('Cannot add single team when in bulk mode');
    }
    if (_team?.hasPortfolio != _hasPortfolio) {
      widget.competition.updatePortfolio(_team!, _hasPortfolio!);
    }
    assert(!_award!.needsPortfolio || _team!.hasPortfolio);
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
    _parsedBulk = null;
    _bulkValid = false;
    // we intentionally don't clear the nominator field
    _commentController.clear();
    _teamFocusNode.requestFocus();
    setState(() {
      _team = null;
      _hasPortfolio = null;
    });
  }

  void _addBulkTeamsToShortlist() {
    if (!_bulk) {
      throw StateError('Cannot add bulk teams when not in bulk mode');
    }
    for (Team team in (_parsedBulk!.map<Team>((final (Team?, String) entry) => entry.$1!))) {
      widget.competition.addToShortlist(
        _award!,
        team,
        ShortlistEntry(
          nominator: _nominatorController.text,
          comment: _commentController.text,
          lateEntry: widget.lateEntry,
        ),
      );
    }
    _addedTrigger.trigger();
    _teamController.clear();
    _parsedBulk = null;
    _bulkValid = false;
    // we intentionally don't clear the nominator field
    _commentController.clear();
    _teamFocusNode.requestFocus();
    setState(() {
      _team = null;
      _hasPortfolio = null;
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
                    final List<Team> remainingTeams = widget.competition.teamsView.where((Team team) => !shortlistedTeams.contains(team) && team.inspireStatus != InspireStatus.exhibition).toList();
                    return InlineScrollableCard(
                      toolbar: AnimatedContainer(
                        duration: animationDuration,
                        curve: Curves.easeInOut,
                        decoration: ShapeDecoration(
                          shape: StadiumBorder(),
                          color: _bulk ? Theme.of(context).colorScheme.tertiaryContainer : Theme.of(context).colorScheme.primaryContainer,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: animationDuration,
                          curve: Curves.easeInOut,
                          style: DefaultTextStyle.of(context).style.apply(
                            color: _bulk ? Theme.of(context).colorScheme.onTertiaryContainer : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          child: Builder(
                            builder: (context) { // provides context for DefaultTextStyle below
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(spacing / 2.0, spacing / 2.0, spacing, spacing / 2.0),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: DefaultTextStyle.of(context).style.fontSize!),
                                  child: FittedBox(
                                    alignment: AlignmentGeometry.centerRight,
                                    child: MergeSemantics(
                                      child: Row(
                                        children: [
                                          Switch(
                                            value: _bulk,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                _bulk = value!;
                                              });
                                            },
                                          ),
                                          SizedBox(width: spacing),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _bulk = !_bulk;
                                              });
                                            },
                                            child: Text('BULK', style: DefaultTextStyle.of(context).style.apply(fontSizeFactor: 2.0)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                          ),
                        ),
                      ),
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
                          : _bulk ? buildBulkNominatorForm() : buildSingleTeamNominatorForm(),
                      onClosed: () {
                        setState(() {
                          _award = null;
                          _team = null;
                          _hasPortfolio = null;
                          _teamController.clear();
                          _parsedBulk = null;
                          _bulkValid = false;
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

  List<Widget> buildSingleTeamNominatorForm() {
    return [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Nominate team for '),
            TextSpan(text: _award!.name, style: bold),
            TextSpan(text: ' (${_award!.description})${widget.lateEntry ? " as a late entry" : ""}:'),
          ],
        ),
      ),
      const SizedBox(height: spacing),
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth - indent * 7 - spacing),
              child: DropdownList<Team>(
                focusNode: _teamFocusNode,
                controller: _teamController,
                onSelected: _handleTeamChange,
                label: 'Team',
                values: Map<Team, String>.fromIterable(
                  widget.competition.teamsView.where((Team team) => !team.shortlistsView.containsKey(_award) && team.inspireStatus != InspireStatus.exhibition),
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
                  } else if (!_award!.needsPortfolio || (_hasPortfolio == true)) {
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
                  if (!_award!.needsPortfolio || (_hasPortfolio == true)) {
                    _addTeamToShortlist();
                  }
                } else {
                  _teamFocusNode.requestFocus();
                }
              },
            ),
          ),
          const SizedBox(width: spacing),
          MergeSemantics(
            child: Row(
              children: [
                Checkbox(
                  value: _hasPortfolio,
                  tristate: _hasPortfolio == null,
                  onChanged: _hasPortfolio == null ? null : (bool? value) { 
                    setState(() {
                      _hasPortfolio = value;
                    });
                  },
                ),
                GestureDetector(
                  onTap: _hasPortfolio == null ? null : () { 
                    setState(() {
                      _hasPortfolio = _hasPortfolio == false;
                    });
                  },
                  child: Text('Team has portfolio', style: _team != null && _award!.needsPortfolio && (_hasPortfolio != true) ? red : null)
                ),
              ],
            ),
          ),
          const SizedBox(width: spacing * 2.0),
          IconButton.filledTonal(
            onPressed: _team != null && (!_award!.needsPortfolio || (_hasPortfolio == true)) ? _addTeamToShortlist : null,
            icon: const Icon(
              Symbols.heart_plus,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> buildBulkNominatorForm() {
    return [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Nominate teams for '),
            TextSpan(text: _award!.name, style: bold),
            TextSpan(text: ' (${_award!.description})${widget.lateEntry ? " as late entries" : ""}:'),
          ],
        ),
      ),
      const SizedBox(height: spacing),
      TextField(
        controller: _teamController,
        focusNode: _teamFocusNode,
        decoration: const InputDecoration(
          label: Text(
            'Teams (space or comma separated)',
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (String value) {
          if (!_bulkValid) {
            _teamFocusNode.requestFocus();
          } else if (_nominatorController.text.isEmpty) {
            _nominatorFocusNode.requestFocus();
          } else if (_commentController.text.isEmpty) {
            _commentFocusNode.requestFocus();
          } else {
            _addBulkTeamsToShortlist();
          }
        },
      ),
      const SizedBox(height: spacing),
      TextField(
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
          if (!_bulkValid) {
            _teamFocusNode.requestFocus();
          } else if (_commentController.text.isEmpty) {
            _commentFocusNode.requestFocus();
          } else {
            _addBulkTeamsToShortlist();
          }
        },
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
                if (!_bulkValid) {
                  _teamFocusNode.requestFocus();
                } else {
                  _addBulkTeamsToShortlist();
                }
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: spacing),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListBody(
              children: [
                if (_parsedBulk != null)
                  for (final (Team? team, String comment) in _parsedBulk!)
                    if (team != null)
                      Text(' $bullet #${team.number} ${team.name}${comment.isNotEmpty ? " — $comment" : ""}', style: comment.isNotEmpty ? red : null)
                    else
                      Text(' $bullet $comment', style: red),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _bulkValid ? _addBulkTeamsToShortlist : null, 
            icon: const Icon(
              Symbols.heart_plus,
            ),
          ),
        ],
      ),
    ];
  }

  List<(Team?, String)> _parseBulk(String input) {
    final List<(Team?, String)> result = <(Team?, String)>[];
    final Map<int, Team> teamMap = {
      for (final Team team in widget.competition.teamsView) team.number: team,
    };
    List<int> buffer = <int>[];
    bool error = false;
    for (int c in '$input\x00'.runes) {
      switch (c) {
        case 0x00:
        case 0x0A:
        case 0x0D:
        case 0x20:
        case 0x2C: // split
          if (buffer.isNotEmpty) {
            if (error) {
              result.add((null, 'Invalid input: "${String.fromCharCodes(buffer)}"'));
            } else {
              int? number = int.tryParse(String.fromCharCodes(buffer));
              if (number == null) {
                result.add((null, 'Invalid number: "${String.fromCharCodes(buffer)}"'));
              } else {
                Team? team = teamMap[number];
                if (team == null) {
                  result.add((null, 'Unknown team: $number'));
                } else if (team.inspireStatus == InspireStatus.exhibition) {
                  result.add((team, 'Exhibition team'));
                } else if (_award!.needsPortfolio && !team.hasPortfolio) {
                  result.add((team, 'Team has no portfolio'));
                } else if (team.shortlistsView.containsKey(_award)) {
                  result.add((team, 'Team already shortlisted for this award'));
                } else {
                  result.add((team, ''));
                }
              }
            }
          }
          buffer.clear();
          error = false;
        case >=0x30 && <=0x39: // 0-9
          buffer.add(c);
        default:
          buffer.add(c);
          error = true;
      }
    }
    return result;
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

  late String _inspireSummary;
  late String _overallSummary;
  void _updateSummary() {
    setState(() {
      _inspireSummary = _generateInspireSummary();
      _overallSummary = _generateOverallSummary();
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    _updateSummary();
  }

  String _generateInspireSummary() {
    if (widget.competition.inspireAward == null) {
      return '';
    }
    final Map<int, Map<Team, Set<String>>> candidates = widget.competition.computeInspireCandidates();
    final List<String> categories = widget.competition.inspireCategories;
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
      requiredAwards = 'awards in both Inspire-contributing award categories';
    } else {
      requiredAwards = 'awards in all $targetCategories Inspire-contributing award categories';
    }
    if (!candidates.containsKey(targetCategories)) {
      return 'No teams are nominated for $requiredAwards, '
          'and thus no teams yet fully qualify for the ${widget.competition.inspireAward!.name} award.';
    }
    final int nomineeTarget = widget.competition.inspireAward!.count;
    final int totalNomineeCount = candidates[targetCategories]!.length;
    final int qualifyingNomineeCount = candidates[targetCategories]!.keys.where(
      (Team team) => team.inspireStatus == InspireStatus.eligible || team.inspireStatus == InspireStatus.hidden,
    ).length;
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

  String _generateOverallSummary() {
    final List<(Award, List<AwardFinalistEntry>)> finalists = widget.competition.computeFinalists();
    final List<Award> incompleteAwards = <Award>[];
    for ((Award, List<AwardFinalistEntry>) entry in finalists) {
      final Award award = entry.$1;
      if (award.isInspire) {
        continue;
      }
      final List<AwardFinalistEntry> awardFinalists = entry.$2;
      int count = 0;
      for (AwardFinalistEntry finalist in awardFinalists) {
        final Team? team = finalist.$1;
        final Award? otherAward = finalist.$2;
        if (team != null && otherAward == null) {
          count += 1;
        }
      }
      if (count < award.count) {
        incompleteAwards.add(award);
      }
    }
    if (incompleteAwards.isEmpty) {
      return '🏆 Sufficient teams have been ranked to have finalists for all awards.';
    }
    incompleteAwards.sort(widget.competition.awardSorter);
    if (incompleteAwards.length == 1) {
      return '⚠️ The ${incompleteAwards.single.name} award may not yet have sufficient ranked teams to assign finalists to all placements.';
    }
    return '⚠️ The following awards may not yet have sufficient ranked teams to assign finalists to all placements: '
        '${incompleteAwards.map((Award award) => award.name).join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    if (_inspireSummary.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
      child: Text(
        '$_inspireSummary\n$_overallSummary',
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
