import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageAppointmentsScreen extends StatelessWidget {
  const ManageAppointmentsScreen({super.key});

  Future<void> _updateStatus(DocumentSnapshot doc, String newStatus) async {
    await doc.reference.update({'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('appointments')
            .orderBy('date')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading appointments'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No appointments found.'));
          }

          final appointments = snapshot.data!.docs;

          return ListView.builder(
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final doc = appointments[index];
              final data = doc.data() as Map<String, dynamic>;
              final patientName = data['patientName'] ?? 'Unnamed';
              final date = (data['date'] as Timestamp).toDate();
              final notes = data['notes'] ?? '';
              final status = data['status'] ?? 'pending';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Icon(Icons.event, color: Colors.purple.shade400),
                  title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('MMM d, yyyy – hh:mm a').format(date)),
                      if (notes.isNotEmpty) Text('Notes: $notes'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Chip(
                            label: Text(status, style: const TextStyle(color: Colors.white)),
                            backgroundColor: status == 'confirmed'
                                ? Colors.green
                                : status == 'rejected'
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                          const Spacer(),
                          if (status == 'pending') ...[
                            TextButton(
                              onPressed: () => _updateStatus(doc, 'confirmed'),
                              child: const Text('Confirm'),
                            ),
                            TextButton(
                              onPressed: () => _updateStatus(doc, 'rejected'),
                              child: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                          ]
                        ],
                      )
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
