# Safe Space Device Firmware

This folder contains the firmware code for the ESP32-based wearable device used in the Safe Space system. The device monitors:

- ❤️ Heart Rate and SpO2 (via MAX30102)
- 🌡️ Body Temperature
- ⚠️ Sends alerts when vitals are abnormal
- 📲 Communicates via Bluetooth and WiFi
- ☁️ Sends data to the Blynk IoT platform

---

## 📦 Requirements

### Hardware:
- ESP32
- MAX30102 Pulse Oximeter Sensor
- DS18B20 or other temperature sensor
- 16x2 I2C LCD Display
- 128x64 OLED Display
- Buzzer
- Vibration Motor
- Red & Green LEDs

### Libraries:
See `libraries.txt` for installation.

---

## 🛠 Setup Instructions

1. Open `SafeSpaceDevice.ino` in Arduino IDE.
2. Install the required libraries listed in `libraries.txt`.
3. Replace the placeholders in the code:
   ```cpp
   char ssid[] = "YOUR_WIFI_SSID";
   char pass[] = "YOUR_WIFI_PASSWORD";
   char auth[] = "YOUR_BLYNK_AUTH_TOKEN";
