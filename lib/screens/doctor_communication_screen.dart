import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class DoctorCommunicationScreen extends StatelessWidget {
  const DoctorCommunicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Communicate with Patients')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('doctorId', isEqualTo: doctorId)
            .where('role', isEqualTo: 'patient')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading patients'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No assigned patients'));
          }

          final patients = snapshot.data!.docs;

          return ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              final patientName = patient['name'];
              final patientEmail = patient['email'];
              final patientId = patient.id;

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(patientName),
                subtitle: Text(patientEmail),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        patientId: patientId,
                        doctorId: doctorId,
                        patientName: patientName,
                        isPatient: false, // doctor is the sender
                      ),
                    ),
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
