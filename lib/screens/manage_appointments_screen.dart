import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageAppointmentsScreen extends StatelessWidget {
  const ManageAppointmentsScreen({super.key});

  Future<void> _updateStatus(DocumentSnapshot doc, String newStatus) async {
    await doc.reference.update({'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    final currentDoctorId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('appointments')
            .where('doctorId', isEqualTo: currentDoctorId)
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

              final dateTime = (data['dateTime'] as Timestamp?)?.toDate();
              final formatted = dateTime != null
                  ? DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime)
                  : 'No Date';

              final note = data['note'] ?? '';
              final status = data['status'] ?? 'pending';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(formatted),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.isNotEmpty) Text('Note: $note'),
                      Text('Status: $status'),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _updateStatus(doc, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'pending', child: Text('Pending')),
                      const PopupMenuItem(value: 'approved', child: Text('Approved')),
                      const PopupMenuItem(value: 'declined', child: Text('Declined')),
                    ],
                    icon: const Icon(Icons.more_vert),
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
