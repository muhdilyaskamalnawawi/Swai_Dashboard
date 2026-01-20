# ✅ SWAI Dashboard - Server Ready!

## 🎉 Status: ONLINE

Your Python sensor server is **now running** and ready to receive data from Arduino!

NOTE:
- This page applies ONLY if you are using the Python/Flask sensor server.
- If you cancelled/stopped the Python server and your Arduino is still posting to
    `http://<YOUR_IP>:<PORT>/api/sensor/reading`, then Supabase will not receive new rows.
- For the recommended setup (no Python server), use `ARDUINO_SENSOR_CODE_FIXED.ino`
    which posts directly to Supabase REST.

---

## 📊 Server Information

| Item | Value |
|------|-------|
| **Status** | ✅ Running |
| **Server IP** | `192.168.8.48` |
| **Port** | `8000` |
| **API Endpoint** | `http://192.168.8.48:8000/api/sensor/reading` |
| **Health Check** | `http://localhost:8000/health` |
| **Database** | Supabase (connected) |
| **Platform** | Windows 10/11 |

---

## 📱 Arduino Configuration

Your Arduino code is already updated with the correct server address:

```cpp
// Only when using the Python/Flask server:
const char* serverUrl = "http://192.168.8.48:8000/api/sensor/reading";
```

**No changes needed!** Just upload this code to your ESP32.

---

## 🚀 Next Steps

### Step 1: Ensure Server Keeps Running
- ✅ Server is running in a terminal window
- **Important:** Keep the terminal open while testing
- The server will reload automatically when code changes

### Step 2: Test the Server
A test script is available:
```bash
python test_sensor_server.py
```

**Expected output:**
```
============================================================
  SWAI Dashboard - Sensor Server Test Suite
============================================================
✓ PASS - Health Check
✓ PASS - Send Normal Data
✓ PASS - Send Critical Data
✓ PASS - Get Latest Reading
✓ PASS - Get Thresholds
✓ PASS - Get History
✓ PASS - Get Statistics

Results: 7/7 tests passed
✓ All tests passed! Server is ready.
```

### Step 3: Upload Arduino Code
1. Open `ARDUINO_SENSOR_CODE_FIXED.ino` in Arduino IDE
2. Update WiFi credentials:
   ```cpp
   const char* ssid = "YOUR_WIFI_SSID";
   const char* password = "YOUR_WIFI_PASSWORD";
   ```
3. Select ESP32 board
4. Upload to device

### Step 4: Verify Data Flow
Once Arduino is connected:
1. Open Serial Monitor → Should see:
   ```
   Reading #1 | pH: 7.2 | TDS: 250 ppm | Temp: 28.5°C
   ✓ Response Code: 201
   ```

2. Check Supabase Dashboard → New rows in `sensor_readings` table

3. Open Flutter App → Dashboard updates in real-time ✨

---

## 📚 Available API Endpoints

### 1. Health Check
```
GET http://192.168.8.48:8000/health
```
Response: `{"status": "running", "timestamp": "..."}`

### 2. Send Sensor Data (Arduino uses this)
```
POST http://192.168.8.48:8000/api/sensor/reading
Content-Type: application/json

{
  "pH": 7.2,
  "temp": 28.5,
  "tds": 250,
  "timestamp": "1234567890"
}
```
Response: `{"status": "success", "id": "...", "alert": {...}}`

### 3. Get Latest Reading
```
GET http://192.168.8.48:8000/api/readings/latest
```

### 4. Get History (Last 50)
```
GET http://192.168.8.48:8000/api/readings/history
```

### 5. Get Thresholds
```
GET http://192.168.8.48:8000/api/thresholds
```

### 6. Get Statistics (24 hours)
```
GET http://192.168.8.48:8000/api/statistics
```

---

## ⚙️ Server Features

✅ **Data Validation**
- Checks required fields (pH, temp, TDS)
- Validates numeric values
- Returns error if data is invalid

✅ **Alert Detection**
- Critical alerts (outside safety limits)
- Warning alerts (outside optimal range)
- Custom thresholds (editable in code)

✅ **Database Integration**
- Inserts data into Supabase
- Stores timestamp and alert status
- Provides real-time updates to app

✅ **Logging**
- All requests logged to console
- Error tracking
- Debug information available

✅ **CORS Support**
- Allows requests from Flutter app
- API accessible from anywhere on network

---

## 🧪 Testing Without Arduino

Want to test before uploading to Arduino? Use PowerShell:

```powershell
# Test with normal data
$body = @{
    "pH" = 7.2
    "temp" = 28.5
    "tds" = 250
    "timestamp" = "1702046000"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:8000/api/sensor/reading" `
    -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body $body
```

---

## 🔧 Troubleshooting

### ❌ Server won't start
**Error:** "Address already in use"
```bash
# Kill process on port 8000
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

### ❌ Arduino can't connect
**Check:**
1. ✅ Server is running (check terminal)
2. ✅ Arduino and computer on same WiFi network
3. ✅ IP address is `192.168.8.48` (not 192.168.1.x)
4. ✅ Port is `8000`
5. ✅ WiFi credentials in Arduino code are correct

### ❌ Data not reaching Supabase
**Check:**
1. ✅ Supabase credentials in `sensor_server.py` are correct
2. ✅ Table `sensor_readings` exists in Supabase
3. ✅ Check Supabase dashboard for errors

### ❌ Firewall blocking
Windows Firewall may allow port 8000 by default, but if blocked:
```powershell
# Run as Administrator
netsh advfirewall firewall add rule name="Flask 8000" dir=in action=allow protocol=tcp localport=8000
```

---

## 📈 Data Flow

```
Arduino (sends JSON)
    ↓ WiFi POST request
http://192.168.8.48:8000/api/sensor/reading
    ↓ Flask validates
sensor_server.py (checks thresholds)
    ↓ Inserts record
Supabase Database
    ↓ Real-time subscription
Flutter App Dashboard
    ↓ Updates gauges & charts
User sees live water quality! 🎉
```

---

## 🔐 Security Notes

⚠️ **Current Setup:**
- Development mode enabled (debug=True)
- No API key authentication on endpoints
- Supabase key visible in code

✅ **For Production:**
1. Disable debug mode
2. Add API key authentication
3. Use environment variables for secrets
4. Enable HTTPS
5. Use a production WSGI server (Gunicorn)

---

## 📞 Quick Reference

| Task | Command |
|------|---------|
| Start server | `python sensor_server.py` |
| Test endpoints | `python test_sensor_server.py` |
| Stop server | `Ctrl+C` in terminal |
| View logs | Check terminal output |
| Check health | `http://localhost:8000/health` |

---

## 🎯 Summary

Your SWAI Dashboard ecosystem is almost complete:

- ✅ Flutter App (ready to receive data)
- ✅ Python Backend Server (running)
- ✅ Supabase Database (connected)
- ⏳ Arduino Sensor Code (waiting to upload)
- ⏳ Physical Hardware (sensors not connected yet)

**Next action:** Upload Arduino code and watch the magic happen! 🚀

---

**Generated:** December 8, 2025  
**Server:** SWAI Dashboard Sensor Server v1.0
