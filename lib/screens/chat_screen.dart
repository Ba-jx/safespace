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
    return user1.hashCode <= user2.hashCode ? '${user1}_$user2' : '${user2}_$user1';
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

    final receiverId = widget.isPatient ? widget.doctorId : widget.patientId;
    await FirebaseFirestore.instance.collection('messages').doc(chatId).set(
      {'typing': false},
      SetOptions(merge: true),
    );

    await FirebaseFirestore.instance.collection('messages').doc(chatId).collection('chats').add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName)),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('messages').doc(chatId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.data() is Map<String, dynamic>) {
                final typing = (snapshot.data!.data() as Map<String, dynamic>)['typing'];
                final showTyping = typing == true && currentUserId != widget.doctorId;
                return showTyping
                    ? const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 4),
                        child: Text('Typing...', style: TextStyle(fontStyle: FontStyle.italic)),
                      )
                    : const SizedBox.shrink();
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(chatId)
                  .collection('chats')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error loading messages'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == currentUserId;
                    final isRead = msg['isRead'] == true;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment:
                            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.purple[200] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(msg['message'] ?? ''),
                          ),
                          if (isMe && isRead)
                            const Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: Text('Read', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                        ],
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
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: (text) {
                      FirebaseFirestore.instance.collection('messages').doc(chatId).set(
                        {'typing': text.isNotEmpty},
                        SetOptions(merge: true),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
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
