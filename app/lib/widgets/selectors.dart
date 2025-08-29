import 'package:flutter/material.dart';

import '../model/competition.dart';
import '../utils/constants.dart';

class TeamOrderSelector extends StatelessWidget {
  const TeamOrderSelector({
    super.key,
    required this.competition,
  });

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) => Row(
        children: [
          Text('Sort order:'),
          SizedBox(width: indent),
          SegmentedButton<TeamComparatorCallback>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<TeamComparatorCallback>>[
              ButtonSegment<TeamComparatorCallback>(
                value: Team.teamNumberComparator,
                label: Text('Team Number'),
              ),
              ButtonSegment<TeamComparatorCallback>(
                value: Team.inspireCandidateComparator,
                label: Text('Rank Score'),
              ),
              ButtonSegment<TeamComparatorCallback>(
                value: Team.rankedCountComparator,
                label: Text('Ranked Count'),
              ),
            ],
            selected: <TeamComparatorCallback>{competition.finalistsSortOrder},
            onSelectionChanged: (Set<TeamComparatorCallback> newSelection) {
              competition.finalistsSortOrder = newSelection.single;
            },
          ),
        ],
      ),
    );
  }
}