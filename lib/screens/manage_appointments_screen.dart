import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  State<ManageAppointmentsScreen> createState() =>
      _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  List<Map<String, dynamic>> _allAppointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    final appointments = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'docId': doc.id,
        'ref': doc.reference,
        ...data,
      };
    }).toList();

    setState(() {
      _allAppointments = appointments;
      _filteredAppointments = appointments;
    });
  }

  void _filterAppointments(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredAppointments = _allAppointments.where((appt) {
        final name =
            (appt['patientName'] ?? 'Unknown').toString().toLowerCase();
        return name.contains(_searchQuery);
      }).toList();
    });
  }

  Future<void> _updateStatus(
      Map<String, dynamic> appt, String newStatus) async {
    await appt['ref'].update({'status': newStatus});
    await _loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _filterAppointments,
              decoration: InputDecoration(
                hintText: 'Search by patient name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredAppointments.isEmpty
                ? const Center(child: Text('No appointments found.'))
                : ListView.builder(
                    itemCount: _filteredAppointments.length,
                    itemBuilder: (context, index) {
                      final appt = _filteredAppointments[index];
                      final dateTime =
                          (appt['dateTime'] as Timestamp).toDate();
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(appt['patientName'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Date: ${DateFormat.yMMMEd().add_jm().format(dateTime)}'),
                              if ((appt['note'] ?? '').isNotEmpty)
                                Text('Note: ${appt['note']}'),
                              Text('Status: ${appt['status']}'),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) =>
                                _updateStatus(appt, value),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              const PopupMenuItem(
                                value: 'confirmed',
                                child: Text('Confirmed'),
                              ),
                              const PopupMenuItem(
                                value: 'completed',
                                child: Text('Completed'),
                              ),
                              const PopupMenuItem(
                                value: 'cancelled',
                                child: Text('Cancelled'),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
