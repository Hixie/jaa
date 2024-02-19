import 'package:flutter/material.dart';
import 'package:jaa/exporters.dart';

import '2_shortlists.dart';
import '3_pitvisits.dart';
import '4_ranks.dart';
import '5_inspire.dart';
import '6_finalists.dart';
import '../constants.dart';
import '../model/competition.dart';
import '../widgets.dart';

class ExportPane extends StatelessWidget {
  const ExportPane({super.key, required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: competition,
      builder: (BuildContext context, Widget? child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Heading('7. Export'),
            ExportButton(
              label: 'Export event state (ZIP)',
              onPressed: () => exportEventState(context, competition),
            ),
            ExportButton(
              label: 'Export shortlists (HTML)',
              onPressed: () => ShortlistsPane.exportShortlistsHTML(context, competition),
            ),
            ExportButton(
              label: 'Export pit visits table (HTML)',
              onPressed: () => PitVisitsPane.exportPitVisitsHTML(context, competition),
            ),
            ExportButton(
              label: 'Export ranked lists (HTML)',
              onPressed: () => RanksPane.exportRanksHTML(context, competition),
            ),
            ExportButton(
              label: 'Export Inspire candidates table (CSV)',
              onPressed: () => exportInspireCandidatesTable(context, competition),
            ),
            ExportButton(
              label: 'Export Inspire award results (HTML)',
              onPressed: () => InspirePane.exportInspireHTML(context, competition),
            ),
            ExportButton(
              label: 'Export awards ceremony script (HTML)',
              onPressed: () => AwardFinalistsPane.exportFinalistsScriptHTML(context, competition),
            ),
            ExportButton(
              label: 'Export finalists tables (CSV)',
              onPressed: () => exportFinalistsTable(context, competition),
            ),
            ExportButton(
              label: 'Export finalists lists (CSV)',
              onPressed: () => exportFinalistsLists(context, competition),
            ),
            ExportButton(
              label: 'Export finalists tables (HTML)',
              onPressed: () => AwardFinalistsPane.exportFinalistsTableHTML(context, competition),
            ),
          ],
        );
      },
    );
  }
}

class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
      child: FilledButton(
        onPressed: onPressed,
        child: Text(
          label,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
