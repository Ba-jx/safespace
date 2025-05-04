import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String patientId;
  final String doctorId;
  final String peerName;
  final bool isPatient;

  const ChatScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
    required this.peerName,
    required this.isPatient,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final String currentUserId;
  late final String chatId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    chatId = _getChatId(widget.patientId, widget.doctorId);
    _markMessagesAsRead();
  }

  String _getChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode ? '${user1}$user2' : '${user2}$user1';
  }

  Future<void> _markMessagesAsRead() async {
    final unread = await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final message = {
      'senderId': currentUserId,
      'receiverId': widget.isPatient ? widget.doctorId : widget.patientId,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .add(message);

    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(chatId)
                  .collection('chats')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages found.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.purple[200] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['message'] ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (isMe && msg['isRead'] == true)
                              const Text(
                                'Read',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
