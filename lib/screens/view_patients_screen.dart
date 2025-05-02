import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewPatientsScreen extends StatelessWidget {
  const ViewPatientsScreen({super.key});

  Future<String?> _fetchLatestMood(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('symptom_logs')
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data()['mood'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patients')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading patients.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final patients = snapshot.data?.docs ?? [];

          if (patients.isEmpty) {
            return const Center(child: Text('No patients found.'));
          }

          return ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              final data = patient.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unnamed';
              final email = data['email'] ?? 'No email';
              final userId = patient.id;

              return FutureBuilder<String?>(
                future: _fetchLatestMood(userId),
                builder: (context, moodSnapshot) {
                  final mood = moodSnapshot.data ?? '❓';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFD8BFD8),
                      child: Text(mood, style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(name),
                    subtitle: Text(email),
                    onTap: () {
                      // Navigate to patient profile/logs
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
