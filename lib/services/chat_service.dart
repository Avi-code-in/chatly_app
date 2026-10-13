import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<void> createUserIfNotExistsWithPhone(String name, String phone) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'phone': phone,
        'email': '',
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

  // 🔥 Sirf contacts mein wale users dikhao
  Future<List<UserModel>> getContactsOnly() async {
    final uid = currentUserId;
    if (uid.isEmpty) return [];

    try {
      // Permission maango
      final permission = await FlutterContacts.requestPermission();
      if (!permission) return [];

      // Phone ke contacts uthao
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Saare phone numbers nikalo
      final phoneNumbers = <String>[];
      for (var c in contacts) {
        for (var p in c.phones) {
          final cleaned = p.number.replaceAll(RegExp(r'[^\d]'), '');
          if (cleaned.length >= 10) {
            phoneNumbers.add(cleaned.substring(cleaned.length - 10));
          }
        }
      }

      if (phoneNumbers.isEmpty) return [];

      // Firestore se matching users dhundho
      final usersSnapshot =
          await _firestore.collection('users').get();

      final matchedUsers = <UserModel>[];
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final userPhone = (data['phone'] ?? '').toString();
        final cleaned = userPhone.replaceAll(RegExp(r'[^\d]'), '');
        final last10 = cleaned.length >= 10
            ? cleaned.substring(cleaned.length - 10)
            : cleaned;

        if (last10.isNotEmpty &&
            phoneNumbers.contains(last10) &&
            data['uid'] != uid) {
          matchedUsers.add(UserModel.fromMap(data));
        }
      }

      return matchedUsers;
    } catch (e) {
      debugPrint('Contacts error: $e');
      return [];
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

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
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

  Stream<UserModel?> getUserStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .asyncMap((chatDoc) async {
      if (!chatDoc.exists) return null;
      final participants =
          List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      if (otherId.isEmpty) return null;
      final userDoc =
          await _firestore.collection('users').doc(otherId).get();
      if (!userDoc.exists) return null;
      return UserModel.fromMap(userDoc.data()!);
    });
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
