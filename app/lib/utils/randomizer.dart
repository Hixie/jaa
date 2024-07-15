import 'dart:math' as math;

const List<(int, String)> _letterDistribution = [
  (80, 'A'),
  (16, 'B'),
  (30, 'C'),
  (44, 'D'),
  (120, 'E'),
  (25, 'F'),
  (17, 'G'),
  (64, 'H'),
  (80, 'I'),
  (4, 'J'),
  (8, 'K'),
  (40, 'L'),
  (30, 'M'),
  (80, 'N'),
  (80, 'O'),
  (17, 'P'),
  (5, 'Q'),
  (62, 'R'),
  (80, 'S'),
  (90, 'T'),
  (34, 'U'),
  (12, 'V'),
  (20, 'W'),
  (4, 'X'),
  (20, 'Y'),
  (2, 'Z'),
];

class Randomizer {
  Randomizer(this.random) {
    for (final (int f, String s) in _letterDistribution) {
      for (int index = 0; index < f; index += 1) {
        _letterBag.add(s);
      }
    }
  }

  final math.Random random;

  final List<String> _letterBag = [];

  void _addWord(StringBuffer buffer) {
    final int count = random.nextInt(5) + random.nextInt(5) + random.nextInt(5) + 1;
    for (int index = 0; index < count; index += 1) {
      buffer.write(_letterBag[random.nextInt(_letterBag.length)]);
    }
  }

  String generatePhrase([int? count]) {
    StringBuffer buffer = StringBuffer();
    count ??= random.nextInt(2) + random.nextInt(2) + random.nextInt(2) + 1;
    for (int index = 0; index < count; index += 1) {
      if (index > 0) {
        buffer.write(' ');
      }
      _addWord(buffer);
    }
    return buffer.toString();
  }

  T randomItem<T>(List<T> values) {
    return values[random.nextInt(values.length)];
  }
}
