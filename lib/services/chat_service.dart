import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
    await saveFcmToken();
  }

  Future<void> saveFcmToken() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _firestore.collection('users').doc(uid).update({
          'fcmToken': newToken,
        });
      });
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  Future<void> updateProfilePicture(String base64Image) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'photoUrl': base64Image,
    });
  }

  Future<void> updateName(String name) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({'name': name});
  }

  Stream<UserModel?> getCurrentUser() {
    final uid = currentUserId;
    if (uid.isEmpty) return const Stream.empty();
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  Stream<List<UserModel>> getUsers() {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .toList());
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<String> createOrGetChatRoom(String otherUserId) async {
    final chatId = _generateChatId(currentUserId, otherUserId);
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [currentUserId, otherUserId],
        'lastMessage': '',
        'lastMessageTime': DateTime.now().toIso8601String(),
        'lastMessageSender': '',
      });
    }
    return chatId;
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<Map<String, dynamic>>> getChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final chats = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['chatId'] = doc.id;
        chats.add(data);
      }
      chats.sort((a, b) {
        final aTime = (a['lastMessageTime'] ?? '').toString();
        final bTime = (b['lastMessageTime'] ?? '').toString();
        return bTime.compareTo(aTime);
      });
      return chats;
    });
  }

  // Text message
  Future<void> sendMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    await _sendMessageData(chatId, {
      'senderId': currentUserId,
      'text': text.trim(),
      'type': 'text',
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    }, text.trim());
  }

  // Image message (base64)
  Future<void> sendImageMessage(String chatId, String base64Image) async {
    await _sendMessageData(chatId, {
      'senderId': currentUserId,
      'text': '',
      'type': 'image',
      'imageData': base64Image,
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    }, '📷 Photo');
  }

  // File message
  Future<void> sendFileMessage(
      String chatId, String fileName, String base64File) async {
    await _sendMessageData(chatId, {
      'senderId': currentUserId,
      'text': '',
      'type': 'file',
      'fileName': fileName,
      'fileData': base64File,
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    }, '📎 $fileName');
  }

  Future<void> _sendMessageData(String chatId,
      Map<String, dynamic> data, String previewText) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(data);

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': previewText,
      'lastMessageTime': DateTime.now().toIso8601String(),
      'lastMessageSender': currentUserId,
    });
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> markMessagesAsSeen(String chatId) async {
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('seen', isEqualTo: false)
        .get();
    for (var doc in messages.docs) {
      await doc.reference.update({'seen': true});
    }
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
    return getUserById(otherId);
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
