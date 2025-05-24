import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  }

  String _getChatId(String user1, String user2) =>
      user1.hashCode <= user2.hashCode ? '${user1}_$user2' : '${user2}_$user1';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markMessageAsRead(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    if (data['receiverId'] == currentUserId && data['isRead'] == false) {
      await doc.reference.update({'isRead': true});
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final timestamp = msg['timestamp'] as Timestamp?;
    final timeText = timestamp != null
        ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple[300] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg['message'] ?? '',
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      msg['isRead'] == true ? Icons.done_all : Icons.check,
                      size: 14,
                      color:
                          msg['isRead'] == true ? Colors.white : Colors.white60,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName)),
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                _scrollToBottom();

                DateTime? lastDate;

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final msg = doc.data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == currentUserId;

                    final timestamp =
                        (msg['timestamp'] as Timestamp?)?.toDate();
                    final showDateDivider = timestamp != null &&
                        (lastDate == null ||
                            timestamp.day != lastDate!.day ||
                            timestamp.month != lastDate!.month ||
                            timestamp.year != lastDate!.year);
                    if (timestamp != null) lastDate = timestamp;

                    _markMessageAsRead(doc);

                    return Column(
                      children: [
                        if (showDateDivider)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              DateFormat.yMMMMd().format(timestamp),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        _buildMessageBubble(msg, isMe),
                      ],
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                   child: TextField(
  controller: _controller,
  style: TextStyle(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white,
  ),
  decoration: InputDecoration(
    hintText: 'Type your message...',
    hintStyle: TextStyle(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.black45
          : Colors.white54,
    ),
    border: InputBorder.none,
  ),
  onSubmitted: (_) => _sendMessage(),
),

                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
