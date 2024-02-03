import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'constants.dart';

Future<PlatformFile?> openFile(
  BuildContext context, {
  required String title,
  required String extension,
}) async {
  Navigator.push(
    context,
    PageRouteBuilder<void>(
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
    ),
  );
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    dialogTitle: title,
    type: FileType.custom,
    allowedExtensions: [extension],
    withReadStream: true,
    lockParentWindow: true,
  );
  // ignore: use_build_context_synchronously
  Navigator.pop(context);
  return result?.files.single;
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
