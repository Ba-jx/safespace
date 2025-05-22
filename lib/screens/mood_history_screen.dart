import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  List<Map<String, dynamic>> _moodEntries = [];

  @override
  void initState() {
    super.initState();
    _fetchMoodLogs();
  }

  Future<void> _fetchMoodLogs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('symptom_logs')
        .orderBy('timestamp', descending: true)
        .get();

    final logs = snapshot.docs.map((doc) => doc.data()).toList();

    setState(() {
      _moodEntries = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2F2A43) : Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text('Mood History')),
      body: _moodEntries.isEmpty
          ? const Center(child: Text('No mood history found.'))
          : ListView.builder(
              itemCount: _moodEntries.length,
              itemBuilder: (context, index) {
                final entry = _moodEntries[index];
                final mood = entry['mood'] ?? '';
                final note = entry['note'] ?? '';
                final timestamp = (entry['timestamp'] as Timestamp?)?.toDate();

                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Text(
                      mood,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(
                      timestamp != null
                          ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}'
                          : 'Unknown date',
                    ),
                    subtitle: note.isNotEmpty ? Text(note) : null,
                  ),
                );
              },
            ),
    );
  }
}
