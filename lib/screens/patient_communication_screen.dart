import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class PatientCommunicationScreen extends StatelessWidget {
  const PatientCommunicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in.')),
      );
    }

    final userDoc = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    return FutureBuilder<DocumentSnapshot>(
      future: userDoc.get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('User data not found.')));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final doctorId = userData['doctorId'];
        if (doctorId == null || doctorId.isEmpty) {
          return const Scaffold(body: Center(child: Text('No assigned doctor found.')));
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(doctorId).get(),
          builder: (context, doctorSnap) {
            if (!doctorSnap.hasData || !doctorSnap.data!.exists) {
              return const Scaffold(body: Center(child: Text('Assigned doctor not found.')));
            }

            final doctorData = doctorSnap.data!.data() as Map<String, dynamic>;
            final doctorName = doctorData['name'] ?? 'Doctor';
            final chatId = currentUser.uid.hashCode <= doctorId.hashCode
                ? '${currentUser.uid}_$doctorId'
                : '${doctorId}_${currentUser.uid}';

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(chatId)
                  .collection('chats')
                  .where('receiverId', isEqualTo: currentUser.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, unreadSnap) {
                final unreadCount = unreadSnap.data?.docs.length ?? 0;

                return Scaffold(
                  appBar: AppBar(title: const Text('Your Doctor')),
                  body: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(doctorName),
                    subtitle: Text(doctorData['email'] ?? ''),
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
                            patientId: currentUser.uid,
                            doctorId: doctorId,
                            patientName: doctorName,
                            isPatient: true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
