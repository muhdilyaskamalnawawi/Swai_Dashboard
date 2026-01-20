# Arduino Water Quality Sensor Setup Guide

## Overview
This guide helps you set up your Arduino with pH, TDS, and Temperature sensors to send data to your SWAI Dashboard.

---

## Hardware Components

### Required Parts
| Component | Quantity | Notes |
|-----------|----------|-------|
| ESP32 or Arduino Uno | 1 | ESP32 recommended (has WiFi) |
| pH Sensor Module | 1 | Analog output, 0-5V or 0-3.3V |
| DS18B20 Temperature Sensor | 1 | 1-Wire protocol |
| TDS Sensor Module | 1 | Analog output, 0-5V or 0-3.3V |
| 4.7kΩ Resistor | 1 | Pull-up for DS18B20 (required) |
| USB Cable | 1 | For programming and power |
| Breadboard + Jumper Wires | 1 set | For connections |
| WiFi Module (optional) | 1 | For Arduino Uno (ESP32 has built-in) |

---

## Pin Connections

### ESP32 Board
```
pH Sensor    → GPIO 35 (Analog Input A7)
TDS Sensor   → GPIO 34 (Analog Input A6)
DS18B20      → GPIO 2  (Digital Input, with 4.7kΩ pull-up to 3.3V)
Built-in LED → GPIO 2  (for status feedback)
```

### Arduino Uno (if using WiFi Shield)
```
pH Sensor    → A0 (Analog Input)
TDS Sensor   → A1 (Analog Input)
DS18B20      → D2 (Digital Input, with 4.7kΩ pull-up to 5V)
WiFi TX      → D1
WiFi RX      → D0
```

---

## Wiring Diagram

### DS18B20 Temperature Sensor
```
DS18B20 Pins (looking at flat side):
1 (GND)     → GND
2 (DQ)      → GPIO 2 + 4.7kΩ resistor to 3.3V
3 (VCC)     → 3.3V
```

### pH Sensor Module
```
VCC   → 3.3V or 5V
GND   → GND
A0    → GPIO 35 (ESP32) or A0 (Arduino)
```

### TDS Sensor Module
```
VCC   → 3.3V or 5V
GND   → GND
A0    → GPIO 34 (ESP32) or A1 (Arduino)
```

---

## Installation Steps

### Step 1: Install Arduino IDE
1. Download from https://www.arduino.cc/en/software
2. Install for your OS (Windows, Mac, Linux)

### Step 2: Install ESP32 Board (if using ESP32)
1. Open Arduino IDE
2. Go to **File → Preferences**
3. Add to "Additional Boards Manager URLs":
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. Go to **Tools → Board → Boards Manager**
5. Search for "esp32" and install

### Step 3: Install Required Libraries
1. Go to **Sketch → Include Library → Manage Libraries**
2. Install these libraries:
   - **DallasTemperature** (by Miles Burton)
   - **OneWire** (by Paul Stoffregen)
   - **ArduinoJson** (by Benoit Blanchon)
   - **WiFi** (built-in for ESP32)

### Step 4: Configure the Code
Open `ARDUINO_SENSOR_CODE_FIXED.ino` and update:

```cpp
// Line 24-25: Your WiFi credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Supabase REST endpoint (recommended: send directly to Supabase)
// Example:
// const char* supabaseUrl = "https://<YOUR_PROJECT>.supabase.co/rest/v1/sensor_readings";
// const char* supabaseAnonKey = "<YOUR_ANON_KEY>";

// IMPORTANT:
// If you previously configured the Arduino to POST to a Python/Flask endpoint like
//   http://<YOUR_IP>:5000/api/sensor/reading
// and you are NOT running that server anymore, your data will NOT reach Supabase.
// Use the direct Supabase configuration in ARDUINO_SENSOR_CODE_FIXED.ino instead.
```

### Step 5: Select Board and Port
1. **Tools → Board**: Select your board (ESP32 Dev Module or Arduino Uno)
2. **Tools → Port**: Select your COM port (e.g., COM3, /dev/ttyUSB0)
3. **Tools → Upload Speed**: 115200

### Step 6: Upload Code
1. Click **Sketch → Upload** (or Ctrl+U)
2. Wait for "Done uploading"
3. Open **Tools → Serial Monitor** (9600 baud)
4. You should see sensor readings!

---

## Calibration

### pH Sensor Calibration
1. Get two calibration buffer solutions (pH 7.0 and pH 4.0 or 10.0)
2. Place probe in pH 7.0 buffer
3. Read raw value from Serial Monitor
4. Calculate: `PH_OFFSET = 7.0 - readValue`
5. Update line 42 in code: `const float PH_OFFSET = YOUR_VALUE;`

### TDS Sensor Calibration
1. Get a standard solution (e.g., 1413 ppm or 500 ppm)
2. Place probe in solution
3. Read voltage and calculate: `TDS_CONSTANT = desiredPPM / voltage`
4. Update line 46 in code: `const float TDS_CONSTANT = YOUR_VALUE;`

### Temperature Sensor
- DS18B20 is factory calibrated
- No adjustment usually needed
- Verify in ice water (0°C) or boiling water (100°C)

---

## Backend API Integration

### Option 1: Node-RED (Recommended)
Create a Node-RED flow to receive data:

```json
HTTP In (POST) → Parse JSON → Insert into Supabase → HTTP Response
```

### Option 2: Direct Supabase (Advanced)
Update your backend URL to point to Supabase:
```cpp
const char* serverUrl = "https://YOUR_PROJECT.supabase.co/rest/v1/sensor_readings";
```

Add authorization header in code:
```cpp
http.addHeader("Authorization", "Bearer YOUR_ANON_KEY");
```

---

## Testing

### Serial Monitor Output (Expected)
```
=== SWAI Dashboard Arduino Sensor Code ===
Initializing...
✓ Temperature sensor initialized
Connecting to WiFi: YOUR_WIFI
...............
✓ WiFi connected!
IP Address: 192.168.1.100
✓ Setup complete!
Reading #1 | pH: 7.23 | TDS: 245 ppm | Temp: 28.50°C
Sending: {"pH":7.23,"temp":28.50,"tds":245,"timestamp":"1234567"}
✓ Response Code: 200
Response: {"success":true}
```

### Common Issues

**Problem**: Serial monitor shows garbage text
- **Solution**: Check baud rate (set to 115200)

**Problem**: pH values out of range (> 14 or < 0)
- **Solution**: Recalibrate sensor or adjust PH_OFFSET

**Problem**: Temperature reads -127°C
- **Solution**: Check DS18B20 wiring and 4.7kΩ pull-up resistor

**Problem**: WiFi won't connect
- **Solution**: Verify SSID/password, check WiFi signal strength

**Problem**: Data not sending to backend
- **Solution**: Check serverUrl is correct, verify backend is running

---

## Data Format Sent to Backend

Your Arduino sends this JSON to the backend every 30 seconds:

```json
{
  "pH": 7.23,
  "temp": 28.50,
  "tds": 245,
  "timestamp": "1234567890"
}
```

This data is then stored in Supabase and appears in your Flutter app dashboard!

---

## Advanced Configuration

### Change Read Intervals
```cpp
// Line 56: Read sensors every 10 seconds instead of 5
const unsigned long READ_INTERVAL = 10000;

// Line 57: Send data every 60 seconds instead of 30
const unsigned long SEND_INTERVAL = 60000;
```

### Add More Sensors
1. Add new pin constant:
   ```cpp
   const int TURBIDITY_PIN = 33;
   ```
2. Create read function:
   ```cpp
   void readTurbidity() {
     int raw = analogRead(TURBIDITY_PIN);
     turbidity = raw * VOLTAGE_FACTOR;
   }
   ```
3. Add to JSON payload:
   ```cpp
   doc["turbidity"] = turbidity;
   ```

---

## Power Management

### For Autonomous Deployment
- Use 5V/12V power supply instead of USB
- Add 5V → 3.3V voltage regulator for ESP32
- Use capacitors for stability (100µF + 10µF)
- Consider deep sleep mode for battery operation

```cpp
// Deep sleep every 5 minutes
void sleep() {
  esp_deep_sleep(5 * 60 * 1000000); // 5 minutes in microseconds
}
```

---

## Troubleshooting Checklist

- [ ] All sensors connected to correct pins
- [ ] 4.7kΩ pull-up resistor on DS18B20 data line
- [ ] WiFi SSID and password correct
- [ ] Backend API URL is accessible
- [ ] Arduino IDE shows "Done uploading"
- [ ] Serial monitor shows sensor readings
- [ ] Baud rate set to 115200
- [ ] Board and port correctly selected
- [ ] All libraries installed

---

## Next Steps

1. ✅ Upload code to Arduino
2. ✅ Verify sensor readings in Serial Monitor
3. ✅ Connect to WiFi
4. ✅ Test data sending to backend
5. ✅ Deploy in fish pond
6. ✅ View real-time data in Flutter app!

---

## Support

For issues:
1. Check Serial Monitor output
2. Review calibration values
3. Verify wiring connections
4. Test with known sensor values
5. Check backend API logs

Happy monitoring! 🐟💧
