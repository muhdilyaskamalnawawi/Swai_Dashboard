# Node-RED & Backend Integration Guide

## Quick Start Integration

### Option 1: Direct Node-RED to Supabase

This Node-RED flow automatically saves sensor data to Supabase:

```json
[
  {
    "id": "sensor_input",
    "type": "http in",
    "url": "/api/water-quality",
    "method": "post",
    "name": "Sensor Data Input"
  },
  {
    "id": "parse_payload",
    "type": "json",
    "action": "obj",
    "property": "payload"
  },
  {
    "id": "add_timestamp",
    "type": "function",
    "func": "msg.payload.timestamp = new Date().toISOString();\nreturn msg;",
    "outputs": 1
  },
  {
    "id": "supabase_insert",
    "type": "http request",
    "method": "POST",
    "url": "https://YOUR_PROJECT.supabase.co/rest/v1/sensor_readings",
    "headers": {
      "apikey": "YOUR_ANON_KEY",
      "Authorization": "Bearer YOUR_ANON_KEY",
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    }
  },
  {
    "id": "response",
    "type": "http response",
    "statusCode": 200
  }
]
```

### Option 2: REST API Endpoint for App

Update your `lib/services/api_service.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';

class ApiService {
  final String baseUrl = 'http://YOUR_NODE_RED_IP:1880/api';

  Future<SensorReading> fetchLatestReading() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/water-quality/latest'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SensorReading.fromJson(json);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ API Error: $e');
      rethrow;
    }
  }

  Future<List<SensorReading>> fetchHistory({int days = 7}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/water-quality/history?days=$days'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        return json
            .map((e) => SensorReading.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch history');
      }
    } catch (e) {
      print('❌ API Error: $e');
      return [];
    }
  }

  Future<void> sendAlert(SensorReading reading, String message) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/water-quality/alert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'timestamp': reading.timestamp.toIso8601String(),
          'pH': reading.pH,
          'temp': reading.temp,
          'tds': reading.tds,
          'message': message,
        }),
      );
    } catch (e) {
      print('❌ Alert send failed: $e');
    }
  }
}
```

## Node-RED Flow Templates

### Template 1: Sensor Data Collection & Storage

```
Sensor Hardware (MQTT/Serial)
  ↓
[MQTT In] - Topic: sensors/water/#
  ↓
[Function] - Parse and validate
  ↓
[Parallel]
  ├→ [Supabase Insert] → Database
  ├→ [Call ML API] → Get prediction
  └→ [Call Gemini API] → Get recommendation
  ↓
[Combine Results]
  ↓
[Update Supabase] - Add prediction/recommendation
  ↓
[Check Thresholds]
  ├→ [If Critical] → [Send Alert]
  └→ [If Safe] → [Log]
```

### Template 2: Historical Data Aggregation

```
[Schedule Node] - Hourly/Daily
  ↓
[Query Supabase] - Get readings from past period
  ↓
[Calculate Statistics]
  - Average
  - Min/Max
  - Trend
  ↓
[Store Aggregated Data]
  ↓
[Send Report to App]
```

## Environment Setup

### Docker Compose (Node-RED + Supabase)

```yaml
version: '3'
services:
  node-red:
    image: nodered/node-red:latest
    ports:
      - "1880:1880"
    volumes:
      - node_red_data:/data
    environment:
      - TZ=UTC
    networks:
      - water-network

  supabase:
    # Use hosted Supabase instead
    # https://supabase.com/dashboard

networks:
  water-network:
    driver: bridge

volumes:
  node_red_data:
```

## Sensor Data Format

Your sensors should send data in this JSON format:

```json
{
  "pH": 7.2,
  "temp": 28.5,
  "tds": 250,
  "timestamp": "2024-12-03T10:30:00Z"
}
```

### MQTT Topic Structure (Optional)
```
sensors/water/pH → 7.2
sensors/water/temp → 28.5
sensors/water/tds → 250
```

## Pushing to Supabase from Node-RED

### HTTP Request Configuration

**URL:**
```
https://YOUR_PROJECT.supabase.co/rest/v1/sensor_readings
```

**Method:** POST

**Headers:**
```
apikey: YOUR_ANON_KEY
Authorization: Bearer YOUR_ANON_KEY
Content-Type: application/json
Prefer: return=representation
```

**Body (Raw JSON):**
```json
{
  "pH": 7.2,
  "temp": 28.5,
  "tds": 250,
  "prediction": "Safe",
  "recommendation": "Continue monitoring",
  "timestamp": "2024-12-03T10:30:00Z"
}
```

## Error Handling in Node-RED

```json
[
  {
    "id": "error_handler",
    "type": "catch",
    "scope": ["supabase_insert"],
    "uncaught": false,
    "name": "Error Handler"
  },
  {
    "id": "retry_logic",
    "type": "function",
    "func": "if (!msg.payload.retries) msg.payload.retries = 0;\nif (msg.payload.retries < 3) {\n  msg.payload.retries++;\n  msg.delay = 5000 * msg.payload.retries;\n  return msg;\n} else {\n  node.warn('Max retries exceeded');\n  return null;\n}"
  },
  {
    "id": "delay_retry",
    "type": "delay",
    "timeoutType": "msg"
  }
]
```

## Integration Checklist

- [ ] Node-RED server running and accessible
- [ ] Supabase project created with `sensor_readings` table
- [ ] API endpoints configured correctly
- [ ] Environment variables set (URLs, API keys)
- [ ] CORS enabled if using cross-origin requests
- [ ] Sensor data format validated
- [ ] Error handling implemented
- [ ] Rate limiting configured (if needed)
- [ ] Authentication/authorization set up
- [ ] Testing completed with sample data

## Testing the Integration

### Test 1: Direct API Call
```bash
curl -X POST http://YOUR_NODE_RED_IP:1880/api/water-quality \
  -H "Content-Type: application/json" \
  -d '{
    "pH": 7.2,
    "temp": 28.5,
    "tds": 250
  }'
```

### Test 2: Supabase Insert
```bash
curl -X POST https://YOUR_PROJECT.supabase.co/rest/v1/sensor_readings \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "pH": 7.2,
    "temp": 28.5,
    "tds": 250,
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'
```

### Test 3: App Integration
```dart
// Run in your app
void testIntegration() async {
  final apiService = ApiService();
  
  try {
    final reading = await apiService.fetchLatestReading();
    print('✓ Latest reading: $reading');
  } catch (e) {
    print('✗ Error: $e');
  }
}
```

## Production Deployment

### Security Best Practices

1. **API Keys**: Store in environment variables, never commit to git
2. **HTTPS**: Use HTTPS in production (Node-RED behind nginx)
3. **Rate Limiting**: Implement rate limits on endpoints
4. **Authentication**: Add JWT tokens for secure communication
5. **Input Validation**: Validate all sensor data before storage

### Example Nginx Configuration

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location /api/ {
        proxy_pass http://localhost:1880/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection refused" | Check Node-RED is running: `pm2 status` |
| "401 Unauthorized" | Verify Supabase API key is correct |
| "CORS error" | Add CORS headers in Node-RED HTTP response |
| "Data not appearing" | Check Supabase dashboard for rows |
| "Slow updates" | Reduce update frequency or batch requests |

---

For more help, refer to:
- [Supabase Docs](https://supabase.com/docs)
- [Node-RED Docs](https://nodered.org/docs/)
- [Flutter HTTP Docs](https://pub.dev/packages/http)
