import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoodHistoryScreen extends StatelessWidget {
  const MoodHistoryScreen({super.key});

  bool isSameDay(DateTime? day1, DateTime? day2) {
    if (day1 == null || day2 == null) return false;
    return day1.year == day2.year &&
        day1.month == day2.month &&
        day1.day == day2.day;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('All Mood History')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('symptom_logs')
                .where('uid', isEqualTo: uid)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data!.docs;

          if (entries.isEmpty) {
            return const Center(child: Text('No mood entries found.'));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final mood = entry['mood'];
              final note = entry['note'];
              final timestamp = (entry['timestamp'] as Timestamp?)?.toDate();

              return ListTile(
                leading: Text(mood, style: const TextStyle(fontSize: 32)),
                title: Text(note ?? 'No note'),
                subtitle:
                    timestamp != null
                        ? Text(
                          '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                        )
                        : null,
              );
            },
          );
        },
      ),
    );
  }
}
