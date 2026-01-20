# 🐍 Python Sensor Server Setup Guide

This guide helps you set up the Python backend server that bridges Arduino sensors to Supabase.

IMPORTANT:
- Only use this guide if you want Arduino to POST to the Python/Flask endpoint `/api/sensor/reading`.
- If you are NOT running the Python server, do NOT point Arduino to it.
- The recommended setup is Arduino → Supabase directly using `ARDUINO_SENSOR_CODE_FIXED.ino`.

## 📋 Prerequisites

- Python 3.8+ installed ([python.org](https://www.python.org))
- Supabase credentials (from `lib/config/app_config.dart`)
- Arduino code updated with server IP

---

## 🚀 Quick Start (3 minutes)

### Step 1: Install Python Dependencies

```bash
# Navigate to project directory
cd c:\Users\HP\swai_dashboard

# Install required packages
pip install flask python-dotenv supabase
```

### Step 2: Find Your Computer's IP Address

**Windows (PowerShell):**
```powershell
ipconfig
```

Look for `IPv4 Address` under your WiFi adapter. Example: `192.168.1.50`

**macOS/Linux:**
```bash
ifconfig
```

### Step 3: Update Arduino Code

Edit `ARDUINO_SENSOR_CODE_FIXED.ino` (or your own sketch) and replace your server URL:
```cpp
const char* serverUrl = "http://YOUR_COMPUTER_IP:5000/api/sensor/reading";
```

With your actual IP (e.g.):
```cpp
const char* serverUrl = "http://192.168.1.50:5000/api/sensor/reading";
```

### Step 4: Run the Server

```bash
python sensor_server.py
```

**Expected Output:**
```
============================================================
🌊 SWAI Dashboard - Sensor Server
============================================================
✓ Supabase connected
✓ Server starting on http://0.0.0.0:5000
✓ Arduino endpoint: http://YOUR_IP:5000/api/sensor/reading
✓ Health check: http://localhost:5000/health
============================================================
```

✅ **Server is running!** Keep this terminal open.

---

## 🧪 Testing the Server

### Test 1: Health Check (Browser)

Open in your browser:
```
http://localhost:5000/health
```

**Expected Response:**
```json
{"status": "running", "timestamp": "2025-12-08T10:30:45.123456"}
```

### Test 2: Send Test Data (PowerShell)

```powershell
# Test sensor data endpoint
$body = @{
    "pH" = 7.2
    "temp" = 28.5
    "tds" = 250
    "timestamp" = "1702046000"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:5000/api/sensor/reading" `
    -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body $body
```

**Expected Response:**
```json
{
    "status": "success",
    "message": "Data received and stored",
    "id": "abc-123-def",
    "alert": {
        "is_critical": false,
        "is_warning": false,
        "message": "All readings normal"
    }
}
```

### Test 3: Get Latest Reading

```
http://localhost:5000/api/readings/latest
```

### Test 4: View Statistics

```
http://localhost:5000/api/statistics
```

---

## 📊 Available Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/api/sensor/reading` | POST | Receive sensor data from Arduino |
| `/api/readings/latest` | GET | Get latest reading |
| `/api/readings/history` | GET | Get last 50 readings |
| `/api/thresholds` | GET | Get water quality thresholds |
| `/api/statistics` | GET | Get 24-hour statistics |

---

## ⚙️ Configuration

### Supabase Credentials

Edit `sensor_server.py` lines 17-19:

```python
SUPABASE_URL = "https://jrybjofyxppwicvgflpz.supabase.co"
SUPABASE_KEY = "sb_secret_tdP1pQNqoDS5mXHmz_CF-w_orfeERyT"
```

Get these from `lib/config/app_config.dart`

### Water Quality Thresholds

Edit `sensor_server.py` lines 22-28 to match your requirements:

```python
THRESHOLDS = {
    'pH': {'min': 6.5, 'max': 8.5, 'criticalMin': 5.0, 'criticalMax': 10.0},
    'temp': {'min': 25.0, 'max': 30.0, 'criticalMin': 10.0, 'criticalMax': 45.0},
    'tds': {'min': 100.0, 'max': 500.0, 'criticalMin': 0.0, 'criticalMax': 1500.0},
}
```

---

## 🔧 Troubleshooting

### Error: "ModuleNotFoundError: No module named 'flask'"

```bash
pip install flask python-dotenv supabase
```

### Error: "Connection refused" when Arduino connects

**Check:**
1. ✅ Python server is running (terminal shows output)
2. ✅ Arduino has correct IP address (run `ipconfig`)
3. ✅ Arduino and computer on same WiFi network
4. ✅ Firewall not blocking port 5000

**Allow port 5000 in Windows Firewall:**
```powershell
# PowerShell as Administrator
New-NetFirewallRule -DisplayName "Flask" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5000
```

### Error: "Supabase connection failed"

```bash
# Check if URL and KEY are correct
# From lib/config/app_config.dart:
# - supabaseUrl = "https://jrybjofyxppwicvgflpz.supabase.co"
# - supabaseKey = "sb_secret_tdP1pQNqoDS5mXHmz_CF-w_orfeERyT"
```

### Arduino shows "Connection failed"

Check Arduino Serial Monitor:
```
✗ Error Code: -1   // Network error
✗ Error Code: 404  // Wrong endpoint
✗ Error Code: 500  // Server error
```

---

## 📈 Data Flow

```
Arduino (ESP32)
    ↓ (WiFi - JSON POST)
Python Server (:5000)
    ↓ (Validate & Check Thresholds)
Supabase Database
    ↓ (Real-time subscription)
Flutter App (Dashboard)
```

---

## 🚀 Running in Production

For long-running deployments:

### Option A: Using PM2 (Node.js-based process manager)
```bash
# Install PM2
npm install -g pm2

# Start server
pm2 start sensor_server.py --name "swai-sensor" --interpreter python

# Auto-start on reboot
pm2 startup
pm2 save
```

### Option B: Using Windows Task Scheduler
1. Open Task Scheduler
2. Create Basic Task
3. Trigger: At startup
4. Action: Run program `python sensor_server.py`

### Option C: Docker

Create `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY sensor_server.py .
COPY requirements.txt .

RUN pip install -r requirements.txt

CMD ["python", "sensor_server.py"]
```

Build and run:
```bash
docker build -t swai-sensor-server .
docker run -p 5000:5000 swai-sensor-server
```

---

## 🔐 Security Notes

⚠️ **For production:**
1. Never commit Supabase keys to GitHub
2. Use environment variables:
   ```python
   from os import getenv
   SUPABASE_KEY = getenv('SUPABASE_KEY')
   ```
3. Add API key authentication to `/api/sensor/reading`
4. Use HTTPS instead of HTTP
5. Implement rate limiting

---

## 📚 Next Steps

1. ✅ Run `python sensor_server.py`
2. ✅ Upload Arduino code to ESP32
3. ✅ Watch data flow to Supabase
4. ✅ View in Flutter app dashboard
5. ✅ Test alert notifications

---

**Need help?** Check the Arduino Serial Monitor for connection logs or the Python console for error messages.
