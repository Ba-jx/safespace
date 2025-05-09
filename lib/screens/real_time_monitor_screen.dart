import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';

class RealTimeMonitorScreen extends StatefulWidget {
  const RealTimeMonitorScreen({super.key});

  @override
  State<RealTimeMonitorScreen> createState() => _RealTimeMonitorScreenState();
}

class _RealTimeMonitorScreenState extends State<RealTimeMonitorScreen> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? dataChar;
  String status = 'Scanning...';

  @override
  void initState() {
    super.initState();
    startScan();
  }

  void startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == "ESP32_HealthMonitor") {
          FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    setState(() => status = 'Connecting...');
    try {
      await device.connect();
      setState(() {
        connectedDevice = device;
        status = 'Connected';
      });
      discoverServices(device);
    } catch (e) {
      setState(() => status = 'Connection Failed');
      debugPrint('Connection error: $e');
    }
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          dataChar = characteristic;
          await characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((value) {
            final reading = String.fromCharCodes(value);
            _handleReading(reading);
          });
        }
      }
    }
  }

  void _handleReading(String data) {
    final device = Provider.of<DeviceProvider>(context, listen: false);
    if (data.contains('BPM:')) {
      final bpm = RegExp(r'BPM:(\d+)').firstMatch(data)?.group(1);
      final spo2 = RegExp(r'SpO2:(\d+)').firstMatch(data)?.group(1);
      final temp = RegExp(r'Temp:([\d.]+)').firstMatch(data)?.group(1);

      if (bpm != null) device.updateHeartRate(int.parse(bpm));
      if (spo2 != null) device.updateOxygenLevel(int.parse(spo2));
      if (temp != null) device.updateTemperature(double.parse(temp));
    }
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = Provider.of<DeviceProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Real-Time Monitor')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMetricRow(Icons.favorite, 'Heart Rate', '${device.heartRate} BPM', Colors.redAccent),
            const SizedBox(height: 16),
            _buildMetricRow(Icons.thermostat, 'Temperature', '${device.temperature.toStringAsFixed(1)} °C', Colors.orange),
            const SizedBox(height: 16),
            _buildMetricRow(Icons.bloodtype, 'Oxygen Level', '${device.oxygenLevel}%', Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 36, color: color),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 18, color: Colors.black),
            children: [
              TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w500)),
              const TextSpan(text: '  '),
              TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
