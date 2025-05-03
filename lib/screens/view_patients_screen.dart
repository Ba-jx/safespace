import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_drawer.dart';
import 'patient_detail_screen.dart';

class ViewPatientsScreen extends StatefulWidget {
  const ViewPatientsScreen({super.key});

  @override
  State<ViewPatientsScreen> createState() => _ViewPatientsScreenState();
}

class _ViewPatientsScreenState extends State<ViewPatientsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Assigned Patients')),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'patient')
                    .where('doctorId', isEqualTo: doctorId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading patients.'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No assigned patients.'));
                  }

                  final patients = snapshot.data!.docs.where((doc) {
                    final name = (doc['name'] ?? '').toString().toLowerCase();
                    final email = (doc['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();

                  if (patients.isEmpty) {
                    return const Center(child: Text('No matching patients found.'));
                  }

                  return ListView.builder(
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final data = patients[index].data() as Map<String, dynamic>;
                      final patientId = patients[index].id;
                      final name = data['name'] ?? 'No Name';
                      final email = data['email'] ?? 'No Email';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(name),
                          subtitle: Text(email),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PatientDetailScreen(
                                  patientId: patientId,
                                  name: name,
                                  email: email,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
