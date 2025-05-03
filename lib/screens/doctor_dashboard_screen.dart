
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_drawer.dart';
import 'patient_detail_screen.dart';

class DoctorDashboardScreen extends StatelessWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentDoctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Dashboard')),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'patient')
              .where('doctorId', isEqualTo: currentDoctorId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading patients.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final patients = snapshot.data!.docs;

            if (patients.isEmpty) {
              return const Center(child: Text('No assigned patients.'));
            }

            return ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final data = patients[index].data() as Map<String, dynamic>;
                final id = patients[index].id;
                final name = data['name'] ?? 'Unnamed';
                final email = data['email'] ?? 'No email';

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
                            patientId: id,
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
    );
  }
}
