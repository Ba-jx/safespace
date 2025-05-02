import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 20),
            const Text(
              'Mood & Vitals History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(patientId)
                    .collection('symptom_logs')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading mood logs'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No mood logs found.'));
                  }

                  final logs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index].data() as Map<String, dynamic>;
                      final mood = log['mood'] ?? '❓';
                      final date = log['date']?.toDate();
                      final formatted = date != null
                          ? DateFormat('MMM dd, yyyy – hh:mm a').format(date)
                          : 'Unknown date';

                      final heartRate = log['heartRate'];
                      final temperature = log['temperature'];
                      final oxygen = log['oxygenLevel'];
                      final note = log['note'];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Text(mood, style: const TextStyle(fontSize: 28)),
                          title: Text(formatted),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (heartRate != null)
                                Text('Heart Rate: $heartRate bpm'),
                              if (temperature != null)
                                Text('Temperature: $temperature °C'),
                              if (oxygen != null)
                                Text('Oxygen Level: $oxygen%'),
                              if (note != null && note.toString().isNotEmpty)
                                Text('Note: $note'),
                            ],
                          ),
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
