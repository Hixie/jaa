import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../constants.dart';
import '../model/competition.dart';
import 'widgets.dart';

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
                            if (award.spreadTheWealth != SpreadTheWealth.no) TextSpan(text: '#${award.rank}: '),
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
          ? const Padding(
              padding: EdgeInsets.fromLTRB(indent, 0.0, indent, 0.0),
              child: Text('No awards loaded. Use the Setup pane to import an awards list.'),
            )
          : ScrollableRegion(
              child: Wrap(
                runSpacing: spacing,
                spacing: 0.0,
                children: _buildChildren(),
              ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(indent, spacing, indent, indent),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: () {
                  competition.awardOrder = AwardOrder.rank;
                },
                child: const Text(
                  'Sort awards by rank',
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(spacing, 0.0, spacing, 0.0),
              child: MergeSemantics(
                child: Semantics(
                  label: 'Sort awards by category (rather than rank)',
                  child: ListenableBuilder(
                    listenable: competition,
                    builder: (BuildContext context, Widget? child) => Switch.adaptive(
                      value: competition.awardOrder == AwardOrder.categories,
                      thumbIcon: MaterialStateProperty.all(const Icon(Symbols.trophy)),
                      onChanged: (bool value) {
                        competition.awardOrder = value ? AwardOrder.categories : AwardOrder.rank;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: () {
                  competition.awardOrder = AwardOrder.categories;
                },
                child: const Text(
                  'Sort awards by category',
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
