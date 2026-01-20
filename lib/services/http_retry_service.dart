// lib/services/http_retry_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// HTTP client with automatic retry logic using exponential backoff.
/// Handles network failures gracefully with retries, capped backoff, and jitter.
class HttpRetryService {
  // Configuration
  static const int maxRetries = 3;
  static const Duration initialDelay = Duration(milliseconds: 500);
  static const double backoffMultiplier = 2.0;
  static const Duration requestTimeout = Duration(seconds: 10);
  static const Duration maxBackoff = Duration(seconds: 8);

  /// Performs GET with retry logic.
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    int retries = maxRetries,
    Duration? delay,
  }) async {
    return _runWithRetry(
      () => http.get(url, headers: headers),
      context: 'GET $url',
      retries: retries,
      delay: delay,
    );
  }

  /// Performs POST with retry logic.
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    int retries = maxRetries,
    Duration? delay,
  }) async {
    return _runWithRetry(
      () => http.post(url, headers: headers, body: body, encoding: encoding),
      context: 'POST $url',
      retries: retries,
      delay: delay,
    );
  }

  /// Shared retry wrapper with exponential backoff and simple jitter.
  static Future<http.Response> _runWithRetry(
    Future<http.Response> Function() request, {
    required String context,
    int retries = maxRetries,
    Duration? delay,
  }) async {
    delay ??= initialDelay;
    final attempt = maxRetries - retries + 1;
    print('🔄 $context (attempt $attempt/$maxRetries)');

    try {
      final response = await request().timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Success: ${response.statusCode}');
        return response;
      }

      if (_shouldRetryStatus(response.statusCode) && retries > 0) {
        final nextDelay = _nextBackoff(delay);
        print(
            '⚠️ ${response.statusCode} -> retrying in ${nextDelay.inMilliseconds}ms');
        await Future.delayed(nextDelay);
        return _runWithRetry(
          request,
          context: context,
          retries: retries - 1,
          delay: nextDelay,
        );
      }

      return response;
    } on TimeoutException {
      if (retries > 0) {
        final nextDelay = _nextBackoff(delay);
        print('⏱️ Timeout -> retrying in ${nextDelay.inMilliseconds}ms');
        await Future.delayed(nextDelay);
        return _runWithRetry(
          request,
          context: context,
          retries: retries - 1,
          delay: nextDelay,
        );
      }
      rethrow;
    } catch (e) {
      if (retries > 0) {
        final nextDelay = _nextBackoff(delay);
        print(
            '❌ Network error: $e -> retrying in ${nextDelay.inMilliseconds}ms');
        await Future.delayed(nextDelay);
        return _runWithRetry(
          request,
          context: context,
          retries: retries - 1,
          delay: nextDelay,
        );
      }
      rethrow;
    }
  }

  static bool _shouldRetryStatus(int statusCode) {
    // Retry on server errors and transient client errors (429, 408)
    return statusCode >= 500 || statusCode == 429 || statusCode == 408;
  }

  /// Retry backoff calculation: 500ms, 1s, 2s, 4s... capped, plus light jitter.
  static Duration calculateBackoff(int failureCount) {
    final backoffMs = initialDelay.inMilliseconds *
        pow(backoffMultiplier, failureCount).toDouble();
    return Duration(
      milliseconds: min(backoffMs.round(), maxBackoff.inMilliseconds),
    );
  }

  static Duration _nextBackoff(Duration current) {
    final multiplied = current.inMilliseconds * backoffMultiplier;
    final capped = min(multiplied.round(), maxBackoff.inMilliseconds);
    // Add up to +/-10% jitter to avoid thundering herd
    final jitter = (Random().nextDouble() * 0.2 - 0.1) * capped;
    final withJitter =
        (capped + jitter).clamp(100, maxBackoff.inMilliseconds).round();
    return Duration(milliseconds: withJitter);
  }

  /// Backward-compatible helper for callers expecting a parsed JSON Map.
  /// Throws if the response body is not JSON.
  static Map<String, dynamic> decodeJsonObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object');
  }
}
