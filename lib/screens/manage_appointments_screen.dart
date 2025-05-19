import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  State<ManageAppointmentsScreen> createState() => _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  String _searchQuery = '';

  Future<void> _updateStatus(DocumentSnapshot doc, String newStatus) async {
    final currentStatus = doc['status'] ?? '';
    if (currentStatus == newStatus) return; // Prevent duplicate update

    await doc.reference.update({'status': newStatus});
    setState(() {}); // Refresh
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'rescheduled':
        color = Colors.blue;
        break;
      default:
        color = Colors.orange;
    }

    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDoctorId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by patient name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('appointments')
                  .where('doctorId', isEqualTo: currentDoctorId)
                  .orderBy('dateTime')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No appointments found.'));
                }

                final appointments = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? 'Unknown').toLowerCase();
                  return patientName.contains(_searchQuery);
                }).toList();

                if (appointments.isEmpty) {
                  return const Center(child: Text('No matching results.'));
                }

                return ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final doc = appointments[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final timestamp = data['dateTime'];
                    final dateTime = (timestamp is Timestamp) ? timestamp.toDate() : null;

                    final formattedDate = (dateTime != null)
                        ? DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime)
                        : 'Unknown Date';

                    final note = data['note'] ?? '';
                    final status = data['status'] ?? 'pending';
                    final patientName = data['patientName'] ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(patientName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: $formattedDate'),
                            if (note.isNotEmpty) Text('Note: $note'),
                            const SizedBox(height: 4),
                            _buildStatusChip(status),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _updateStatus(doc, value),
                          itemBuilder: (context) => [
                            if (status != 'confirmed')
                              const PopupMenuItem(
                                  value: 'confirmed', child: Text('Mark as Confirmed')),
                            if (status != 'cancelled')
                              const PopupMenuItem(
                                  value: 'cancelled', child: Text('Mark as Cancelled')),
                          ],
                          icon: const Icon(Icons.more_vert),
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
    );
  }
}
