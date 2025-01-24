import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jaa/main.dart';
import 'package:jaa/model/competition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file/memory.dart';

void main() {
  testWidgets('', (WidgetTester tester) async {
    final MemoryFileSystem fs = MemoryFileSystem.test();
    final Competition competition = Competition(
      autosaveDirectory: fs.systemTempDirectory,
      exportDirectoryBuilder: () async => fs.systemTempDirectory,
    );
    competition.debugGenerateRandomData(math.Random(0));
    await tester.pumpWidget(MainApp(competition: competition));
    expect(find.text('362 Teams.'), findsOneWidget);

    // edit team button
    expect(find.text('Edit team:'), findsNothing);
    await tester.tap(find.text('Show team editor'));
    await tester.pump();
    expect(find.text('Edit team:'), findsOneWidget);
    // TODO: add a test for actually editing the team

    // shortlists
    await tester.tap(find.text('2. Shortlists'));
    await tester.pump();
    await tester.tap(find.text('ISOEA'));
    await tester.pump();

    // shut down
    await tester.pumpWidget(const SizedBox.shrink());
    competition.dispose();
  });
}
