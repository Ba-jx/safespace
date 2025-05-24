# Safe Space

Safe Space is a health monitoring and support platform for PTSD patients. It includes:

- 📱 A Flutter-based mobile app for patients
- 🧑‍⚕️ A doctor-facing dashboard
- 🧠 A wearable ESP32 device that monitors vitals

---

## 📱 Mobile App

Located in the `lib/`, `android/`, and `ios/` folders.

---

## 🔧 ESP32 Device Firmware

Firmware for the wearable device is available in the [`device_firmware/`](./device_firmware/) folder.

It reads:
- Heart Rate & SpO2 via MAX30102
- Temperature via DS18B20
- Sends alerts using Bluetooth & Blynk

Setup instructions and wiring diagrams are inside that folder.

---

## ☁️ Backend

Firebase Cloud Functions and Firestore-based backend logic is located in the `functions/` folder.
