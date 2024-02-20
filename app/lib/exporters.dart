import 'dart:io';

import 'package:flutter/material.dart';

import 'io.dart';
import 'model/competition.dart';

// TODO: support Android and iOS using https://pub.dev/packages/flutter_file_dialog

Future<void> exportEventState(BuildContext context, Competition competition) async {
  final String? filename = await saveFile(
    context,
    title: 'Export event state (ZIP)',
    extension: 'zip',
  );
  if (filename != null) {
    await showProgress(
      context, // ignore: use_build_context_synchronously
      message: 'Exporting event state...',
      task: () async {
        competition.exportEventState(filename);
      },
    );
  }
}

Future<void> exportPitVisitNotes(BuildContext context, Competition competition) async {
  final String? filename = await saveFile(
    context,
    title: 'Export pit visit notes (CSV)',
    extension: 'csv',
  );
  if (filename != null) {
    await showProgress(
      context, // ignore: use_build_context_synchronously
      message: 'Exporting pit visit notes...',
      task: () => File(filename).writeAsString(competition.pitVisitNotesToCsv()),
    );
  }
}

Future<void> exportInspireCandidatesTable(BuildContext context, Competition competition) async {
  final String? filename = await saveFile(
    context,
    title: 'Export Inspire candidates table (CSV)',
    extension: 'csv',
  );
  if (filename != null) {
    await showProgress(
      context, // ignore: use_build_context_synchronously
      message: 'Exporting Inspire candidates...',
      task: () => File(filename).writeAsString(competition.inspireCandiatesToCsv()),
    );
  }
}

Future<void> exportFinalistsTable(BuildContext context, Competition competition) async {
  final String? filename = await saveFile(
    context,
    title: 'Export finalists tables (CSV)',
    extension: 'csv',
  );
  if (filename != null) {
    await showProgress(
      context, // ignore: use_build_context_synchronously
      message: 'Exporting finalists...',
      task: () => File(filename).writeAsString(competition.finalistTablesToCsv()),
    );
  }
}

Future<void> exportFinalistsLists(BuildContext context, Competition competition) async {
  final String? filename = await saveFile(
    context,
    title: 'Export finalists lists (CSV)',
    extension: 'csv',
  );
  if (filename != null) {
    await showProgress(
      context, // ignore: use_build_context_synchronously
      message: 'Exporting finalists...',
      task: () => File(filename).writeAsString(competition.finalistListsToCsv()),
    );
  }
}
