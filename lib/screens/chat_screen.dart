import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final bool isPatient;

  const ChatScreen({super.key, required this.isPatient});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  String? selectedPeerId;
  String? selectedPeerName;
  String get chatId => _getChatId(currentUserId, selectedPeerId!);

  String _getChatId(String user1, String user2) =>
      user1.hashCode <= user2.hashCode ? '$user1$user2' : '$user2$user1';

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || selectedPeerId == null) return;

    await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .add({
      'senderId': currentUserId,
      'receiverId': selectedPeerId,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

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

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: widget.isPatient ? 'doctor' : 'patient')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final users = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          itemCount: users.length,
          itemBuilder: (context, index) {
            final peer = users[index];
            final peerId = peer.id;
            final peerName = peer['name'] ?? 'No Name';
            final id = _getChatId(currentUserId, peerId);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(id)
                  .collection('chats')
                  .where('receiverId', isEqualTo: currentUserId)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, unreadSnapshot) {
                final unreadCount = unreadSnapshot.data?.docs.length ?? 0;

                return ListTile(
                  onTap: () {
                    setState(() {
                      selectedPeerId = peerId;
                      selectedPeerName = peerName;
                    });
                  },
                  leading: CircleAvatar(child: Text(peerName[0])),
                  title: Text(peerName),
                  trailing: unreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatMessages() {
    return Column(
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
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedPeerName == null ? "Chats" : selectedPeerName!),
        leading: selectedPeerId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedPeerId = null;
                    selectedPeerName = null;
                  });
                },
              )
            : null,
      ),
      body: selectedPeerId == null
          ? _buildChatList()
          : _buildChatMessages(),
    );
  }
}
