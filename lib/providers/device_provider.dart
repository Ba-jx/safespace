import 'package:flutter/foundation.dart';

class DeviceProvider extends ChangeNotifier {
  int _heartRate = 0;
  double _temperature = 0.0;
  int _oxygenLevel = 0;

  int get heartRate => _heartRate;
  double get temperature => _temperature;
  int get oxygenLevel => _oxygenLevel;

  void updateHeartRate(int value) {
    _heartRate = value;
    notifyListeners();
  }

  void updateTemperature(double value) {
    _temperature = value;
    notifyListeners();
  }

  void updateOxygenLevel(int value) {
    _oxygenLevel = value;
    notifyListeners();
  }

  void updateFromBluetoothData(String data) {
    // Expected format: "BPM:75 | SpO2:98% | Temp:36.5C"
    try {
      final parts = data.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.startsWith('BPM:')) {
          _heartRate = int.tryParse(trimmed.substring(4).trim()) ?? _heartRate;
        } else if (trimmed.startsWith('SpO2:')) {
          final spStr = trimmed.substring(5).replaceAll('%', '').trim();
          _oxygenLevel = int.tryParse(spStr) ?? _oxygenLevel;
        } else if (trimmed.startsWith('Temp:')) {
          final tempStr = trimmed.substring(5).replaceAll('C', '').trim();
          _temperature = double.tryParse(tempStr) ?? _temperature;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing Bluetooth data: $e');
    }
  }

  void reset() {
    _heartRate = 0;
    _temperature = 0.0;
    _oxygenLevel = 0;
    notifyListeners();
  }
}
