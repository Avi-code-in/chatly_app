import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> sendMessage(String receiverId, String message, String chatId) async {
    // 1. Send actual message
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUid,
      'receiverId': receiverId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'isAutoReply': false,
    });

    // 2. Update Last Message in Chat List
    await _db.collection('chats').doc(chatId).set({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Check for Auto-Reply
    DocumentSnapshot receiverDoc = await _db.collection('users').doc(receiverId).get();
    if (receiverDoc.exists) {
      var data = receiverDoc.data() as Map<String, dynamic>;
      if (data['autoReplyEnabled'] == true) {
        // Delay for realism (2 seconds)
        await Future.delayed(const Duration(seconds: 2));
        
        await _db.collection('chats').doc(chatId).collection('messages').add({
          'senderId': receiverId, // Receiving user sends this
          'receiverId': currentUid,
          'message': data['autoReplyMessage'],
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'sent',
          'isAutoReply': true, // UI me bot badge dikhane ke liye
        });
      }
    }
  }
}
