import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/device_provider.dart';

class RealTimeMonitorScreen extends StatefulWidget {
  const RealTimeMonitorScreen({super.key});

  @override
  State<RealTimeMonitorScreen> createState() => _RealTimeMonitorScreenState();
}

class _RealTimeMonitorScreenState extends State<RealTimeMonitorScreen> {
  static const String authToken = 'IC_O52YQ1auEdxmNw345luxEMu5cwvnl';
  static const String baseUrl = 'https://blynk.cloud/external/api/get';

  final int _saveEveryNthFetch = 3;
  int _fetchCounter = 0;

  int? _lastHeartRate;
  int? _lastOxygenLevel;
  double? _lastTemperature;

  Timer? _refreshTimer;
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    fetchData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => fetchData(),
    );
    _uiUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl?token=$authToken&v0')), // heart rate
        http.get(Uri.parse('$baseUrl?token=$authToken&v1')), // oxygen
        http.get(Uri.parse('$baseUrl?token=$authToken&v2')), // temperature
      ]);

      if (responses.every((res) => res.statusCode == 200)) {
        final bpm = int.tryParse(responses[0].body.trim()) ?? 0;
        final spo2 = int.tryParse(responses[1].body.trim()) ?? 0;
        final temp = double.tryParse(responses[2].body.trim()) ?? 0.0;

        final provider = Provider.of<DeviceProvider>(context, listen: false);
        provider.updateHeartRate(bpm);
        provider.updateOxygenLevel(spo2);
        provider.updateTemperature(temp);

        _fetchCounter++;

        final isChanged = _lastHeartRate != bpm ||
            _lastOxygenLevel != spo2 ||
            _lastTemperature != temp;

        if (_fetchCounter % _saveEveryNthFetch == 0 && isChanged) {
          final patientId = FirebaseAuth.instance.currentUser?.uid;
          if (patientId != null) {
            await FirebaseFirestore.instance
                .collection('patients')
                .doc(patientId)
                .collection('readings')
                .add({
              'heartRate': bpm,
              'oxygenLevel': spo2,
              'temperature': temp,
              'timestamp': Timestamp.now(),
              'patientId': patientId,
            });

            debugPrint('Saved reading #$_fetchCounter to Firestore');

            _lastHeartRate = bpm;
            _lastOxygenLevel = spo2;
            _lastTemperature = temp;
          }
        } else {
          debugPrint('Skipped save — no change or not nth fetch');
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch/save Blynk data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = Provider.of<DeviceProvider>(context);
    final lastUpdated = device.lastUpdated;

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
            if (lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Text(
                  'Last updated: ${_formatTimestamp(lastUpdated)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
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
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds <= 3) {
      return 'just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
          ' on ${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
