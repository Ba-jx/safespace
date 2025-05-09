import 'dart:async';
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
  StreamSubscription<List<int>>? dataSubscription;

  @override
  void initState() {
    super.initState();
    _scanAndConnect();
  }

  @override
  void dispose() {
    dataSubscription?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }

  void _scanAndConnect() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    deviceProvider.updateBluetoothStatus('Scanning...');

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if (result.device.name.contains("ESP32")) {
          FlutterBluePlus.stopScan();
          deviceProvider.updateBluetoothStatus('Connecting...');
          try {
            await result.device.connect(autoConnect: false);
          } catch (_) {}

          connectedDevice = result.device;
          deviceProvider.updateBluetoothStatus('Connected');
          _listenToDevice();
          break;
        }
      }
    });
  }

  void _listenToDevice() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    List<BluetoothService> services = await connectedDevice!.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          dataSubscription = characteristic.value.listen((value) {
            String data = String.fromCharCodes(value);
            List<String> parts = data.split("|");

            for (String part in parts) {
              if (part.contains("BPM:")) {
                deviceProvider.updateHeartRate(int.tryParse(part.split(":")[1].trim()) ?? 0);
              } else if (part.contains("SpO2:")) {
                deviceProvider.updateOxygenLevel(int.tryParse(part.split(":")[1].replaceAll("%", "").trim()) ?? 0);
              } else if (part.contains("Temp:")) {
                deviceProvider.updateTemperature(double.tryParse(part.split(":")[1].replaceAll("C", "").trim()) ?? 0.0);
              }
            }
          });
          return;
        }
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
            Text('Bluetooth: ${device.bluetoothStatus}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
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
              TextSpan(
                text: title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const TextSpan(text: '  '),
              TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
