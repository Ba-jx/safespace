
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
              final patientId = patient.id;

              final chatId = doctorId.hashCode <= patientId.hashCode
                  ? '${doctorId}_$patientId'
                  : '${patientId}_$doctorId';

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('messages')
                    .doc(chatId)
                    .collection('chats')
                    .where('receiverId', isEqualTo: doctorId)
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, unreadSnapshot) {
                  int unreadCount = unreadSnapshot.data?.docs.length ?? 0;

                  return ListTile(
                    title: Text(patientName),
                    subtitle: Text(patient['email']),
                    leading: const Icon(Icons.person),
                    trailing: unreadCount > 0
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            patientId: patientId,
                            doctorId: doctorId,
                            patientName: patientName,
                            isPatient: false,
                          ),
                        ),
                      );
                    },
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
