import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'vitals_chart_screen.dart';

class PatientDetailScreen extends StatelessWidget {
  final String patientId;
  final String name;
  final String email;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2F2A43) : Colors.white;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[300] : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mood & Vitals History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VitalsChartScreen(patientId: patientId),
                  ),
                );
              },
              icon: const Icon(Icons.show_chart),
              label: const Text('View Vitals Chart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C4DB0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(patientId)
                    .collection('symptom_logs')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No mood logs found.'));
                  }

                  final logs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index].data() as Map<String, dynamic>;
                      final date = (log['timestamp'] as Timestamp?)?.toDate();
                      final formatted = date != null
                          ? DateFormat('MMM dd, yyyy – hh:mm a').format(date)
                          : 'Unknown date';

                      final mood = log['mood'] ?? '❓';
                      final note = log['note'];

                      return Card(
                        color: cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Text(mood, style: const TextStyle(fontSize: 28)),
                          title: Text(formatted),
                          subtitle: note != null && note.toString().trim().isNotEmpty
                              ? Text('Note: $note')
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
