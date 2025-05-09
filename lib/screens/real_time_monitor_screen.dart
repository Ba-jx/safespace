import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/device_provider.dart';

class RealTimeMonitorScreen extends StatefulWidget {
  const RealTimeMonitorScreen({super.key});

  @override
  State<RealTimeMonitorScreen> createState() => _RealTimeMonitorScreenState();
}

class _RealTimeMonitorScreenState extends State<RealTimeMonitorScreen> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? notifyCharacteristic;
  StreamSubscription<List<int>>? notifySubscription;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    scanAndConnect();
  }

  @override
  void dispose() {
    notifySubscription?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }

  void scanAndConnect() async {
    setState(() => isScanning = true);

    flutterBlue.startScan(timeout: const Duration(seconds: 5));
    flutterBlue.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name == "ESP32_HealthMonitor") {
          flutterBlue.stopScan();
          await r.device.connect();
          connectedDevice = r.device;

          List<BluetoothService> services = await r.device.discoverServices();
          for (var service in services) {
            for (var char in service.characteristics) {
              if (char.properties.notify) {
                notifyCharacteristic = char;
                await char.setNotifyValue(true);
                notifySubscription = char.value.listen((value) {
                  final data = String.fromCharCodes(value);
                  parseAndUpdate(data);
                });
                break;
              }
            }
          }

          setState(() => isScanning = false);
          break;
        }
      }
    });
  }

  void parseAndUpdate(String data) async {
    final device = Provider.of<DeviceProvider>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      final parts = data.split('|');
      int hr = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
      int spo2 = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      double temp = double.parse(parts[2].replaceAll(RegExp(r'[^0-9\.]'), ''));

      device.updateHeartRate(hr);
      device.updateOxygenLevel(spo2);
      device.updateTemperature(temp);

      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('readings')
            .add({
              'heartRate': hr,
              'oxygenLevel': spo2,
              'temperature': temp,
              'timestamp': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      debugPrint("Parse error: $e");
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
            const SizedBox(height: 24),
            if (isScanning)
              const CircularProgressIndicator()
            else if (connectedDevice != null)
              Text('Connected to ${connectedDevice!.name}', style: const TextStyle(color: Colors.green))
            else
              const Text('Device not connected', style: TextStyle(color: Colors.red)),
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
