import 'dart:convert';
import 'dart:io';

// ============================ CONFIGURATION ============================
// Edit these constants to tune generation. There are no CLI arguments.

/// Maximum length of any alias.
const int kMaxLength = 8;

/// A word (or boundary affix) occurring in >= this fraction of the sample
/// names is treated as boilerplate and elided.
const double kCommonThreshold = 0.10;

/// Enable camelCase splitting when >= this fraction of tokens look camelCase.
const double kCamelThreshold = 0.05;

/// Bake a commonness value only for words occurring in at least this many
/// names; rarer words are implicitly maximally distinctive.
const int kMinDocFreq = 2;

/// Longest boundary affix considered in monolithic mode.
const int kMaxAffix = 4;
// =======================================================================

// Markers bounding the embeddable engine below. The needle literals are built
// by string concatenation so they do NOT appear verbatim here — only the real
// marker comment lines match, letting the script locate the engine in its own
// source.
const _beginMark =
    '// ===ALIAS-ENGINE '
    'BEGIN===';
const _endMark =
    '// ===ALIAS-ENGINE '
    'END===';

void main() {
  try {
    // Representative names: one per line on stdin.
    final names = <String>[];
    String? line;
    while ((line = stdin.readLineSync(encoding: utf8)) != null) {
      final t = line!.trim();
      if (t.isNotEmpty) names.add(t);
    }

    // Read this script's own source and lift out the engine to embed.
    final self = File(Platform.script.toFilePath()).readAsStringSync();
    final b = self.indexOf(_beginMark), e = self.indexOf(_endMark);
    if (b < 0 || e < 0 || e <= b) {
      throw const FormatException('engine markers not found in script source');
    }
    final engine = self.substring(b + _beginMark.length, e).trim();

    stdout.write(_librarySource(_analyze(names), engine));
  } catch (err) {
    stderr.writeln('team_aliaser: $err');
    exit(1);
  }
}

// ----------------------- analysis + emission ---------------------------
// (Used only by the generator; not embedded in the output.)

class _Profile {
  final int nameCount;
  final int wordNames;
  final int monoNames;
  final bool splitCamelCase;
  final Map<String, double> commonness;
  final Set<String> commonPrefixes;
  final Set<String> commonSuffixes;
  _Profile(
    this.nameCount,
    this.wordNames,
    this.monoNames,
    this.splitCamelCase,
    this.commonness,
    this.commonPrefixes,
    this.commonSuffixes,
  );

  List<String> get elided =>
      (commonness.entries
          .where((x) => x.value >= kCommonThreshold)
          .map((x) => x.key)
          .toList()
        ..sort());
}

_Profile _analyze(List<String> names) {
  // Classify each name the way the engine will at alias time, then calibrate
  // each mode from the names that actually belong to it.
  final wordNames = <String>[], monoNames = <String>[];
  for (final name in names) {
    (_isWordSegmented(name) ? wordNames : monoNames).add(name);
  }

  // camelCase splitting: enabled when enough segmented tokens look camelCase.
  var camelTokens = 0, totalTokens = 0;
  for (final name in wordNames) {
    for (final t in wordTexts(name)) {
      totalTokens++;
      if (_camelRe.hasMatch(t)) camelTokens++;
    }
  }
  final splitCamelCase =
      totalTokens > 0 && camelTokens / totalTokens >= kCamelThreshold;

  // Word commonness: document frequency over the segmented names, as a fraction
  // of those names (so a monolithic-heavy corpus doesn't dilute it).
  final df = <String, int>{};
  for (final name in wordNames) {
    final seen = <String>{};
    for (final w in wordTexts(name)) {
      seen.add(normalizeToken(w, fold: true, lower: true));
    }
    for (final w in seen) {
      df[w] = (df[w] ?? 0) + 1;
    }
  }
  final nWord = wordNames.length;
  final commonness = <String, double>{
    for (final x in df.entries)
      if (x.value >= kMinDocFreq) x.key: x.value / nWord,
  };

  // Monolithic boundary affixes: over the monolithic names, as a fraction of
  // those names.
  final commonPrefixes = <String>{}, commonSuffixes = <String>{};
  final nMono = monoNames.length;
  if (nMono > 1) {
    final pre = <String, int>{}, suf = <String, int>{};
    for (final name in monoNames) {
      final s = wordTexts(name).join();
      if (s.isEmpty) continue;
      for (var k = 1; k <= kMaxAffix && k <= s.length; k++) {
        final p = s.substring(0, k), q = s.substring(s.length - k);
        pre[p] = (pre[p] ?? 0) + 1;
        suf[q] = (suf[q] ?? 0) + 1;
      }
    }
    final thr = kCommonThreshold * nMono;
    for (final x in pre.entries) {
      if (x.value >= thr) commonPrefixes.add(x.key);
    }
    for (final x in suf.entries) {
      if (x.value >= thr) commonSuffixes.add(x.key);
    }
  }

  return _Profile(
    names.length,
    nWord,
    nMono,
    splitCamelCase,
    commonness,
    commonPrefixes,
    commonSuffixes,
  );
}

String _setLiteral(Set<String> s) => s.isEmpty
    ? '<String>{}'
    : '<String>{${(s.toList()..sort()).map((e) => "'$e'").join(', ')}}';

String _mapLiteral(Map<String, double> m) {
  if (m.isEmpty) return '<String, double>{}';
  final entries = (m.keys.toList()..sort())
      .map((k) => "'$k': ${m[k]!.toStringAsFixed(4)}")
      .join(', ');
  return '<String, double>{$entries}';
}

String _librarySource(_Profile p, String engine) {
  final header = StringBuffer()
    ..writeln('// GENERATED FILE - do not edit by hand.')
    ..writeln(
      '// Self-contained: depends only on dart:core. Copy this file in,',
    )
    ..writeln('// then call generateAliases(List<(int, String)> teams).')
    ..writeln(
      '// Built from ${p.nameCount} names (${p.wordNames} word-segmented, '
      '${p.monoNames} monolithic); maxLength=$kMaxLength, '
      'commonThreshold=$kCommonThreshold. Segmentation is decided per name.',
    )
    ..writeln(
      '// elided (>= threshold): '
      '${p.elided.isEmpty ? "(none)" : p.elided.join(", ")}',
    );

  final config = StringBuffer()
    ..writeln('const AliasConfig _config = AliasConfig(')
    ..writeln('  maxLength: $kMaxLength,')
    ..writeln('  commonThreshold: $kCommonThreshold,')
    ..writeln('  splitCamelCase: ${p.splitCamelCase},')
    ..writeln('  commonness: ${_mapLiteral(p.commonness)},')
    ..writeln('  commonPrefixes: ${_setLiteral(p.commonPrefixes)},')
    ..writeln('  commonSuffixes: ${_setLiteral(p.commonSuffixes)},')
    ..writeln('  maxAffix: $kMaxAffix,')
    ..writeln(');');

  const wrapper =
      '/// Computes a unique, representative alias for every (number, name) pair.\n'
      'Map<int, String> generateAliases(List<(int, String)> teams) =>\n'
      '    generateAliasesWith(teams, _config);\n';

  return '$header\n$engine\n$config\n$wrapper';
}

// ===ALIAS-ENGINE BEGIN===
// Self-contained alias engine (depends only on dart:core).
//
// An alias is a *verbatim fragment of the original name*: it never changes the
// case of any text and never introduces punctuation absent from the name. It is
// built by keeping the distinctive words and dropping the overly-common ones
// (by training frequency) and, across a list, the words shared with other
// teams, bounded to a maximum length. Aliases are never longer than the name.

final RegExp _wordRe = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
final RegExp _camelRe = RegExp(r'(?<=[\p{Ll}0-9])(?=\p{Lu})', unicode: true);

/// Scripts that do not put spaces between words. A lone token written in one of
/// these has no internal word boundaries to exploit, so it is aliased
/// monolithically (stripping common boundary affixes) rather than by word.
final RegExp _noSpaceRe = RegExp(
  r'[\p{sc=Han}\p{sc=Hiragana}\p{sc=Katakana}\p{sc=Thai}'
  r'\p{sc=Lao}\p{sc=Khmer}\p{sc=Myanmar}]',
  unicode: true,
);

/// Whether [name] is word-segmented (vs monolithic). Decided per name, not per
/// corpus, so mixed sets work: two or more tokens means segmented; a single
/// token is monolithic only when written in a no-space script.
bool _isWordSegmented(String name) {
  final ws = wordTexts(name);
  if (ws.length != 1) return true;
  return !_noSpaceRe.hasMatch(ws.first);
}

/// Verbatim content words (maximal letter/mark/number runs). camelCase is NOT
/// split here, so "RoboHawks" stays one word with its exact casing.
List<String> wordTexts(String name) =>
    _wordRe.allMatches(name).map((m) => m.group(0)!).toList();

/// Accent folding used for FREQUENCY MATCHING only (never for emitted text).
const Map<String, String> kFold = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ĕ': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ĩ': 'i',
  'ī': 'i',
  'ĭ': 'i',
  'į': 'i',
  'ı': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ŏ': 'o',
  'ő': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ũ': 'u',
  'ū': 'u',
  'ŭ': 'u',
  'ů': 'u',
  'ű': 'u',
  'ų': 'u',
  'ç': 'c',
  'ć': 'c',
  'ĉ': 'c',
  'ċ': 'c',
  'č': 'c',
  'ñ': 'n',
  'ń': 'n',
  'ņ': 'n',
  'ň': 'n',
  'ý': 'y',
  'ÿ': 'y',
  'ŷ': 'y',
  'ś': 's',
  'ŝ': 's',
  'ş': 's',
  'š': 's',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
  'ĝ': 'g',
  'ğ': 'g',
  'ġ': 'g',
  'ģ': 'g',
  'ĺ': 'l',
  'ļ': 'l',
  'ľ': 'l',
  'ŀ': 'l',
  'ł': 'l',
  'ŕ': 'r',
  'ŗ': 'r',
  'ř': 'r',
  'ţ': 't',
  'ť': 't',
  'ŧ': 't',
  'ď': 'd',
  'đ': 'd',
  'ŵ': 'w',
  'ĥ': 'h',
  'ħ': 'h',
  'ĵ': 'j',
  'ķ': 'k',
  'æ': 'ae',
  'œ': 'oe',
  'ß': 'ss',
  'ð': 'd',
  'þ': 'th',
};

/// Lowercases + (optionally) ASCII-folds a token to a frequency-match key.
String normalizeToken(String token, {required bool fold, required bool lower}) {
  final text = lower ? token.toLowerCase() : token;
  final sb = StringBuffer();
  for (final r in text.runes) {
    final ch = String.fromCharCode(r);
    final folded = fold ? kFold[ch] : null;
    sb.write(folded ?? ch);
  }
  return sb.toString();
}

/// Everything needed to build aliases, baked by the generator.
class AliasConfig {
  final int maxLength;
  final double commonThreshold;
  final bool splitCamelCase;
  final Map<String, double> commonness; // normalized word -> fraction of names
  final Set<String> commonPrefixes; // monolithic mode
  final Set<String> commonSuffixes; // monolithic mode
  final int maxAffix;

  const AliasConfig({
    required this.maxLength,
    required this.commonThreshold,
    required this.splitCamelCase,
    required this.commonness,
    required this.commonPrefixes,
    required this.commonSuffixes,
    required this.maxAffix,
  });
}

class _Word {
  final String text;
  final int start;
  final int end;
  const _Word(this.text, this.start, this.end);
}

List<_Word> _wordsOf(String name) => _wordRe
    .allMatches(name)
    .map((m) => _Word(m.group(0)!, m.start, m.end))
    .toList();

String _matchKey(String word) => normalizeToken(word, fold: true, lower: true);

double _commonness(String word, AliasConfig c) =>
    c.commonness[_matchKey(word)] ?? 0.0;

/// Teams in the current list sharing [word] (a word or sub-word); supplied by
/// [generateAliasesWith]. 0 when there is no list context.
int _shareOf(String word, int Function(String)? share) =>
    share?.call(word) ?? 0;

/// Order for which fragment to *keep*: prefer the one shared by fewer teams
/// (more uniquely identifying), then the rarer one in the corpus. Negative
/// means [a] is the better keep.
int _cmpKeep(String a, String b, AliasConfig c, int Function(String)? share) {
  final sa = _shareOf(a, share), sb = _shareOf(b, share);
  if (sa != sb) return sa.compareTo(sb);
  return _commonness(a, c).compareTo(_commonness(b, c));
}

List<String> _subWords(String word, AliasConfig c) {
  if (!c.splitCamelCase) return [word];
  final parts = word.split(_camelRe).where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? [word] : parts;
}

String _truncate(String s, int max) =>
    s.length <= max ? s : s.substring(0, max);

/// Joins the kept words verbatim, using a single ORIGINAL separator (the one
/// immediately preceding each kept word) between them. The result is a
/// subsequence of [name], so no new punctuation, no case change, never longer.
String _assemble(String name, List<_Word> words, List<int> keptSorted) {
  final sb = StringBuffer();
  for (var i = 0; i < keptSorted.length; i++) {
    final ci = keptSorted[i];
    if (i > 0) sb.write(name.substring(words[ci - 1].end, words[ci].start));
    sb.write(words[ci].text);
  }
  return sb.toString();
}

String _stripAffixes(String s, AliasConfig c) {
  for (var k = c.maxAffix; k >= 1; k--) {
    if (k < s.length && c.commonPrefixes.contains(s.substring(0, k))) {
      s = s.substring(k);
      break;
    }
  }
  for (var k = c.maxAffix; k >= 1; k--) {
    if (k < s.length && c.commonSuffixes.contains(s.substring(s.length - k))) {
      s = s.substring(0, s.length - k);
      break;
    }
  }
  return s;
}

/// Reduces [indices] to fit maxLength. Drops the least uniquely-identifying
/// word first (most shared across the list, then most common); if a single word
/// is still too long, prefers a fitting camelCase sub-word, else truncates.
String _fit(
  String name,
  List<_Word> words,
  List<int> indices,
  AliasConfig c,
  int Function(String)? share,
) {
  final kept = [...indices]..sort();
  while (kept.length > 1 && _assemble(name, words, kept).length > c.maxLength) {
    var worst = kept.first;
    for (final i in kept) {
      final cmp = _cmpKeep(words[i].text, words[worst].text, c, share);
      if (cmp > 0 || (cmp == 0 && i > worst)) worst = i;
    }
    kept.remove(worst);
  }
  final s = _assemble(name, words, kept);
  if (s.length <= c.maxLength) return s;
  if (kept.length == 1) {
    final subs =
        _subWords(
            words[kept.first].text,
            c,
          ).where((w) => w.length <= c.maxLength).toList()
          ..sort((a, b) => _cmpKeep(a, b, c, share));
    if (subs.isNotEmpty) return subs.first;
  }
  return _truncate(s, c.maxLength);
}

/// Ordered, deduplicated candidate aliases for [name], all <= maxLength and all
/// verbatim fragments of [name]. Most-preferred first. With [share] supplied,
/// the preferred alias keeps only each name's least-shared (most identifying)
/// words, so conflicting names diverge on their distinguishing parts even when
/// the whole name would fit.
List<String> aliasCandidates(
  String name,
  AliasConfig c, {
  int Function(String)? share,
}) {
  final words = _wordsOf(name);
  final out = <String>[];
  void add(String s) {
    if (s.isEmpty || s.length > c.maxLength || out.contains(s)) return;
    out.add(s);
  }

  if (words.isEmpty) return out;

  if (!_isWordSegmented(name)) {
    final tok = words.map((w) => w.text).join();
    add(_truncate(_stripAffixes(tok, c), c.maxLength));
    add(_truncate(tok, c.maxLength));
    return out;
  }

  final all = List<int>.generate(words.length, (i) => i);

  // 1) Drop corpus-boilerplate words (unless that removes everything).
  var core = all
      .where((i) => _commonness(words[i].text, c) < c.commonThreshold)
      .toList();
  if (core.isEmpty) core = [...all];

  // 2) Keep only the least-shared words within the list (the distinguishing
  //    ones), unless that removes everything.
  if (share != null) {
    var minShare = -1;
    for (final i in core) {
      final s = share(words[i].text);
      if (minShare < 0 || s < minShare) minShare = s;
    }
    final distinguishing = core
        .where((i) => share(words[i].text) == minShare)
        .toList();
    if (distinguishing.isNotEmpty) core = distinguishing;
  }

  add(_fit(name, words, core, c, share)); // distinguishing core
  add(_fit(name, words, all, c, share)); // whole name (collision fallback)

  final byKeep = [...all]
    ..sort((a, b) {
      final cmp = _cmpKeep(words[a].text, words[b].text, c, share);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
  for (final i in byKeep) {
    add(words[i].text); // individual identifying words
  }
  final subs = [for (final i in byKeep) ..._subWords(words[i].text, c)]
    ..sort((a, b) => _cmpKeep(a, b, c, share));
  for (final s in subs) {
    add(s); // camelCase sub-words
  }
  add(_truncate(_assemble(name, words, all), c.maxLength));
  add(_truncate(words[byKeep.first].text, c.maxLength));
  return out;
}

/// Computes an alias for every (number, name) pair under [c].
///
/// Guarantees: every alias is unique across the list, <= maxLength, and a
/// verbatim fragment of its name (no case or punctuation changes). Where names
/// conflict, aliases are drawn from each name's distinguishing words — the ones
/// fewest other teams share — rather than collapsing onto a shared word.
/// Colliding teams otherwise diverge by keeping more of their names; only
/// genuinely indistinguishable names get a numeric suffix (the one case that
/// adds characters, kept within maxLength). Order-independent.
Map<int, String> generateAliasesWith(List<(int, String)> teams, AliasConfig c) {
  // How many teams share each word / sub-word (case- and accent-insensitive).
  final inputDf = <String, int>{};
  for (final (_, name) in teams) {
    final seen = <String>{};
    for (final w in wordTexts(name)) {
      seen.add(_matchKey(w));
      if (c.splitCamelCase) {
        for (final s in _subWords(w, c)) {
          seen.add(_matchKey(s));
        }
      }
    }
    for (final k in seen) {
      inputDf[k] = (inputDf[k] ?? 0) + 1;
    }
  }
  int share(String word) => inputDf[_matchKey(word)] ?? 0;

  final candidates = <int, List<String>>{};
  for (final (number, name) in teams) {
    final list = aliasCandidates(name, c, share: share);
    candidates[number] = list.isNotEmpty ? list : <String>['$number'];
  }

  final ordered = teams.map((t) => t.$1).toList()..sort();
  final used = <String>{};
  final result = <int, String>{};
  for (final number in ordered) {
    final list = candidates[number]!;
    String? chosen;
    for (final cand in list) {
      if (!used.contains(cand)) {
        chosen = cand;
        break;
      }
    }
    if (chosen == null) {
      final base = list.first;
      for (var k = 2; ; k++) {
        final suffix = '$k';
        final room = c.maxLength - suffix.length;
        final cand = '${room <= 0 ? '' : _truncate(base, room)}$suffix';
        if (!used.contains(cand)) {
          chosen = cand;
          break;
        }
      }
    }
    used.add(chosen);
    result[number] = chosen;
  }
  return result;
}

// ===ALIAS-ENGINE END===
