/*
  SWAI Dashboard - ESP32 -> Supabase (Clean Version)
  - Reads pH, TDS, Temperature
  - Uses NTP (UTC+8) to get real time
  - Sends JSON directly to Supabase REST (sensor_readings)
*/

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WiFiClient.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include "time.h"

// ==========================
// WiFi Configuration
// ==========================
const char* ssid = "Yaso";
const char* password = "alqolamun";

// Some networks hijack DNS and return 0.0.0.0 for blocked domains.
// Force public DNS servers to avoid that when possible.
IPAddress dns1(1, 1, 1, 1); // Cloudflare
IPAddress dns2(8, 8, 8, 8); // Google

// ==========================
// Supabase Configuration
// ==========================
const char* supabaseUrl = "https://jrybjofyxppwicvgflpz.supabase.co/rest/v1/sensor_readings";
const char* supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpyeWJqb2Z5eHBwd2ljdmdmbHB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2OTQ1NTcsImV4cCI6MjA4MDI3MDU1N30.z58mhtQfn1DGsAIpMSfj8rNH_69OJ2MS03LC84ZoKWY";
const char* supabaseHost = "jrybjofyxppwicvgflpz.supabase.co";
const uint16_t supabasePort = 443;

// ==========================
// NTP Time Settings (UTC+8)
// ==========================
// Try multiple NTP servers. Many networks block UDP/123 (NTP).
const char* ntpServer1 = "pool.ntp.org";
const char* ntpServer2 = "time.google.com";
const char* ntpServer3 = "time.cloudflare.com";
// Use UTC for storage. Supabase timestamps should be UTC.
const long  gmtOffset_sec = 0;
const int   daylightOffset_sec = 0;

// Timestamp fallback (when NTP is blocked/unavailable)
// We estimate UTC time using build time + uptime, then switch to true NTP time once available.
unsigned long g_bootMs = 0;
time_t g_bootEpochUtc = 0; // epoch seconds at boot (UTC)

int _monthFromStr(const char* mon) {
  if (strncmp(mon, "Jan", 3) == 0) return 1;
  if (strncmp(mon, "Feb", 3) == 0) return 2;
  if (strncmp(mon, "Mar", 3) == 0) return 3;
  if (strncmp(mon, "Apr", 3) == 0) return 4;
  if (strncmp(mon, "May", 3) == 0) return 5;
  if (strncmp(mon, "Jun", 3) == 0) return 6;
  if (strncmp(mon, "Jul", 3) == 0) return 7;
  if (strncmp(mon, "Aug", 3) == 0) return 8;
  if (strncmp(mon, "Sep", 3) == 0) return 9;
  if (strncmp(mon, "Oct", 3) == 0) return 10;
  if (strncmp(mon, "Nov", 3) == 0) return 11;
  if (strncmp(mon, "Dec", 3) == 0) return 12;
  return 1;
}

time_t _buildEpochUtc() {
  // __DATE__ example: "Jan 10 2026"
  // __TIME__ example: "12:34:56"
  const char* dateStr = __DATE__;
  const char* timeStr = __TIME__;

  char mon[4] = {0};
  mon[0] = dateStr[0];
  mon[1] = dateStr[1];
  mon[2] = dateStr[2];
  const int month = _monthFromStr(mon);

  const int day = atoi(dateStr + 4);
  const int year = atoi(dateStr + 7);

  const int hour = atoi(timeStr);
  const int minute = atoi(timeStr + 3);
  const int second = atoi(timeStr + 6);

  struct tm tmUtc;
  memset(&tmUtc, 0, sizeof(tmUtc));
  tmUtc.tm_year = year - 1900;
  tmUtc.tm_mon = month - 1;
  tmUtc.tm_mday = day;
  tmUtc.tm_hour = hour;
  tmUtc.tm_min = minute;
  tmUtc.tm_sec = second;

  // mktime treats struct tm as local time; we only need a monotonic-ish fallback.
  // For IoT dashboards this is sufficient until NTP succeeds.
  return mktime(&tmUtc);
}

bool _hasValidNtpTime() {
  // 1700000000 ~= 2023-11-14 UTC. Anything below is likely "unset" on ESP32.
  const time_t nowEpoch = time(nullptr);
  return nowEpoch > 1700000000;
}

// ==========================
// Pins
// ==========================
const int PH_PIN  = 35;
const int TDS_PIN = 34;
const int TEMP_PIN = 33;
const int LED_PIN  = 2;

// ==========================
// Calibration / Globals
// ==========================
// pH calibration
// Measured ~1.911V in pH 7.0 buffer, use that as neutral
const float PH_V_NEUTRAL = 1.911;
const float PH_SLOPE     = 0.059; // Theoretical slope (~59 mV per pH)
float PH_OFFSET          = 0.0;

// TDS calibration
// Adjusted for Malaysian standards (100-500 ppm for treated water)
// Previous TDS_K=3.1 gave 1000-1400 ppm, scaled down by ~5x
float TDS_K = 0.65;

// Temperature sensor
OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensors(&oneWire);

float g_ph = 0.0;
float g_tds = 0.0;
float g_temp = 0.0;
bool g_tdsValid = true;

unsigned long lastReadMs = 0;
unsigned long lastSendMs = 0;
const unsigned long READ_INTERVAL_MS = 5000;   // 5 seconds
const unsigned long SEND_INTERVAL_MS = 30000;  // 30 seconds

// ==========================
// Function Prototypes
// ==========================
void connectWiFi();
void initTime();
String getIsoTimestamp();
void diagnoseSupabaseConnectivity();
void readAllSensors();
void readPH();
void readTDS();
void readTemp();
void sendToSupabase();
void blinkSuccess();
void blinkError();

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("=== SWAI DASHBOARD - ESP32 -> Supabase ===");

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // ESP32 ADC configuration
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  tempSensors.begin();

  g_bootMs = millis();
  g_bootEpochUtc = _buildEpochUtc();

  connectWiFi();
  diagnoseSupabaseConnectivity();
  initTime();

  Serial.println("Setup complete. Starting monitoring...");
}

void diagnoseSupabaseConnectivity() {
  Serial.println("--- Connectivity diagnostic (Supabase) ---");

  IPAddress resolved;
  if (WiFi.hostByName(supabaseHost, resolved)) {
    Serial.print("DNS OK: ");
    Serial.print(supabaseHost);
    Serial.print(" -> ");
    Serial.println(resolved);
  } else {
    Serial.print("DNS FAILED for host: ");
    Serial.println(supabaseHost);
    Serial.println("Tip: Try different WiFi / hotspot or set custom DNS.");
    Serial.println("-----------------------------------------");
    return;
  }

  // 1) Plain TCP check to port 443
  WiFiClient tcp;
  Serial.print("TCP connect to ");
  Serial.print(supabaseHost);
  Serial.print(":");
  Serial.print(supabasePort);
  Serial.print(" ... ");
  if (tcp.connect(supabaseHost, supabasePort)) {
    Serial.println("OK");
    tcp.stop();
  } else {
    Serial.println("FAILED");
    Serial.println("Likely network blocks outbound 443 or requires a proxy/captive portal.");
    Serial.println("Try phone hotspot as a quick test.");
    Serial.println("-----------------------------------------");
    return;
  }

  // 2) TLS check (cert verification disabled for development)
  WiFiClientSecure tls;
  tls.setInsecure();
  Serial.print("TLS connect ... ");
  if (tls.connect(supabaseHost, supabasePort)) {
    Serial.println("OK");
    tls.stop();
  } else {
    Serial.println("FAILED");
    Serial.println("TLS handshake failed. Try updating ESP32 core, or use hotspot.");
  }

  Serial.println("-----------------------------------------");
}

void loop() {
  unsigned long now = millis();

  if (now - lastReadMs >= READ_INTERVAL_MS) {
    readAllSensors();
    lastReadMs = now;
  }

  if (now - lastSendMs >= SEND_INTERVAL_MS) {
    sendToSupabase();
    lastSendMs = now;
  }
}

// ==========================
// WiFi & Time
// ==========================
void connectWiFi() {
  Serial.printf("Connecting to WiFi: %s\n", ssid);

  WiFi.mode(WIFI_STA);
  // Keep DHCP but override DNS servers.
  WiFi.config(INADDR_NONE, INADDR_NONE, INADDR_NONE, dns1, dns2);

  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection failed");
    blinkError();
  }
}

void initTime() {
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer1, ntpServer2, ntpServer3);
  Serial.println("Syncing NTP time...");

  struct tm timeinfo;
  // Don't block startup for long: uploads do not depend on NTP (we have a timestamp fallback).
  int retries = 0;
  while (!getLocalTime(&timeinfo) && retries < 6) {
    Serial.print(".");
    delay(300);
    retries++;
  }

  if (retries < 6) {
    Serial.println("\nTime synced");
    // Align our boot epoch to real NTP time once available.
    const time_t nowEpoch = time(nullptr);
    if (nowEpoch > 0) {
      g_bootEpochUtc = nowEpoch - (millis() / 1000);
    }
  } else {
    Serial.println("\nFailed to sync time (will retry later)");
  }
}

String getIsoTimestamp() {
  // Prefer real NTP time when available.
  if (_hasValidNtpTime()) {
    time_t nowEpoch = time(nullptr);
    struct tm tmUtc;
    gmtime_r(&nowEpoch, &tmUtc);
    char buffer[25];
    strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &tmUtc);
    return String(buffer);
  }

  // Fallback: estimate using boot epoch + uptime.
  // This prevents "skip send" loops when NTP is blocked by the network.
  time_t estEpoch = g_bootEpochUtc + (millis() / 1000);
  struct tm tmUtc;
  gmtime_r(&estEpoch, &tmUtc);
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &tmUtc);
  return String(buffer);
}

// ==========================
// Sensor Reading
// ==========================
void readAllSensors() {
  readTemp();
  readPH();
  readTDS();

  Serial.println("------------------------------");
  Serial.printf(
    "pH: %.2f | Temp: %.2f C | TDS: %.0f ppm%s\n",
    g_ph,
    g_temp,
    g_tds,
    g_tdsValid ? "" : " (invalid sample)"
  );
  Serial.println("------------------------------");
}

void readTemp() {
  tempSensors.requestTemperatures();
  g_temp = tempSensors.getTempCByIndex(0);

  if (g_temp == DEVICE_DISCONNECTED_C) {
    Serial.println("Temp sensor error, using 25.0 C fallback");
    g_temp = 25.0;
  }
}

void readPH() {
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(PH_PIN);
    delay(10);
  }

  float raw = sum / 10.0;
  float voltage = raw * (3.3 / 4095.0);
  g_ph = 7.0 + ((PH_V_NEUTRAL - voltage) / PH_SLOPE);
  g_ph += PH_OFFSET;
  g_ph = constrain(g_ph, 0.0, 14.0);
}

void readTDS() {
  long sum = 0;
  for (int i = 0; i < 30; i++) {
    sum += analogRead(TDS_PIN);
    delay(5);
  }

  float raw = sum / 30.0;

  // If the analog input is basically zero, treat it as an invalid sample.
  // This often happens when the probe is out of water, wiring is loose,
  // or the probe output temporarily collapses after exposure to detergents.
  if (raw <= 2.0) {
    g_tdsValid = false;
    Serial.println("⚠ TDS sensor read ~0 (raw ADC near 0). Check probe/wiring; keeping last TDS value.");
    return;
  }

  float voltage = raw * (3.3 / 4095.0);

  // Temperature compensation (common conductivity/TDS sensor approach)
  const float compensationCoefficient = 1.0 + 0.02 * (g_temp - 25.0);
  const float compensationVoltage = voltage / compensationCoefficient;

  // Standard-ish TDS conversion curve (used by popular TDS sensor modules)
  float tds = (133.42 * compensationVoltage * compensationVoltage * compensationVoltage
               - 255.86 * compensationVoltage * compensationVoltage
               + 857.39 * compensationVoltage) * 0.5;

  // Apply user calibration scale
  tds *= TDS_K;

  // Clamp to sane bounds
  tds = constrain(tds, 0.0, 2000.0);

  g_tds = tds;
  g_tdsValid = true;
}

// ==========================
// Supabase HTTP
// ==========================
String _jsonNumber(double value, int decimals) {
  // Return a JSON number token with fixed decimals (not a quoted string).
  // Using `serialized()` with this keeps numeric types in the JSON.
  return String(value, decimals);
}

void sendToSupabase() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, skipping send");
    connectWiFi();
    return;
  }

  String timestamp = getIsoTimestamp();
  if (timestamp.length() == 0) {
    // Extremely unlikely after fallback, but keep a safe guard.
    timestamp = "1970-01-01T00:00:00Z";
  }

  WiFiClientSecure client;
  client.setInsecure(); // For development; use CA cert in production

  HTTPClient http;
  if (!http.begin(client, supabaseUrl)) {
    Serial.println("Failed to begin HTTPS connection to Supabase");
    blinkError();
    return;
  }

  http.setTimeout(15000);

  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseAnonKey);
  http.addHeader("Authorization", String("Bearer ") + supabaseAnonKey);
  http.addHeader("Prefer", "return=representation");

  StaticJsonDocument<256> doc;
  // Match payload precision seen in your logs.
  doc["ph"] = serialized(_jsonNumber(g_ph, 5));
  doc["temp"] = serialized(_jsonNumber(g_temp, 4));
  doc["tds"] = serialized(_jsonNumber(g_tds, 4));
  doc["timestamp"] = timestamp;

  String payload;
  serializeJson(doc, payload);

  Serial.print("Sending to Supabase: ");
  Serial.println(payload);

  int code = http.POST(payload);
  if (code > 0) {
    Serial.printf("HTTP %d\n", code);
    String response = http.getString();
    if (response.length() > 0) {
      Serial.println("Response: " + response);
    }

    if (code == 200 || code == 201) {
      blinkSuccess();
    } else {
      blinkError();
    }
  } else {
    // Force consistent Serial output for the common ESP32 -1 case.
    if (code == HTTPC_ERROR_CONNECTION_REFUSED) {
      Serial.println("HTTP error (-1): connection refused");
      Serial.println("If this is CONNECTION_REFUSED, try a different network/hotspot.");
    } else {
      Serial.printf("HTTP error (%d): %s\n", code, http.errorToString(code).c_str());
    }
    blinkError();
  }

  http.end();
}

// ==========================
// LED Helpers
// ==========================
void blinkSuccess() {
  for (int i = 0; i < 2; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
}

void blinkError() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
    delay(200);
  }
}
