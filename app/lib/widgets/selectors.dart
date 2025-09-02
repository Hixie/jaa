import 'package:flutter/material.dart';

import '../model/competition.dart';
import '../utils/constants.dart';

class TeamOrderSelector extends StatelessWidget {
  const TeamOrderSelector({
    super.key,
    required this.value,
    required this.onChange,
  });

  final TeamComparatorCallback value;
  final ValueChanged<TeamComparatorCallback> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          selected: <TeamComparatorCallback>{value},
          onSelectionChanged: (Set<TeamComparatorCallback> newSelection) {
            onChange(newSelection.single);
          },
        ),
      ],
    );
  }
}