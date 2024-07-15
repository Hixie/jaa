import 'package:flutter/material.dart';

const Color background = Color.fromARGB(255, 255, 255, 255);
const Color control = Color.fromARGB(255, 227, 232, 236);
const Color scrim = Color.fromARGB(64, 0, 0, 0);

const Color primary = Color.fromARGB(255, 101, 89, 245);
const Color primaryText = Color.fromARGB(255, 0, 0, 0);
const TextStyle primaryStyle = TextStyle(
  inherit: false,
  fontFamily: 'Roboto',
  color: primaryText,
  fontSize: 14.0,
);

const Color accent = Color.fromARGB(255, 223, 222, 254);
const Color accentText = Color.fromARGB(255, 66, 78, 94);
const TextStyle accentStyle = TextStyle(
  inherit: false,
  fontFamily: 'Roboto',
  color: accentText,
  fontSize: 14.0,
);

const TextStyle headingStyle = TextStyle(
  inherit: false,
  fontFamily: 'Roboto',
  color: accentText,
  fontSize: 20.0,
  fontWeight: FontWeight.bold,
);

const double minimumReasonableWidth = 500.0;
const double indent = 20.0;
const double spacing = 8.0;

const Duration animationDuration = Duration(milliseconds: 150);

const TextStyle bold = TextStyle(fontWeight: FontWeight.bold);
const TextStyle italic = TextStyle(fontStyle: FontStyle.italic);

const double teamListElevation = 3.0;
const ShapeBorder teamListCardShape = BeveledRectangleBorder(
  borderRadius: BorderRadius.all(
    Radius.circular(4.0),
  ),
);

const String css = '''
table { border-collapse: collapse; border: hidden; }
th, td { border: solid thin; padding: 0.25em; text-align: left; }
h1 { margin: 0 0 0.25rem 0; }
h2 { margin: 1rem 0 0.5rem 0; }
h3 { margin: 0 0 0.5rem 0; }
p { margin: 0 0 1rem 0; }
li:not([value]) { list-style-type: disc; }
blockquote { margin: 2em 0 0.5em 0; }
h2 + blockquote, h3 + blockquote { margin-top: 0; }
''';

const String currentHelp = 'Event On-Call Support # 603-206-2412';
