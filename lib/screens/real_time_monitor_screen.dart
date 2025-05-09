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
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? dataChar;
  String status = 'Scanning...';

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() {
    flutterBlue.startScan(timeout: const Duration(seconds: 5));
    flutterBlue.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name == 'ESP32_HealthMonitor') {
          await flutterBlue.stopScan();
          setState(() => status = 'Connecting to ${r.device.name}');
          try {
            await r.device.connect();
          } catch (_) {}
          setState(() => connectedDevice = r.device);
          discoverServices(r.device);
          break;
        }
      }
    });
  }

  void discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.properties.notify) {
          await char.setNotifyValue(true);
          char.value.listen((value) {
            final rawData = String.fromCharCodes(value);
            parseAndUpdateData(rawData);
          });
          setState(() => dataChar = char);
          break;
        }
      }
    }
  }

  void parseAndUpdateData(String data) {
    final device = Provider.of<DeviceProvider>(context, listen: false);
    final parts = data.split('|');
    for (var part in parts) {
      if (part.contains('BPM:')) {
        device.updateHeartRate(int.tryParse(part.split(':')[1].trim()) ?? 0);
      } else if (part.contains('SpO2:')) {
        device.updateOxygenLevel(int.tryParse(part.split(':')[1].replaceAll('%', '').trim()) ?? 0);
      } else if (part.contains('Temp:')) {
        device.updateTemperature(double.tryParse(part.split(':')[1].replaceAll('C', '').trim()) ?? 0.0);
      }
    }
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
            Text('Status: $status', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            _buildMetricRow(
              icon: Icons.favorite,
              title: 'Heart Rate',
              value: '${device.heartRate} BPM',
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              icon: Icons.thermostat,
              title: 'Temperature',
              value: '${device.temperature.toStringAsFixed(1)} °C',
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              icon: Icons.bloodtype,
              title: 'Oxygen Level',
              value: '${device.oxygenLevel}%',
              color: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
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
