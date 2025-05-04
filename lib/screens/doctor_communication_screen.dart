import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
              final patientId = patient.id;
              final chatId = doctorId.hashCode <= patientId.hashCode
                  ? '${doctorId}$patientId'
                  : '${patientId}$doctorId';

              final unreadStream = FirebaseFirestore.instance
                  .collection('messages')
                  .doc(chatId)
                  .collection('chats')
                  .where('receiverId', isEqualTo: doctorId)
                  .where('isRead', isEqualTo: false)
                  .snapshots();

              return StreamBuilder<QuerySnapshot>(
                stream: unreadStream,
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data?.docs.length ?? 0;

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(patient['name']),
                    subtitle: Text(patient['email']),
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
                            patientName: patient['name'],
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
