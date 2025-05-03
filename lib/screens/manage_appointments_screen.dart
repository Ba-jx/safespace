import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_drawer.dart';

class ManageAppointmentsScreen extends StatelessWidget {
  const ManageAppointmentsScreen({super.key});

  Future<void> _updateStatus(String userId, String appointmentId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Appointments')),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('appointments')
              .where('doctorId', isEqualTo: doctorId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('Error: ${snapshot.error}');
              return const Center(child: Text('Error loading appointments.'));
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
                final dateTime = (data['dateTime'] as Timestamp?)?.toDate();
                final note = data['note'] ?? '';
                final status = data['status'] ?? 'Pending';
                final userId = doc.reference.parent.parent?.id;
                final appointmentId = doc.id;

                final formattedDate = dateTime != null
                    ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
                    : 'Unknown';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(patientName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: $formattedDate'),
                        if (note.isNotEmpty) Text('Note: $note'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('Status: '),
                            DropdownButton<String>(
                              value: status,
                              items: ['Pending', 'Confirmed', 'Completed', 'Cancelled']
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null && userId != null) {
                                  _updateStatus(userId, appointmentId, value);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
