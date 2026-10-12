import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<void> createUserIfNotExists(String name) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': _auth.currentUser?.email ?? '',
        'photoUrl': null,
        'isOnline': true,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } else {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': true,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }
  }

  Stream<List<UserModel>> getUsers() {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<String> createOrGetChatRoom(String otherUserId) async {
    final chatId = _generateChatId(currentUserId, otherUserId);
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [currentUserId, otherUserId],
        'lastMessage': '',
        'lastMessageTime': DateTime.now().toIso8601String(),
      });
    }
    return chatId;
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<QuerySnapshot> getChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'text': text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    });

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text.trim(),
      'lastMessageTime': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<UserModel?> getOtherUser(String chatId) async {
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) return null;

    final participants = List<String>.from(doc.data()?['participants'] ?? []);
    final otherId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherId.isEmpty) return null;

    final userDoc = await _firestore.collection('users').doc(otherId).get();
    if (!userDoc.exists) return null;

    return UserModel.fromMap(userDoc.data()!);
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  Future<void> signOut() async {
    await updateOnlineStatus(false);
    await _auth.signOut();
  }
}
