#!/usr/bin/env dart
// Export FTC team names from the FIRST FTC Events API.
//
// Output (written to STDOUT):
//   - One team name per line, in arrival order, de-duplicated.
//   - The name is read only from the API field "nameShort".
//   - No team number, no CSV, no quoting or escaping; the name is printed
//     verbatim. Nothing else is written to STDOUT.
//   - Names are streamed as each page arrives, not buffered to the end, so
//     whatever has been emitted survives a SIGINT/SIGTERM or fatal error.
//
// Season probing:
//   - Fetch kStartSeason, then kStartSeason-1, ... until the first absent season
//     is detected from the first page request, or a valid first-page response
//     contains no teams, or kMinSeason is reached.
//   - Then check kCheckForwardSeason (set it to 0 to disable).
//
// Safety:
//   - Only /v2.0/{season}/teams is called.
//   - Event, rankings, schedule, match, and award endpoints are never called.
//
// Credentials are read ONLY from environment variables (see usernameEnv /
// tokenEnv). There are no command-line arguments. Diagnostics go to STDERR.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ============================== CONFIGURATION ==============================
// Edit these constants to tune behavior. There are no command-line arguments.

/// Environment variables the credentials are read from.
const String usernameEnv = 'FTC_API_USERNAME';
const String tokenEnv = 'FTC_API_TOKEN';

/// Backward season probing starts here and counts down to [kMinSeason].
const int kStartSeason = 2025;

/// Season checked after the backward probe. Set to 0 to disable.
const int kCheckForwardSeason = 2026;

/// Safety floor for backward probing.
const int kMinSeason = 1900;

/// Concurrent page requests per season. Use <= 1 for serial/gentlest mode.
const int kWorkers = 4;

/// Attempts for transient errors (must be >= 1).
const int kRetries = 4;

/// Base retry backoff in seconds (must be >= 0).
const double kBackoff = 1.0;
// ===========================================================================

const String apiBase = 'https://ftc-api.firstinspires.org/v2.0';
const Set<int> _transientStatuses = {408, 409, 425, 429, 500, 502, 503, 504};

// Team names already emitted, used for de-duplication. Dart runs in a single
// isolate with cooperative scheduling, so no lock is needed: emitting is
// synchronous (no await), so it runs to completion even when pages are fetched
// concurrently.
final Set<String> _seenNames = {};

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------
class ApiError implements Exception {
  final String message;
  final int? status;
  final String? url;
  ApiError(this.message, {this.status, this.url});
  @override
  String toString() => message;
}

/// Raised when the first page of a probed season indicates the season is absent.
class SeasonAbsentError extends ApiError {
  SeasonAbsentError(super.message, {super.status, super.url});
}

/// Raised after retryable HTTP/network failures have exhausted retries.
class TransientApiError extends ApiError {
  TransientApiError(super.message, {super.status, super.url});
}

void log(String message) => stderr.writeln(message);

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------
String authHeader(String username, String token) =>
    'Basic ${base64.encode(utf8.encode('$username:$token'))}';

String apiUrl(String path, [Map<String, Object>? params]) {
  final base = apiBase.replaceAll(RegExp(r'/+$'), '');
  final tail = path.replaceAll(RegExp(r'^/+'), '');
  var url = '$base/$tail';
  if (params != null && params.isNotEmpty) {
    url += '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}='
        '${Uri.encodeQueryComponent('${e.value}')}').join('&')}';
  }
  return url;
}

Future<List<int>> _collectBytes(HttpClientResponse resp) async {
  final out = <int>[];
  await for (final chunk in resp) {
    out.addAll(chunk);
  }
  return out;
}

Future<void> _sleep(double seconds) =>
    Future<void>.delayed(Duration(microseconds: (seconds * 1e6).round()));

Future<Map<String, dynamic>> requestJson(
  String url,
  String auth, {
  required bool absentOk,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 60);
  try {
    for (var attempt = 1; attempt <= kRetries; attempt++) {
      try {
        final req = await client.getUrl(Uri.parse(url));
        req.headers.set(HttpHeaders.acceptHeader, 'application/json');
        req.headers.set(HttpHeaders.authorizationHeader, auth);
        req.headers.set(
          HttpHeaders.userAgentHeader,
          'ftc-team-name-export-strict/4.0',
        );
        final resp = await req.close().timeout(const Duration(seconds: 60));
        final bytes = await _collectBytes(resp);
        final status = resp.statusCode;

        if (status >= 200 && status < 300) {
          final Object? data;
          try {
            data = jsonDecode(utf8.decode(bytes));
          } on FormatException catch (e) {
            throw ApiError('Invalid JSON from $url: $e', url: url);
          }
          if (data is! Map<String, dynamic>) {
            throw ApiError('Expected JSON object from $url', url: url);
          }
          return data;
        }

        final body = utf8.decode(bytes, allowMalformed: true);
        final snippet = body.length > 1000 ? body.substring(0, 1000) : body;

        if ((status == 400 || status == 404) && absentOk) {
          throw SeasonAbsentError(
            'HTTP $status for $url\n$snippet',
            status: status,
            url: url,
          );
        }
        if (status == 401 || status == 403) {
          throw ApiError(
            'Authentication/authorization failed: HTTP $status for $url\n'
            '$snippet',
            status: status,
            url: url,
          );
        }
        if (_transientStatuses.contains(status) && attempt < kRetries) {
          final retryAfter = resp.headers.value(HttpHeaders.retryAfterHeader);
          final delay = retryAfter != null
              ? (double.tryParse(retryAfter) ?? kBackoff * attempt)
              : kBackoff * attempt;
          log('Retrying after HTTP $status: $url');
          await _sleep(delay);
          continue;
        }
        if (_transientStatuses.contains(status)) {
          throw TransientApiError(
            'HTTP $status after $kRetries attempts for $url\n$snippet',
            status: status,
            url: url,
          );
        }
        throw ApiError(
          'HTTP $status for $url\n$snippet',
          status: status,
          url: url,
        );
      } on TimeoutException catch (e) {
        if (attempt < kRetries) {
          log('Retrying after network error: $url');
          await _sleep(kBackoff * attempt);
          continue;
        }
        throw TransientApiError(
          'Network error after $kRetries attempts for $url: $e',
          url: url,
        );
      } on IOException catch (e) {
        if (attempt < kRetries) {
          log('Retrying after network error: $url');
          await _sleep(kBackoff * attempt);
          continue;
        }
        throw TransientApiError(
          'Network error after $kRetries attempts for $url: $e',
          url: url,
        );
      }
    }
    throw TransientApiError('Request failed after retries: $url', url: url);
  } finally {
    client.close(force: true);
  }
}

// ---------------------------------------------------------------------------
// Strict field extraction
// ---------------------------------------------------------------------------
String _typeName(Object? v) {
  if (v == null) return 'NoneType';
  if (v is bool) return 'bool';
  if (v is int) return 'int';
  if (v is double) return 'float';
  if (v is String) return 'str';
  if (v is List) return 'list';
  if (v is Map) return 'dict';
  return v.runtimeType.toString();
}

int exactIntField(Map<String, dynamic> obj, String key, String context) {
  if (!obj.containsKey(key)) {
    throw ApiError("Missing required field '$key' in $context");
  }
  final value = obj[key];
  if (value is bool) {
    throw ApiError("Field '$key' in $context is boolean, expected integer");
  }
  if (value is int) return value;
  throw ApiError(
    "Field '$key' in $context has type ${_typeName(value)}, expected integer",
  );
}

String exactStrField(Map<String, dynamic> obj, String key, String context) {
  if (!obj.containsKey(key)) {
    throw ApiError("Missing required field '$key' in $context");
  }
  final value = obj[key];
  if (value is String) return value;
  throw ApiError(
    "Field '$key' in $context has type ${_typeName(value)}, expected string",
  );
}

List<Map<String, dynamic>> teamsFromResponse(
  Map<String, dynamic> data,
  String path,
) {
  if (!data.containsKey('teams')) {
    final keys = data.keys.toList()..sort();
    final repr = '[${keys.map((k) => "'$k'").join(', ')}]';
    throw ApiError(
      "Missing required response field 'teams' from $path; keys were $repr",
    );
  }
  final value = data['teams'];
  if (value is! List) {
    throw ApiError(
      "Response field 'teams' from $path has type ${_typeName(value)}, "
      'expected list',
    );
  }
  final teams = <Map<String, dynamic>>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! Map<String, dynamic>) {
      throw ApiError(
        "Item $index in response field 'teams' from $path has type "
        '${_typeName(item)}, expected object',
      );
    }
    teams.add(item);
  }
  return teams;
}

(int, int) pageMetadata(
  Map<String, dynamic> data,
  String path,
  int requestedPage,
  int itemCount,
) {
  final pageCurrent = exactIntField(data, 'pageCurrent', path);
  final pageTotal = exactIntField(data, 'pageTotal', path);

  // A season with no teams is a valid terminal condition for season probing.
  // Accept it only for the first requested page and only when the response list
  // is actually empty; otherwise, keep pagination validation strict.
  if (pageTotal == 0) {
    if (requestedPage == 1 &&
        itemCount == 0 &&
        (pageCurrent == 0 || pageCurrent == 1)) {
      return (pageCurrent, pageTotal);
    }
    throw ApiError(
      'Response from $path reported invalid empty pagination: '
      'pageCurrent=$pageCurrent pageTotal=$pageTotal item_count=$itemCount',
    );
  }

  if (pageCurrent != requestedPage) {
    throw ApiError(
      'Response from $path reported pageCurrent=$pageCurrent for requested '
      'page=$requestedPage',
    );
  }
  if (pageTotal < 1) {
    throw ApiError('Response from $path reported invalid pageTotal=$pageTotal');
  }
  if (pageCurrent < 1 || pageCurrent > pageTotal) {
    throw ApiError(
      'Response from $path reported invalid pageCurrent=$pageCurrent '
      'pageTotal=$pageTotal',
    );
  }
  return (pageCurrent, pageTotal);
}

// ---------------------------------------------------------------------------
// Fetching and streaming output
// ---------------------------------------------------------------------------
Future<(List<Map<String, dynamic>>, int, int)> getPage(
  String auth,
  int season,
  int page, {
  required bool absentOk,
}) async {
  final path = '$season/teams';
  final url = apiUrl(path, {'page': page});
  final data = await requestJson(url, auth, absentOk: absentOk);
  final teams = teamsFromResponse(data, path);
  final (pageCurrent, pageTotal) = pageMetadata(data, path, page, teams.length);
  return (teams, pageCurrent, pageTotal);
}

/// Prints [name] to stdout if it has not been emitted before. Returns whether
/// it was newly emitted. Synchronous (no await), so concurrent callers cannot
/// interleave a partial line.
bool _emit(String name) {
  if (!_seenNames.add(name)) return false;
  stdout.writeln(name);
  return true;
}

/// Emits each new team name from one page's [teams]. Returns
/// (teamRowsSeen, newNamesEmitted).
(int, int) emitTeams(int season, int page, List<Map<String, dynamic>> teams) {
  var newNames = 0;
  for (var index = 0; index < teams.length; index++) {
    final context = 'season $season page $page item $index';
    final name = exactStrField(teams[index], 'nameShort', context);
    if (_emit(name)) newNames += 1;
  }
  return (teams.length, newNames);
}

/// Runs [fn] over [items] with at most [concurrency] outstanding at a time,
/// returning results in input order. The first error propagates after the
/// already-started tasks settle (mirrors ThreadPoolExecutor shutdown).
Future<List<R>> _mapPool<T, R>(
  List<T> items,
  int concurrency,
  Future<R> Function(T) fn,
) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next;
      if (i >= items.length) break;
      next = i + 1;
      results[i] = await fn(items[i]);
    }
  }

  final n = concurrency < items.length ? concurrency : items.length;
  await Future.wait([for (var w = 0; w < n; w++) worker()]);
  return [for (final r in results) r as R];
}

/// Fetches every page for [season], streaming each new team name to stdout as
/// the page arrives. Returns (teamRowsSeen, newNamesEmitted) for the season.
Future<(int, int)> fetchSeason(String auth, int season) async {
  final (firstTeams, _, pageTotal) =
      await getPage(auth, season, 1, absentOk: true);

  if (firstTeams.isEmpty || pageTotal == 0) return (0, 0);

  // stdout is write-through, so emitting (a synchronous writeln per new name)
  // streams each page out as it arrives. No explicit flush: a flush left
  // pending would make a concurrent worker's writeln throw, and exit() drains
  // stdout regardless.
  var (rows, newNames) = emitTeams(season, 1, firstTeams);
  if (pageTotal == 1) return (rows, newNames);

  final pages = [for (var p = 2; p <= pageTotal; p++) p];

  Future<(int, int)> fetchAndEmit(int page) async {
    final (teams, _, _) = await getPage(auth, season, page, absentOk: false);
    return emitTeams(season, page, teams);
  }

  if (kWorkers <= 1) {
    for (final page in pages) {
      final (r, n) = await fetchAndEmit(page);
      rows += r;
      newNames += n;
    }
    return (rows, newNames);
  }

  final counts = await _mapPool<int, (int, int)>(pages, kWorkers, fetchAndEmit);
  for (final (r, n) in counts) {
    rows += r;
    newNames += n;
  }
  return (rows, newNames);
}

void _installSignalHandlers() {
  ProcessSignal.sigint.watch().listen((_) {
    log('Received SIGINT. Exiting; emitted names are already on stdout.');
    exit(130);
  });
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) {
      log('Received SIGTERM. Exiting; emitted names are already on stdout.');
      exit(143);
    });
  }
}

Future<bool> probeAndAdd(String auth, int season) async {
  log('Fetching season $season teams...');
  final (int, int) result;
  try {
    result = await fetchSeason(auth, season);
  } on SeasonAbsentError catch (exc) {
    log('Season $season appears absent; stopping that probe. $exc');
    return false;
  }
  final (rows, newNames) = result;

  if (rows == 0) {
    log('Season $season returned a valid empty teams list; stopping that '
        'probe.');
    return false;
  }

  log('Season $season: $rows team rows, $newNames new unique names.');
  return true;
}

Future<void> main() async {
  final env = Platform.environment;
  final username = env[usernameEnv];
  final token = env[tokenEnv];
  if (username == null || username.isEmpty) {
    log('ERROR: Set $usernameEnv.');
    exit(2);
  }
  if (token == null || token.isEmpty) {
    log('ERROR: Set $tokenEnv.');
    exit(2);
  }

  _installSignalHandlers();
  final auth = authHeader(username, token);

  try {
    var season = kStartSeason;
    while (season >= kMinSeason) {
      final ok = await probeAndAdd(auth, season);
      if (!ok) break;
      season -= 1;
    }

    if (kCheckForwardSeason != 0) {
      await probeAndAdd(auth, kCheckForwardSeason);
    }

    exit(0);
  } catch (exc) {
    log('ERROR: $exc');
    exit(1);
  }
}
