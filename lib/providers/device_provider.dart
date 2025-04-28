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

  void reset() {
    _heartRate = 0;
    _temperature = 0.0;
    _oxygenLevel = 0;
    notifyListeners();
  }
}
