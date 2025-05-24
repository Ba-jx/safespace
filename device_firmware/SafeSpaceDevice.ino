#define BLYNK_TEMPLATE_ID "Your_Template_ID"
#define BLYNK_TEMPLATE_NAME "Safe Space"
#define BLYNK_AUTH_TOKEN "YOUR_BLYNK_AUTH_TOKEN"

#include <Wire.h>
#include <WiFi.h>
#include <BluetoothSerial.h>
#include <DFRobot_MAX30102.h>
#include <LiquidCrystal_I2C.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_GFX.h>
#include <BlynkSimpleEsp32.h>

// LCD 16x2
LiquidCrystal_I2C lcd(0x27, 16, 2);

// OLED 128x64
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// MAX30102
DFRobot_MAX30102 particleSensor;

// Blynk Credentials
char auth[] = BLYNK_AUTH_TOKEN;

// WiFi Credentials
char ssid[] = "YOUR_WIFI_SSID";
char pass[] = "YOUR_WIFI_PASSWORD";


// Bluetooth
BluetoothSerial SerialBT;

// Pins
#define BUZZER_PIN 2
#define VIBRATION_PIN 13
#define RED_LED_PIN 25      // RED LED for Danger
#define GREEN_LED_PIN 26    // GREEN LED for Normal

// === OLED Display Functions ===
void initOLED() {
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED init failed");
    while (1);
  }
  display.clearDisplay();
  display.display();
}

void showOLEDProjectName() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(35, 25);
  display.println("Safe Space");
  display.display();
  delay(1000);
  display.clearDisplay();
}

void showOLEDStatus(bool danger) {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(WHITE);
  display.setCursor(25, 25);
  if (danger) {
    display.println("DANGER");
  } else {
    display.println("Normal");
  }
  display.display();
}

void showOLEDFingerRequest() {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(WHITE);
  display.setCursor(10, 25);
  display.println("Put Finger!");
  display.display();
}

// === LCD Display Functions ===
void showLCDProjectName() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Safe Space");
  delay(1000);
  lcd.clear();
}

void showStartupScreen() {
  showLCDProjectName();
  lcd.setCursor(0, 1);
  lcd.print("   Starting...   ");
  delay(1000);
  lcd.clear();
}

// === Setup ===
void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);

  lcd.init();
  lcd.backlight();

  initOLED();
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(VIBRATION_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);

  digitalWrite(VIBRATION_PIN, LOW);
  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(GREEN_LED_PIN, LOW);

  showStartupScreen();

  // WiFi Connection
  WiFi.begin(ssid, pass);
  lcd.setCursor(0, 0);
  lcd.print("WiFi Connecting");
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 10) {
    delay(300);
    lcd.print(".");
    tries++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    lcd.clear();
    lcd.print("WiFi Failed, Trying");
    lcd.setCursor(0, 1);
    lcd.print("Backup Hotspot...");
    WiFi.begin(ssidBackup, passBackup);
    tries = 0;
    while (WiFi.status() != WL_CONNECTED && tries < 10) {
      delay(300);
      lcd.print(".");
      tries++;
    }
  }

  lcd.clear();
  if (WiFi.status() == WL_CONNECTED) {
    lcd.print("WiFi Connected");
  } else {
    lcd.print("WiFi Failed!");
  }
  delay(1000);
  lcd.clear();

  // Bluetooth
  SerialBT.begin("ESP32_HealthMonitor");
  lcd.print("Bluetooth Ready");
  delay(500);
  lcd.clear();

  // Sensor Init
  if (!particleSensor.begin()) {
    lcd.print("Sensor Failed!");
    while (1);
  }

  particleSensor.sensorConfiguration(
    50, SAMPLEAVG_4, MODE_MULTILED,
    SAMPLERATE_100, PULSEWIDTH_411, ADCRANGE_16384
  );

  lcd.print("Sensor Ready");
  delay(500);
  lcd.clear();

  // Start Blynk
  Blynk.begin(auth, ssid, pass);
}

// === Loop ===
void loop() {
  int32_t spo2 = 0;
  int8_t spo2Valid = 0;
  int32_t heartRate = 0;
  int8_t hrValid = 0;

  float tempC = particleSensor.readTemperatureC();
  particleSensor.heartrateAndOxygenSaturation(&spo2, &spo2Valid, &heartRate, &hrValid);

  Serial.print("Heart Rate: ");
  Serial.print(heartRate);
  Serial.print(" SpO2: ");
  Serial.print(spo2);
  Serial.print(" Temp: ");
  Serial.println(tempC);

  if (spo2Valid && hrValid && heartRate > 0 && spo2 > 0) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("BPM:");
    lcd.print(heartRate);
    lcd.print(" SpO2:");
    lcd.print(spo2);
    lcd.setCursor(0, 1);
    lcd.print("Temp:");
    lcd.print(tempC, 1);
    lcd.print("C");

    bool danger = (heartRate < 50 || heartRate > 120 || spo2 < 90 || tempC < 27 || tempC > 37.5);
    showOLEDStatus(danger);

    Blynk.virtualWrite(V0, heartRate);
    Blynk.virtualWrite(V1, spo2);
    Blynk.virtualWrite(V2, tempC);

    if (danger) {
      tone(BUZZER_PIN, 500);
      digitalWrite(VIBRATION_PIN, HIGH);
      digitalWrite(RED_LED_PIN, HIGH);
      digitalWrite(GREEN_LED_PIN, LOW);

      String alarmMsg = "ALARM: ";
      if (heartRate < 50) alarmMsg += "Low BPM!";
      else if (heartRate > 120) alarmMsg += "High BPM!";
      else if (spo2 < 90) alarmMsg += "Low SpO2!";
      else if (tempC < 27) alarmMsg += "Low Temp!";
      else if (tempC > 37.5) alarmMsg += "High Temp!";
      SerialBT.println(alarmMsg);
    } else {
      noTone(BUZZER_PIN);
      digitalWrite(VIBRATION_PIN, LOW);
      digitalWrite(RED_LED_PIN, LOW);
      digitalWrite(GREEN_LED_PIN, HIGH);
    }

    String report = "BPM:" + String(heartRate) + " | SpO2:" + String(spo2) + "% | Temp:" + String(tempC, 1) + "C";
    Serial.println(report);
    SerialBT.println(report);
  } else {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Put finger on");
    lcd.setCursor(0, 1);
    lcd.print("sensor...");
    showOLEDFingerRequest();

    noTone(BUZZER_PIN);
    digitalWrite(VIBRATION_PIN, LOW);
    digitalWrite(RED_LED_PIN, LOW);
    digitalWrite(GREEN_LED_PIN, LOW);
    SerialBT.println("Waiting for finger...");
  }

  Blynk.run();
  delay(100);
}
