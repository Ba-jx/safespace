import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class VitalsChartScreen extends StatelessWidget {
  final String patientId;

  const VitalsChartScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vitals Over Time')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .collection('readings')
              .orderBy('timestamp')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('No vitals data found.'));

            final List<FlSpot> heartRatePoints = [];
            final List<FlSpot> oxygenPoints = [];
            final List<FlSpot> tempPoints = [];

            for (int i = 0; i < docs.length; i++) {
              final data = docs[i].data() as Map<String, dynamic>;

              if (data['heartRate'] != null) {
                heartRatePoints.add(
                  FlSpot(i.toDouble(), (data['heartRate'] as num).toDouble()),
                );
              }
              if (data['oxygenLevel'] != null) {
                oxygenPoints.add(
                  FlSpot(i.toDouble(), (data['oxygenLevel'] as num).toDouble()),
                );
              }
              if (data['temperature'] != null) {
                tempPoints.add(
                  FlSpot(i.toDouble(), (data['temperature'] as num).toDouble()),
                );
              }
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildVitalsChart(
                    title: 'Heart Rate (BPM)',
                    spots: heartRatePoints,
                    color: Colors.redAccent,
                    minY: 40,
                    maxY: 160,
                  ),
                  const SizedBox(height: 30),
                  _buildVitalsChart(
                    title: 'Oxygen Level (%)',
                    spots: oxygenPoints,
                    color: Colors.blueAccent,
                    minY: 80,
                    maxY: 100,
                  ),
                  const SizedBox(height: 30),
                  _buildVitalsChart(
                    title: 'Temperature (°C)',
                    spots: tempPoints,
                    color: Colors.orange,
                    minY: 34,
                    maxY: 40,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVitalsChart({
    required String title,
    required List<FlSpot> spots,
    required Color color,
    double? minY,
    double? maxY,
  }) {
    if (spots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('No data available')),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: true),
              minY: minY ?? spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 5,
              maxY: maxY ?? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 5,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  dotData: FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
