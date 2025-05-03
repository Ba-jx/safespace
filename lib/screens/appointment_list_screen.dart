import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentListScreen extends StatelessWidget {
  const AppointmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: currentUserId == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .collection('appointments')
                  .orderBy('dateTime')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading appointments'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No appointments found'));
                }

                final appointments = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final doc = appointments[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final dateTime = (data['dateTime'] ?? data['date']) as Timestamp?;
                    final formattedDate = dateTime != null
                        ? DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime.toDate())
                        : 'Unknown Date';

                    final note = data['note'] ?? '';
                    final status = data['status'] ?? 'pending';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(formattedDate),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (note.isNotEmpty) Text('Note: $note'),
                            Text('Status: $status'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
