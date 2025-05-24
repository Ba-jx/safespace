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

// WiFi + Blynk credentials
char ssid[] = "YOUR_WIFI_SSID";
char pass[] = "YOUR_WIFI_PASSWORD";
char auth[] = BLYNK_AUTH_TOKEN;

// GPIO
#define BUZZER_PIN 2
#define RED_LED_PIN 26
#define GREEN_LED_PIN 33
#define VIBRATION_PIN 13

BluetoothSerial SerialBT;

void setup() {
  Serial.begin(115200);
  lcd.init();
  lcd.backlight();
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay();
  display.display();

  lcd.setCursor(0, 0);
  lcd.print("Initializing...");

  WiFi.begin(ssid, pass);
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 10) {
    delay(1000);
    retry++;
  }

  Blynk.begin(auth, ssid, pass);

  if (!particleSensor.begin()) {
    lcd.setCursor(0, 1);
    lcd.print("Sensor Error!");
    while (1);
  }

  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(VIBRATION_PIN, OUTPUT);
  SerialBT.begin("SafeSpace");
}

void loop() {
  Blynk.run();

  int heartRate, SpO2;
  float tempC = 36.5; // Placeholder if temp sensor not added

  if (particleSensor.getHeartbeatFlag()) {
    heartRate = particleSensor.getHeartRate();
    SpO2 = particleSensor.getSpO2();

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("HR:");
    lcd.print(heartRate);
    lcd.print(" SpO2:");
    lcd.print(SpO2);

    lcd.setCursor(0, 1);
    lcd.print("Temp:");
    lcd.print(tempC);

    if (heartRate > 120 || SpO2 < 90 || tempC > 38.0) {
      digitalWrite(RED_LED_PIN, HIGH);
      digitalWrite(GREEN_LED_PIN, LOW);
      digitalWrite(BUZZER_PIN, HIGH);
      digitalWrite(VIBRATION_PIN, HIGH);

      display.clearDisplay();
      display.setTextSize(1);
      display.setCursor(0, 0);
      display.print("!! DANGER !!");
      display.display();

      SerialBT.println("ALERT: Abnormal Vitals!");
    } else {
      digitalWrite(GREEN_LED_PIN, HIGH);
      digitalWrite(RED_LED_PIN, LOW);
      digitalWrite(BUZZER_PIN, LOW);
      digitalWrite(VIBRATION_PIN, LOW);

      display.clearDisplay();
      display.setTextSize(1);
      display.setCursor(0, 0);
      display.print("Vitals Normal");
      display.display();
    }

    Blynk.virtualWrite(V0, heartRate);
    Blynk.virtualWrite(V1, SpO2);
    Blynk.virtualWrite(V2, tempC);
  }

  delay(1000);
}
