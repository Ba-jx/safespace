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
    _markMessagesAsRead();
  }

  String _getChatId(String a, String b) =>
      a.hashCode <= b.hashCode ? '${a}_$b' : '${b}_$a';

  Future<void> _markMessagesAsRead() async {
    final messages = await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var msg in messages.docs) {
      msg.reference.update({'isRead': true});
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

  bool _shouldShowDateDivider(DateTime current, DateTime? previous) {
    if (previous == null) return true;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
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
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                DateTime? lastDate;

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == currentUserId;
                    final timestamp = (msg['timestamp'] as Timestamp?)?.toDate();
                    final showDateDivider = timestamp != null && _shouldShowDateDivider(timestamp, lastDate);
                    if (timestamp != null) lastDate = timestamp;

                    return Column(
                      children: [
                        if (showDateDivider && timestamp != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              DateFormat.yMMMMd().format(timestamp),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.purple[300] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg['message'] ?? ''),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      timestamp != null
                                          ? DateFormat.jm().format(timestamp)
                                          : '',
                                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                                    ),
                                    if (isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          msg['isRead'] == true
                                              ? Icons.done_all
                                              : Icons.check,
                                          size: 14,
                                          color: msg['isRead'] == true
                                              ? Colors.deepPurple
                                              : Colors.black45,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
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
