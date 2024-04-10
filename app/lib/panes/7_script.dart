import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:parchment/codecs.dart';

import '../constants.dart';
import '../model/competition.dart';
import '../widgets/awards.dart';
import '../widgets/widgets.dart';
import '6_finalists.dart';

class ScriptPane extends StatelessWidget {
  const ScriptPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        final List<(Award, List<AwardFinalistEntry>)> finalists = competition.computeFinalists().where(
          ((Award, List<AwardFinalistEntry>) finalists) {
            // ignore: unused_local_variable
            final (Award award, List<AwardFinalistEntry> entries) = finalists;
            return entries.any(
              (AwardFinalistEntry entry) {
                // ignore: unused_local_variable
                final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool overridden) = entry;
                return team != null && otherAward == null && rank == 1;
              },
            );
          },
        ).toList();
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Heading(title: '7. Script'),
            const SizedBox(height: indent),
            for (final (Award award, List<AwardFinalistEntry> entries) in finalists)
              AwardScriptEditor(
                competition: competition,
                award: award,
                entries: entries,
              ),
            ExportButton(
              label: 'Export awards ceremony script (HTML)',
              onPressed: () => AwardFinalistsPane.exportFinalistsScriptHTML(context, competition),
              padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, indent),
            ),
          ],
        );
      },
    );
  }
}

class AwardScriptEditor extends StatelessWidget {
  const AwardScriptEditor({
    super.key,
    required this.competition,
    required this.award,
    required this.entries,
  });

  final Competition competition;
  final Award award;
  final List<AwardFinalistEntry> entries;

  @override
  Widget build(BuildContext context) {
    List<Team> winners = [];
    List<Team> runnersUp = [];
    bool ties = false;
    // ignore: unused_local_variable
    for (final (Team? team, Award? otherAward, int rank, tied: bool tied, overridden: bool overridden) in entries) {
      if (team != null && otherAward == null) {
        if (rank == 1 || !award.isPlacement) {
          ties = ties || tied;
          winners.add(team);
        } else {
          assert(rank > 1);
          runnersUp.add(team);
        }
      }
    }
    Widget child;
    if (winners.isEmpty) {
      child = const Text(
        'No winners have been assigned for this award. Use the Ranks pane to assign winners.',
        softWrap: true,
        overflow: TextOverflow.clip,
      );
    } else if (ties) {
      child = const Text(
        'Multiple teams are tied for this award. Use the Ranks pane to assign winners.',
        softWrap: true,
        overflow: TextOverflow.clip,
      );
    } else {
      final List<Widget> children = <Widget>[];
      for (final Team team in winners) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: indent));
        }
        children.add(
          ListenableBuilder(
            listenable: team,
            builder: (BuildContext context, Widget? child) {
              final ShortlistEntry? entry = team.shortlistsView[award];
              final Color foregroundColor = DefaultTextStyle.of(context).style.color!;
              return ListBody(
                children: [
                  Row(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Winner: ${team.number} '),
                            TextSpan(text: team.name, style: italic),
                            TextSpan(text: ' from ${team.city}'),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (entry != null && entry.nominator.isNotEmpty)
                        Tooltip(
                          message: entry.nominator,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: spacing / 4.0),
                            child: Icon(
                              Symbols.people,
                              size: DefaultTextStyle.of(context).style.fontSize,
                              color: foregroundColor,
                            ),
                          ),
                        ),
                      if (entry != null && entry.comment.isNotEmpty)
                        Tooltip(
                          message: entry.comment,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: spacing / 4.0),
                            child: Icon(
                              Symbols.mark_unread_chat_alt,
                              size: DefaultTextStyle.of(context).style.fontSize,
                              color: foregroundColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0.0, spacing, 0.0, spacing),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(spacing),
                        border: Border.all(color: Colors.black),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            blurStyle: BlurStyle.inner,
                            blurRadius: spacing / 2.0,
                          )
                        ],
                      ),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: Colors.black),
                        child: ListBody(
                          children: [
                            if (!award.isPlacement) ScriptAwardSubnameEditor(competition: competition, award: award, team: team),
                            ScriptBlurbEditor(competition: competition, award: award, team: team),
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
      if (runnersUp.isNotEmpty) {
        children.add(Text('${runnersUp.length == 1 ? "Runner-up" : "Runners-up"}: ${runnersUp.map((Team team) => "${team.number}").join(", ")}'));
      }
      assert(children.isNotEmpty);
      if (children.length > 1) {
        child = ListBody(
          children: children,
        );
      } else {
        child = children.single;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, indent),
      child: ScrollableRegion(
        child: AwardCard(
          intrisicallySized: false,
          award: award,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(spacing, 0, spacing, spacing),
            child: child,
          ),
        ),
      ),
    );
  }
}

class ScriptBlurbEditor extends StatefulWidget {
  ScriptBlurbEditor({
    required this.competition,
    required this.award,
    required this.team,
  }) : super(key: ValueKey(TripleIdentity<ScriptBlurbEditor, Competition, Award, Team>(competition, award, team)));

  final Competition competition;
  final Award award;
  final Team team;

  @override
  State<ScriptBlurbEditor> createState() => _ScriptBlurbEditorState();
}

class _ScriptBlurbEditorState extends State<ScriptBlurbEditor> {
  final FleatherController _controller = FleatherController();
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    widget.team.addListener(_handleTeamChanged);
    _handleTeamChanged();
  }

  void _handleControllerChanged() {
    assert(!_locked);
    _locked = true;
    try {
      widget.competition.updateBlurb(widget.team, widget.award, parchmentHtml.encode(_controller.document));
    } finally {
      _locked = false;
    }
  }

  void _handleTeamChanged() {
    if (_locked) {
      return;
    }
    _controller.document.delete(0, _controller.document.length);
    _controller.document.compose(parchmentHtml.decode(widget.team.blurbsView[widget.award] ?? '').toDelta(), ChangeSource.local);
    // trim trailing empty paragraphs
    while (_controller.document.root.last is LineNode &&
        (_controller.document.root.last as LineNode).isEmpty &&
        (_controller.document.root.last as LineNode).style.isEmpty &&
        _controller.document.root.childCount > 1) {
      _controller.document.delete(_controller.document.length - 2, 2);
    }
  }

  @override
  void dispose() {
    widget.team.removeListener(_handleTeamChanged);
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: indent * 5.0,
      child: FleatherEditor(
        padding: const EdgeInsets.fromLTRB(spacing, 0.0, spacing, 0.0),
        controller: _controller,
      ),
    );
  }
}

class ScriptAwardSubnameEditor extends StatefulWidget {
  ScriptAwardSubnameEditor({
    required this.competition,
    required this.award,
    required this.team,
  }) : super(key: ValueKey(TripleIdentity<ScriptAwardSubnameEditor, Competition, Award, Team>(competition, award, team)));

  final Competition competition;
  final Award award;
  final Team team;

  @override
  State<ScriptAwardSubnameEditor> createState() => _ScriptAwardSubnameEditorState();
}

class _ScriptAwardSubnameEditorState extends State<ScriptAwardSubnameEditor> {
  final TextEditingController _controller = TextEditingController();
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    widget.team.addListener(_handleTeamChanged);
    _handleTeamChanged();
  }

  void _handleControllerChanged() {
    if (_locked) {
      return;
    }
    widget.competition.updateAwardSubname(widget.team, widget.award, _controller.text);
  }

  void _handleTeamChanged() {
    assert(!_locked);
    _locked = true;
    try {
      _controller.text = widget.team.awardSubnamesView[widget.award] ?? '';
    } finally {
      _locked = false;
    }
  }

  @override
  void dispose() {
    widget.team.removeListener(_handleTeamChanged);
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(spacing, spacing, spacing, spacing),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: widget.award.name,
          labelText: 'Award name',
        ),
        style: DefaultTextStyle.of(context).style,
      ),
    );
  }
}
