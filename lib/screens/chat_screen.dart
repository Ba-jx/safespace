@override
Widget build(BuildContext context) {
  return Scaffold(
    resizeToAvoidBottomInset: true,
    appBar: AppBar(title: Text(widget.peerName)),
    body: SafeArea(
      child: Stack(
        children: [
          Column(
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

                        final timestamp = (msg['timestamp'] as Timestamp?)?.toDate();
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
                          autofocus: true,
                          onTap: _scrollToBottom,
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
          ),

          // ✅ Floating menu positioned above keyboard
          Positioned(
            left: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 80, // pushes FAB above keyboard
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 4,
              onPressed: () {
                // open drawer or additional options
              },
              child: const Icon(Icons.menu),
            ),
          ),
        ],
      ),
    ),
  );
}
