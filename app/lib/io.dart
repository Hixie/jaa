import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'model/competition.dart';

Route _createModalBackdrop() => PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
        return const ModalBarrier(
          color: scrim,
          dismissible: false,
        );
      },
      transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );

Future<void> exportHTML(Competition competition, String prefix, DateTime now, String body) async {
  final String filename = path.join((await competition.exportDirectory).path, '$prefix.${now.millisecondsSinceEpoch}.html');
  await File(filename).writeAsString(body);
  await launchUrl(Uri.file(filename));
}

StringBuffer createHtmlPage(Competition competition, String header, DateTime now) {
  final String eventNamePrefix = competition.eventName.isEmpty ? '' : '${competition.eventName} — ';
  return StringBuffer()
    ..writeln('<!DOCTYPE HTML>')
    ..writeln('<style>$css</style>')
    ..writeln('<title>${escapeHtml("$eventNamePrefix$header")}</title>')
    ..writeln('<h1>${escapeHtml("$eventNamePrefix$header")}</h1>')
    ..writeln('<p>Exported at: <time>${escapeHtml(now.toIso8601String())}</time></p>');
}

String escapeHtml(String raw) {
  return raw.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}

String escapeFilename(String raw) {
  return raw.replaceAll(RegExp(r'[:/\\]'), '_').replaceAll(RegExp(r'\.+$'), '');
}

Future<PlatformFile?> openFile(
  BuildContext context, {
  required String title,
  required String extension,
}) async {
  Navigator.push(context, _createModalBackdrop());
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: title,
      type: FileType.custom,
      allowedExtensions: [extension, '*'],
      withReadStream: true,
      lockParentWindow: true,
    );
    return result?.files.single;
  } finally {
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
  }
}

Future<String?> saveFile(
  BuildContext context, {
  required String title,
  required String filename,
  required String extension,
}) async {
  Navigator.push(context, _createModalBackdrop());
  try {
    String? result = await FilePicker.platform.saveFile(
      dialogTitle: title,
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: [extension, '*'],
      lockParentWindow: true,
    );
    if (result != null) {
      if (path.extension(result) == '') {
        result += '.$extension';
      }
    }
    return result;
  } finally {
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
  }
}

Future<T> showProgress<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() task,
}) async {
  Navigator.push(
    context,
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
        return Stack(
          children: [
            const ModalBarrier(
              color: scrim,
              dismissible: false,
            ),
            const Center(
              child: CircularProgressIndicator(),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(indent),
                child: Text(message, textAlign: TextAlign.center, style: headingStyle),
              ),
            ),
          ],
        );
      },
      transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
  try {
    try {
      return await task();
    } finally {
      Navigator.pop(context); // ignore: use_build_context_synchronously
    }
  } catch (e) {
    final String message;
    switch (e) {
      case FormatException(message: final String m):
        message = m;
      default:
        message = '$e';
    }
    await showAdaptiveDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog.adaptive(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    rethrow;
  }
}
