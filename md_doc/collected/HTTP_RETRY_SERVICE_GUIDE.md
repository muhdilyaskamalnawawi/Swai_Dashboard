# HTTP Retry Service - Usage Guide

## Overview
`HttpRetryService` provides automatic retry logic with exponential backoff for HTTP requests. It handles network failures gracefully and retries failed requests automatically.

## Features
- ✅ Automatic retries with exponential backoff
- ✅ Configurable retry attempts (default: 3)
- ✅ Request timeout protection (10 seconds)
- ✅ Detailed logging for debugging
- ✅ Server error (5xx) detection and retry
- ✅ Network timeout handling

## Configuration
```dart
maxRetries = 3              // Maximum retry attempts
initialDelay = 500ms        // Initial delay between retries
backoffMultiplier = 2.0     // Delay multiplier (500ms, 1s, 2s, 4s...)
requestTimeout = 10s        // Individual request timeout
```

## Usage Examples

### 1. Basic GET Request
Replace standard `http.get()` with `HttpRetryService.get()`:

**Before:**
```dart
import 'package:http/http.dart' as http;

final response = await http.get(
  Uri.parse('https://api.example.com/data'),
  headers: {'Content-Type': 'application/json'},
);
```

**After:**
```dart
import 'package:http/http.dart' as http;
import '../services/http_retry_service.dart';

final response = await HttpRetryService.get(
  Uri.parse('https://api.example.com/data'),
  headers: {'Content-Type': 'application/json'},
);
```

### 2. Basic POST Request
Replace standard `http.post()` with `HttpRetryService.post()`:

**Before:**
```dart
final response = await http.post(
  Uri.parse('https://api.example.com/submit'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'key': 'value'}),
);
```

**After:**
```dart
final response = await HttpRetryService.post(
  Uri.parse('https://api.example.com/submit'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'key': 'value'}),
);
```

### 3. Custom Retry Configuration
Override default retry settings:

```dart
// Retry 5 times instead of 3
final response = await HttpRetryService.get(
  Uri.parse('https://api.example.com/data'),
  retries: 5,
);

// Custom initial delay
final response = await HttpRetryService.get(
  Uri.parse('https://api.example.com/data'),
  delay: Duration(seconds: 1), // Start with 1 second delay
);
```

## Integration in Your Project

### Update API Service (if you have one)
If you have `lib/services/api_service.dart`:

```dart
import 'package:http/http.dart' as http;
import '../services/http_retry_service.dart';

class ApiService {
  static const String baseUrl = 'https://your-backend.com/api';

  static Future<Map<String, dynamic>> fetchData() async {
    final response = await HttpRetryService.get(
      Uri.parse('$baseUrl/sensor-data'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }

  static Future<void> postReading(Map<String, dynamic> data) async {
    final response = await HttpRetryService.post(
      Uri.parse('$baseUrl/readings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to post reading');
    }
  }
}
```

### Update Gemini Service (Optional)
If Gemini API calls fail due to network issues:

```dart
// In lib/services/gemini_service.dart
import '../services/http_retry_service.dart';

class GeminiService {
  // If you're making custom HTTP calls to Gemini API
  static Future<String> makeCustomRequest(String prompt) async {
    final response = await HttpRetryService.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1/...'),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': AppConfig.geminiApiKey,
      },
      body: jsonEncode({'prompt': prompt}),
    );

    return jsonDecode(response.body)['text'];
  }
}
```

### Update Supabase Service (if making raw HTTP calls)
If you're making raw HTTP requests to Supabase instead of using the SDK:

```dart
// In lib/services/supabase_service.dart
import '../services/http_retry_service.dart';

Future<List<SensorReading>> fetchReadingsViaHttp() async {
  final response = await HttpRetryService.get(
    Uri.parse('${AppConfig.supabaseUrl}/rest/v1/sensor_readings'),
    headers: {
      'apikey': AppConfig.supabaseKey,
      'Authorization': 'Bearer ${AppConfig.supabaseKey}',
    },
  );

  final List<dynamic> data = jsonDecode(response.body);
  return data.map((json) => SensorReading.fromJson(json)).toList();
}
```

## Retry Behavior

### What Gets Retried
- ✅ Network timeouts
- ✅ Connection failures
- ✅ Server errors (HTTP 500-599)
- ❌ Client errors (HTTP 400-499) - NOT retried
- ❌ Successful responses (HTTP 200-299) - Return immediately

### Retry Schedule
```
Attempt 1: Immediate
Attempt 2: 500ms delay (0.5s)
Attempt 3: 1000ms delay (1s)
Attempt 4: 2000ms delay (2s)
```

## Error Handling

```dart
try {
  final response = await HttpRetryService.get(
    Uri.parse('https://api.example.com/data'),
  );
  
  if (response.statusCode == 200) {
    // Success
    final data = jsonDecode(response.body);
  } else {
    // Non-2xx response after retries
    print('Request failed: ${response.statusCode}');
  }
} on TimeoutException {
  // All retries timed out
  print('Request timed out after all retries');
} catch (e) {
  // Other network errors after all retries
  print('Network error: $e');
}
```

## Logging Output Example

```
🔄 GET https://api.example.com/data (attempt 1/3)
❌ Network error: SocketException: Failed host lookup
🔄 GET https://api.example.com/data (attempt 2/3)
⏱️ Timeout, retrying...
🔄 GET https://api.example.com/data (attempt 3/3)
✅ Success: 200
```

## Performance Considerations

1. **Total Time**: Max ~13 seconds for 3 retries (10s timeout × 3 + delays)
2. **Battery Impact**: Retries consume more battery - use wisely
3. **API Quotas**: Each retry counts toward API rate limits
4. **User Experience**: Show loading indicators during retries

## When to Use

✅ **Good Use Cases:**
- External API calls (Gemini, weather, etc.)
- Backend server requests
- File downloads
- Infrequent network requests

❌ **Avoid Using For:**
- Real-time Supabase streams (built-in retry)
- Frequent polling (use exponential backoff separately)
- Critical user actions requiring immediate feedback
- Large file uploads (may timeout)

## Testing

Test retry logic with mock server errors:

```dart
// Test in your debug console
import '../services/http_retry_service.dart';

void testRetry() async {
  try {
    // This will retry 3 times
    final response = await HttpRetryService.get(
      Uri.parse('https://httpstat.us/500'), // Always returns 500
    );
    print('Response: ${response.statusCode}');
  } catch (e) {
    print('Failed after retries: $e');
  }
}
```

## Summary

**To integrate HttpRetryService:**
1. ✅ File already created: `lib/services/http_retry_service.dart`
2. Replace `http.get()` → `HttpRetryService.get()`
3. Replace `http.post()` → `HttpRetryService.post()`
4. Test with network issues to verify retry behavior
5. Monitor logs to see retry attempts

No additional dependencies needed - uses standard `http` package already in your project!
