import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/group_model.dart';
import '../models/status_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Future<void> createUserIfNotExists(String name, String uid) async {
    if (uid.isEmpty) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': _auth.currentUser?.email ?? '',
        'phone': '',
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
        await _firestore.collection('users').doc(uid).update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  Stream<List<UserModel>> getUsers() {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Stream<UserModel?> getCurrentUser() {
    final uid = currentUserId;
    if (uid.isEmpty) return const Stream.empty();
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  Future<void> updateProfilePicture(String base64Image) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({'photoUrl': base64Image});
  }

  Future<void> updateName(String name) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({'name': name});
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  // ============ CHATS ============
  Future<String> createOrGetChatRoom(String otherUserId) async {
    final chatId = _generateChatId(currentUserId, otherUserId);
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [currentUserId, otherUserId],
        'isGroup': false,
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

  Future<UserModel?> getOtherUser(String chatId) async {
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (!doc.exists) return null;
    final participants = List<String>.from(doc.data()?['participants'] ?? []);
    final otherId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    if (otherId.isEmpty) return null;
    return getUserById(otherId);
  }

  // ============ GROUPS ============
  Future<String> createGroup(String name, List<String> members, {String? photoUrl}) async {
    final groupId = _uuid.v4();
    final allMembers = [currentUserId, ...members];
    final user = await getCurrentUser().first;

    await _firestore.collection('groups').doc(groupId).set({
      'id': groupId,
      'name': name,
      'photoUrl': photoUrl,
      'members': allMembers,
      'admins': [currentUserId],
      'createdBy': currentUserId,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _firestore.collection('chats').doc('group_$groupId').set({
      'participants': allMembers,
      'isGroup': true,
      'groupName': name,
      'groupPhoto': photoUrl,
      'lastMessage': 'Group created by ${user?.name ?? "Someone"}',
      'lastMessageTime': DateTime.now().toIso8601String(),
      'lastMessageSender': currentUserId,
    });

    return 'group_$groupId';
  }

  Stream<List<GroupModel>> getGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GroupModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addMemberToGroup(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
    await _firestore.collection('chats').doc('group_$groupId').update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> updateGroupPhoto(String groupId, String photoUrl) async {
    await _firestore.collection('groups').doc(groupId).update({'photoUrl': photoUrl});
    await _firestore.collection('chats').doc('group_$groupId').update({'groupPhoto': photoUrl});
  }

  // ============ STATUS ============
  Future<void> uploadTextStatus(String text) async {
    final user = await getCurrentUser().first;
    if (user == null) return;
    final id = _uuid.v4();
    final now = DateTime.now();
    await _firestore.collection('statuses').doc(id).set({
      'id': id,
      'userId': currentUserId,
      'userName': user.name,
      'userPhoto': user.photoUrl,
      'type': 'text',
      'text': text,
      'timestamp': now.toIso8601String(),
      'expiresAt': now.add(const Duration(hours: 24)).toIso8601String(),
      'viewers': [],
    });
  }

  Future<void> uploadImageUrlStatus(String url) async {
    final user = await getCurrentUser().first;
    if (user == null) return;
    final id = _uuid.v4();
    final now = DateTime.now();
    await _firestore.collection('statuses').doc(id).set({
      'id': id,
      'userId': currentUserId,
      'userName': user.name,
      'userPhoto': user.photoUrl,
      'type': 'image',
      'text': '',
      'imageUrl': url,
      'timestamp': now.toIso8601String(),
      'expiresAt': now.add(const Duration(hours: 24)).toIso8601String(),
      'viewers': [],
    });
  }

  Future<void> uploadVideoUrlStatus(String url) async {
    final user = await getCurrentUser().first;
    if (user == null) return;
    final id = _uuid.v4();
    final now = DateTime.now();
    await _firestore.collection('statuses').doc(id).set({
      'id': id,
      'userId': currentUserId,
      'userName': user.name,
      'userPhoto': user.photoUrl,
      'type': 'video',
      'text': '',
      'videoUrl': url,
      'timestamp': now.toIso8601String(),
      'expiresAt': now.add(const Duration(hours: 24)).toIso8601String(),
      'viewers': [],
    });
  }

  Stream<List<StatusModel>> getStatuses() {
    return _firestore
        .collection('statuses')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StatusModel.fromMap(doc.data(), doc.id))
            .where((s) => !s.isExpired)
            .toList());
  }

  Stream<List<StatusModel>> getMyStatuses() {
    return _firestore
        .collection('statuses')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StatusModel.fromMap(doc.data(), doc.id))
            .where((s) => !s.isExpired)
            .toList());
  }

  Future<void> markStatusViewed(String statusId) async {
    await _firestore.collection('statuses').doc(statusId).update({
      'viewers': FieldValue.arrayUnion([currentUserId]),
    });
  }

  Future<void> deleteStatus(String statusId) async {
    await _firestore.collection('statuses').doc(statusId).delete();
  }

  // ============ MESSAGES ============
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

  Future<void> sendImageUrlMessage(String chatId, String url) async {
    await _sendMessageData(chatId, {
      'senderId': currentUserId,
      'text': '',
      'type': 'image',
      'imageUrl': url,
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    }, '📷 Photo');
  }

  Future<void> sendVideoUrlMessage(String chatId, String url) async {
    await _sendMessageData(chatId, {
      'senderId': currentUserId,
      'text': '',
      'type': 'video',
      'videoUrl': url,
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    }, '🎥 Video');
  }

  Future<void> sendFileUrlMessage(String chatId, String fileName, String url) async {
    await _sendMessageData(chatId, {
      'senderId': currentUserId,
      'text': '',
      'type': 'file',
      'fileName': fileName,
      'fileData': url,
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    }, '📎 $fileName');
  }

  Future<void> _sendMessageData(String chatId, Map<String, dynamic> data, String previewText) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').add(data);
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
        .map((snapshot) => snapshot.docs.map((doc) => MessageModel.fromMap(doc.data(), doc.id)).toList());
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
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
  }

  Future<void> forwardMessage(MessageModel msg, List<String> userIds) async {
    for (var uid in userIds) {
      final chatId = await createOrGetChatRoom(uid);
      if (msg.type == 'image' && msg.imageUrl != null) {
        await sendImageUrlMessage(chatId, msg.imageUrl!);
      } else if (msg.type == 'video' && msg.videoUrl != null) {
        await sendVideoUrlMessage(chatId, msg.videoUrl!);
      } else if (msg.type == 'file' && msg.fileName != null && msg.fileData != null) {
        await sendFileUrlMessage(chatId, msg.fileName!, msg.fileData!);
      } else {
        await sendMessage(chatId, msg.text);
      }
    }
  }

  Future<void> signOut() async {
    await updateOnlineStatus(false);
    await _auth.signOut();
  }
}
