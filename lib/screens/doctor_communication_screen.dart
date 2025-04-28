import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_drawer.dart';

class DoctorCommunicationScreen extends StatefulWidget {
  const DoctorCommunicationScreen({super.key});

  @override
  State<DoctorCommunicationScreen> createState() =>
      _DoctorCommunicationScreenState();
}

class _DoctorCommunicationScreenState extends State<DoctorCommunicationScreen> {
  final TextEditingController _messageController = TextEditingController();

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance.collection('chat_messages').add({
      'sender': 'patient',
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Communication')),
      drawer: const CustomDrawer(),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('chat_messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isPatient = msg['sender'] == 'patient';
                    return Align(
                      alignment:
                          isPatient
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isPatient ? Colors.purple[100] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(msg['message']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
