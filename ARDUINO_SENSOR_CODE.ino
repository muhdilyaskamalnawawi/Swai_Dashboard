/*
  SWAI Dashboard - Arduino Water Quality Sensor Code
  Monitors: pH, TDS (Total Dissolved Solids), Temperature
  Sends data to backend API or Node-RED
  
  Hardware Required:
  - Arduino (Uno, Mega, or ESP32)
  - pH Sensor Module (analog input)
  - DS18B20 Temperature Sensor (digital input)
  - TDS Sensor Module (analog input)
  - WiFi Module (ESP32 has built-in WiFi)
  
  Connections:
  - pH Sensor → A0 (analog pin)
  - TDS Sensor → A1 (analog pin)
  - Temperature Sensor → D2 (digital pin)
*/

#include <OneWire.h>
#include <DallasTemperature.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ===== WiFi Configuration =====
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// ===== Backend API Configuration =====
// Update this with your Node-RED or backend server URL
const char* serverUrl = "http://YOUR_API_SERVER:1880/api/sensor/reading";

// ===== Pin Configuration =====
const int pH_PIN = 35;           // Analog pin for pH sensor (ESP32: 35 or 36)
const int TDS_PIN = 34;          // Analog pin for TDS sensor (ESP32: 34)
const int TEMP_PIN = 2;          // Digital pin for DS18B20 temperature sensor
const int BUILTIN_LED = 2;       // Built-in LED pin (visual feedback)

// ===== Sensor Calibration =====
// pH Sensor calibration (adjust based on your sensor)
const float PH_OFFSET = 0.0;     // pH offset for calibration
const float VOLTAGE_FACTOR = 3.3 / 4095.0; // For ESP32 ADC (12-bit)

// TDS Sensor calibration
const float TDS_CONSTANT = 0.5;  // TDS conversion constant (adjust per sensor)
const float TDS_OFFSET = 0.0;    // TDS offset for calibration

// ===== Temperature Sensor Setup =====
OneWire oneWire(TEMP_PIN);
DallasTemperature sensors(&oneWire);

// ===== Sensor Reading Variables =====
float pH = 0.0;
float temperature = 0.0;
float tds = 0.0;
int readingCount = 0;

// ===== Timing Configuration =====
unsigned long lastReadTime = 0;
const unsigned long READ_INTERVAL = 5000;  // Read sensors every 5 seconds
const unsigned long SEND_INTERVAL = 30000; // Send data to backend every 30 seconds
unsigned long lastSendTime = 0;

void setup() {
  // Initialize Serial for debugging
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== SWAI Dashboard Arduino Sensor Code ===");
  Serial.println("Initializing...");

  // Initialize pins
  pinMode(BUILTIN_LED, OUTPUT);
  digitalWrite(BUILTIN_LED, LOW);

  // Initialize temperature sensor
  sensors.begin();
  Serial.println("✓ Temperature sensor initialized");

  // Connect to WiFi
  connectToWiFi();

  Serial.println("✓ Setup complete!");
  digitalWrite(BUILTIN_LED, HIGH);
}

void loop() {
  unsigned long currentTime = millis();

  // Read sensors at regular interval
  if (currentTime - lastReadTime >= READ_INTERVAL) {
    readSensors();
    lastReadTime = currentTime;
  }

  // Send data to backend at longer interval
  if (currentTime - lastSendTime >= SEND_INTERVAL) {
    sendDataToBackend();
    lastSendTime = currentTime;
  }

  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    digitalWrite(BUILTIN_LED, LOW);
    Serial.println("WiFi disconnected! Reconnecting...");
    connectToWiFi();
  } else {
    digitalWrite(BUILTIN_LED, HIGH);
  }

  delay(100);
}

// ===== Read All Sensors =====
void readSensors() {
  readPH();
  readTDS();
  readTemperature();
  
  readingCount++;
  Serial.printf("Reading #%d | pH: %.2f | TDS: %.0f ppm | Temp: %.2f°C\n", 
                readingCount, pH, tds, temperature);
}

// ===== Read pH Sensor =====
void readPH() {
  int rawValue = analogRead(pH_PIN);
  float voltage = rawValue * VOLTAGE_FACTOR;
  
  // Convert voltage to pH (0-14 scale)
  // Standard: 7.0 pH = 2.5V at 25°C
  // Typical probe: -0.059V per pH unit (Nernst equation)
  pH = 7.0 + (2.5 - voltage) / 0.059;
  
  // Apply offset calibration
  pH += PH_OFFSET;
  
  // Constrain to valid range
  pH = constrain(pH, 0, 14);
}

// ===== Read TDS Sensor =====
void readTDS() {
  int rawValue = analogRead(TDS_PIN);
  float voltage = rawValue * VOLTAGE_FACTOR;
  
  // Convert voltage to TDS (ppm)
  // Typical TDS sensor: ~0.5 ppm per mV
  tds = voltage * TDS_CONSTANT * 1000;
  
  // Apply offset calibration
  tds += TDS_OFFSET;
  
  // Constrain to valid range
  tds = constrain(tds, 0, 2000);
}

// ===== Read Temperature Sensor =====
void readTemperature() {
  sensors.requestTemperatures();
  temperature = sensors.getTempCByIndex(0);
  
  // Check for sensor error
  if (temperature == DEVICE_DISCONNECTED_C) {
    Serial.println("Temperature sensor error!");
    temperature = 25.0; // Default value
  }
}

// ===== Connect to WiFi =====
void connectToWiFi() {
  int attempts = 0;
  const int MAX_ATTEMPTS = 20;
  
  Serial.printf("Connecting to WiFi: %s\n", ssid);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED && attempts < MAX_ATTEMPTS) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✓ WiFi connected!");
    Serial.printf("IP Address: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\n✗ WiFi connection failed!");
  }
}

// ===== Send Data to Backend =====
void sendDataToBackend() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Skipping send.");
    return;
  }

  HTTPClient http;
  http.begin(serverUrl);
  http.addHeader("Content-Type", "application/json");

  // Create JSON payload
  StaticJsonDocument<256> doc;
  doc["pH"] = pH;
  doc["temp"] = temperature;
  doc["tds"] = tds;
  doc["timestamp"] = getTimestamp();

  String payload;
  serializeJson(doc, payload);

  Serial.printf("Sending: %s\n", payload.c_str());

  // Send POST request
  int httpResponseCode = http.POST(payload);

  if (httpResponseCode > 0) {
    Serial.printf("✓ Response Code: %d\n", httpResponseCode);
    String response = http.getString();
    Serial.printf("Response: %s\n", response.c_str());
  } else {
    Serial.printf("✗ Error Code: %d\n", httpResponseCode);
  }

  http.end();
}

// ===== Get Timestamp (Simple) =====
String getTimestamp() {
  // For production, use NTP time sync
  // This is a simple placeholder
  return String(millis() / 1000);
}

// ===== Debug: Print Calibration Info =====
void printCalibrationInfo() {
  Serial.println("\n=== Calibration Information ===");
  Serial.printf("pH Offset: %.2f\n", PH_OFFSET);
  Serial.printf("TDS Constant: %.2f\n", TDS_CONSTANT);
  Serial.printf("TDS Offset: %.2f\n", TDS_OFFSET);
  Serial.printf("Voltage Factor: %.6f\n", VOLTAGE_FACTOR);
  Serial.println("================================\n");
}
