import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';

class RealTimeMonitorScreen extends StatefulWidget {
  const RealTimeMonitorScreen({super.key});

  @override
  State<RealTimeMonitorScreen> createState() => _RealTimeMonitorScreenState();
}

class _RealTimeMonitorScreenState extends State<RealTimeMonitorScreen> {
  static const String authToken = 'IC_O52YQ1auEdxmNw345luxEMu5cwvnl';
  static const String baseUrl = 'https://blynk.cloud/external/api/get';

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => fetchData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl?token=$authToken&v0')),
        http.get(Uri.parse('$baseUrl?token=$authToken&v1')),
        http.get(Uri.parse('$baseUrl?token=$authToken&v2')),
      ]);

      if (responses.every((res) => res.statusCode == 200)) {
        final bpm = int.tryParse(responses[0].body.trim()) ?? 0;
        final spo2 = int.tryParse(responses[1].body.trim()) ?? 0;
        final temp = double.tryParse(responses[2].body.trim()) ?? 0.0;

        final provider = Provider.of<DeviceProvider>(context, listen: false);
        provider.updateHeartRate(bpm);
        provider.updateOxygenLevel(spo2);
        provider.updateTemperature(temp);
      }
    } catch (e) {
      debugPrint('Failed to fetch Blynk data: $e');
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
              icon: Icons.bloodtype,
              title: 'Oxygen Level',
              value: '${device.oxygenLevel} %',
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              icon: Icons.thermostat,
              title: 'Temperature',
              value: '${device.temperature.toStringAsFixed(1)} °C',
              color: Colors.orange,
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
