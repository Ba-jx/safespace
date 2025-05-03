import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageAppointmentsScreen extends StatelessWidget {
  const ManageAppointmentsScreen({super.key});

  Future<void> _updateStatus(DocumentSnapshot doc, String newStatus) async {
    await doc.reference.update({'status': newStatus});
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blueAccent;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
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
            .orderBy('dateTime', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
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
              final formatted = dateTime != null
                  ? DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime.toDate())
                  : 'No Date';

              final note = data['note'] ?? '';
              final status = data['status'] ?? 'pending';
              final patientName = data['patientName'] ?? 'Unknown';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: ListTile(
                  title: Text(
                    patientName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date: $formatted'),
                      if (note.isNotEmpty) Text('Note: $note'),
                      Row(
                        children: [
                          const Text('Status: '),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _updateStatus(doc, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'pending', child: Text('Pending')),
                      const PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
                      const PopupMenuItem(value: 'completed', child: Text('Completed')),
                      const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    ],
                    icon: const Icon(Icons.edit),
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
