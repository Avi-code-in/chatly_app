import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'call_screen.dart'; 

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverEmail; // Phone ki jagah Email
  final String? receiverPhoto;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverEmail,
    this.receiverPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _initiateCall(String type) {
    String uniqueCallId = "${currentUid}_${widget.receiverId}_${DateTime.now().millisecondsSinceEpoch}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          callId: uniqueCallId,
          otherUserId: widget.receiverId,
          otherUserName: widget.receiverName,
          otherUserEmail: widget.receiverEmail, // Email pass ho rahi hai
          otherUserPhoto: widget.receiverPhoto,
          callType: type, 
          isCaller: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: widget.receiverPhoto != null 
                  ? CachedNetworkImageProvider(widget.receiverPhoto!) 
                  : null,
              child: widget.receiverPhoto == null 
                  ? const Icon(Icons.person, color: Colors.blue) 
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Online", 
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Color(0xFF4A90E2)),
            onPressed: () => _initiateCall('voice'),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Color(0xFF4A90E2)),
            onPressed: () => _initiateCall('video'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Text("Messages will appear here...", style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
