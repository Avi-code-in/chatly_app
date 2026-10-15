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

  // ============ USER ============
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

  // Search by username (returns all matching users - for discovery)
  Future<List<UserModel>> searchUsersByUsername(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    final snap = await _firestore
        .collection('users')
        .orderBy('username')
        .startAt([q])
        .endAt(['${q}\uf8ff'])
        .limit(20)
        .get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .where((u) => u.uid != currentUserId)
        .toList();
  }

  // Get my personal space (contacts only)
  Stream<List<UserModel>> getMySpaceUsers() {
    final uid = currentUserId;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .snapshots()
        .asyncMap((snap) async {
      final users = <UserModel>[];
      for (var doc in snap.docs) {
        final u = await getUserById(doc.id);
        if (u != null) users.add(u);
      }
      return users;
    });
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
      'description': '',
      'photoUrl': photoUrl,
      'members': allMembers,
      'admins': [currentUserId],
      'createdBy': currentUserId,
      'membersCanAdd': true,
      'membersCanSend': true,
      'membersCanEditInfo': false,
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

  Future<GroupModel?> getGroupById(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return GroupModel.fromMap(doc.data()!, groupId);
  }

  Future<void> addMemberToGroup(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
    await _firestore.collection('chats').doc('group_$groupId').update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
      'admins': FieldValue.arrayRemove([userId]),
    });
    await _firestore.collection('chats').doc('group_$groupId').update({
      'participants': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> leaveGroup(String groupId) async {
    await removeMemberFromGroup(groupId, currentUserId);
  }

  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).delete();
    await _firestore.collection('chats').doc('group_$groupId').delete();
  }

  Future<void> promoteToAdmin(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> demoteFromAdmin(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> updateGroupPhoto(String groupId, String photoUrl) async {
    await _firestore.collection('groups').doc(groupId).update({'photoUrl': photoUrl});
    await _firestore.collection('chats').doc('group_$groupId').update({'groupPhoto': photoUrl});
  }

  Future<void> updateGroupDescription(String groupId, String description) async {
    await _firestore.collection('groups').doc(groupId).update({'description': description});
  }

  Future<void> updateGroupSettings(String groupId,
      {bool? membersCanAdd, bool? membersCanSend, bool? membersCanEditInfo}) async {
    final updates = <String, dynamic>{};
    if (membersCanAdd != null) updates['membersCanAdd'] = membersCanAdd;
    if (membersCanSend != null) updates['membersCanSend'] = membersCanSend;
    if (membersCanEditInfo != null) updates['membersCanEditInfo'] = membersCanEditInfo;
    if (updates.isNotEmpty) {
      await _firestore.collection('groups').doc(groupId).update(updates);
    }
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
    return _firestore.collection('statuses').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => StatusModel.fromMap(doc.data(), doc.id))
          .where((s) => !s.isExpired)
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<StatusModel>> getMyStatuses() {
    return _firestore
        .collection('statuses')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => StatusModel.fromMap(doc.data(), doc.id))
          .where((s) => !s.isExpired)
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
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

  Future<void> sendReplyMessage(String chatId, String text,
      {required String replyToId, required String replyToText, required String replyToSender}) async {
    if (text.trim().isEmpty) return;
    await _sendMessageData(chatId, {
      'senderId': currentUserId,
      'text': text.trim(),
      'type': 'text',
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
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

  Future<void> sendVoiceMessage(String chatId, String voiceUrl, int duration, String? transcribedText) async {
    final data = <String, dynamic>{
      'senderId': currentUserId,
      'text': '',
      'type': 'voice',
      'voiceUrl': voiceUrl,
      'voiceDuration': duration,
      'transcribedText': transcribedText,
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    };
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final disappearingHours = chatDoc.data()?['disappearingHours'] as int?;
    if (disappearingHours != null) {
      data['expiresAt'] = DateTime.now().add(Duration(hours: disappearingHours)).toIso8601String();
    }
    await _sendMessageData(chatId, data, '🎤 Voice message');
  }

  Future<void> sendLocationMessage(String chatId, double lat, double lng, String? address,
      {bool isLive = false, Duration? liveDuration}) async {
    final data = <String, dynamic>{
      'senderId': currentUserId,
      'text': '',
      'type': 'location',
      'latitude': lat,
      'longitude': lng,
      'locationAddress': address,
      'isLiveLocation': isLive,
      'timestamp': DateTime.now().toIso8601String(),
      'seen': false,
    };
    if (isLive && liveDuration != null) {
      data['liveLocationExpiresAt'] = DateTime.now().add(liveDuration).toIso8601String();
    }
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final disappearingHours = chatDoc.data()?['disappearingHours'] as int?;
    if (disappearingHours != null) {
      data['expiresAt'] = DateTime.now().add(Duration(hours: disappearingHours)).toIso8601String();
    }
    await _sendMessageData(chatId, data, isLive ? '📍 Live location' : '📍 Location');
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

  // ============ REACTIONS & STAR ============
  Future<void> addReaction(String chatId, String messageId, String emoji) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    final docRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final reactions = Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    reactions.forEach((key, value) {
      final list = List<String>.from(value);
      list.remove(uid);
      if (list.isEmpty) {
        reactions.remove(key);
      } else {
        reactions[key] = list;
      }
    });
    if (reactions[emoji] == null) {
      reactions[emoji] = [uid];
    } else {
      final list = List<String>.from(reactions[emoji]);
      if (!list.contains(uid)) list.add(uid);
      reactions[emoji] = list;
    }
    await docRef.update({'reactions': reactions});
  }

  Future<void> removeReaction(String chatId, String messageId) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    final docRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final reactions = Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    reactions.forEach((key, value) {
      final list = List<String>.from(value);
      list.remove(uid);
      if (list.isEmpty) {
        reactions.remove(key);
      } else {
        reactions[key] = list;
      }
    });
    await docRef.update({'reactions': reactions});
  }

  Future<void> toggleStar(String chatId, String messageId) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    final docRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final starred = List<String>.from(doc.data()?['starredBy'] ?? []);
    if (starred.contains(uid)) {
      starred.remove(uid);
    } else {
      starred.add(uid);
    }
    await docRef.update({'starredBy': starred});
  }

  // ============ DISAPPEARING ============
  Future<void> setDisappearingMessages(String chatId, int? hours) async {
    if (hours == null) {
      await _firestore.collection('chats').doc(chatId).update({'disappearingHours': FieldValue.delete()});
    } else {
      await _firestore.collection('chats').doc(chatId).update({'disappearingHours': hours});
    }
  }

  Stream<int?> getDisappearingHours(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) => doc.data()?['disappearingHours'] as int?);
  }

  Future<void> deleteExpiredMessages(String chatId) async {
    final now = DateTime.now().toIso8601String();
    try {
      final expired = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('expiresAt', isLessThan: now)
          .get();
      for (var doc in expired.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  // ============ CHAT LOCK ============
  Future<void> lockChat(String chatId, bool locked) async {
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid).collection('locked_chats').doc(chatId).set({
      'locked': locked,
      'lockedAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<bool> isChatLocked(String chatId) {
    final uid = currentUserId;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('locked_chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.data()?['locked'] ?? false);
  }

  // ============ SCHEDULED ============
  Future<void> scheduleMessage(String chatId, String text, DateTime scheduledAt) async {
    final uid = currentUserId;
    final id = _uuid.v4();
    await _firestore.collection('scheduled_messages').doc(id).set({
      'id': id,
      'chatId': chatId,
      'senderId': uid,
      'text': text,
      'scheduledAt': scheduledAt.toIso8601String(),
      'isSent': false,
    });
  }

  // ============ CONTACT TAGS ============
  Future<String> createTag(String name, String color, List<String> userIds) async {
    final uid = currentUserId;
    final id = _uuid.v4();
    await _firestore.collection('users').doc(uid).collection('tags').doc(id).set({
      'id': id,
      'name': name,
      'color': color,
      'userIds': userIds,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Stream<List<Map<String, dynamic>>> getTags() {
    final uid = currentUserId;
    return _firestore.collection('users').doc(uid).collection('tags').snapshots().map((s) => s.docs.map((d) => d.data()).toList());
  }

  Future<void> deleteTag(String tagId) async {
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid).collection('tags').doc(tagId).delete();
  }

  // ============ BROADCAST ============
  Future<String> createBroadcast(String name, List<String> receiverIds) async {
    final uid = currentUserId;
    final id = _uuid.v4();
    await _firestore.collection('users').doc(uid).collection('broadcasts').doc(id).set({
      'id': id,
      'name': name,
      'receiverIds': receiverIds,
      'lastMessage': '',
      'createdAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Stream<List<Map<String, dynamic>>> getBroadcasts() {
    final uid = currentUserId;
    return _firestore.collection('users').doc(uid).collection('broadcasts').snapshots().map((s) => s.docs.map((d) => d.data()).toList());
  }

  Future<void> sendBroadcast(String broadcastId, String message) async {
    final uid = currentUserId;
    final doc = await _firestore.collection('users').doc(uid).collection('broadcasts').doc(broadcastId).get();
    if (!doc.exists) return;
    final receiverIds = List<String>.from(doc.data()?['receiverIds'] ?? []);
    for (var rid in receiverIds) {
      final chatId = await createOrGetChatRoom(rid);
      await sendMessage(chatId, message);
    }
    await _firestore.collection('users').doc(uid).collection('broadcasts').doc(broadcastId).update({
      'lastMessage': message,
      'lastMessageTime': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteBroadcast(String broadcastId) async {
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid).collection('broadcasts').doc(broadcastId).delete();
  }

  // ============ AUTO-REPLY ============
  Future<void> saveAutoReply({
    required String message,
    required bool enabled,
    required bool onlyOutsideHours,
    required int startHour,
    required int endHour,
  }) async {
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid).update({
      'autoReply': {
        'message': message,
        'enabled': enabled,
        'onlyOutsideHours': onlyOutsideHours,
        'startHour': startHour,
        'endHour': endHour,
        'updatedAt': DateTime.now().toIso8601String(),
      }
    });
  }

  Stream<Map<String, dynamic>?> getAutoReply() {
    final uid = currentUserId;
    return _firestore.collection('users').doc(uid).snapshots().map((d) => d.data()?['autoReply'] as Map<String, dynamic>?);
  }

  // ============ BACKUP ============
  Future<void> saveBackupMetadata() async {
    final uid = currentUserId;
    final chats = await _firestore.collection('chats').where('participants', arrayContains: uid).get();
    int totalMessages = 0;
    for (var chat in chats.docs) {
      final msgs = await _firestore.collection('chats').doc(chat.id).collection('messages').get();
      totalMessages += msgs.docs.length;
    }
    await _firestore.collection('users').doc(uid).update({
      'backup': {
        'lastBackup': DateTime.now().toIso8601String(),
        'totalChats': chats.docs.length,
        'totalMessages': totalMessages,
      }
    });
  }

  Stream<Map<String, dynamic>?> getBackupInfo() {
    final uid = currentUserId;
    return _firestore.collection('users').doc(uid).snapshots().map((d) => d.data()?['backup'] as Map<String, dynamic>?);
  }

  // ============ AUTH ============
  Future<void> signOut() async {
    await updateOnlineStatus(false);
    await _auth.signOut();
  }
}

// ============ SAFETY & PRIVACY EXTENSION ============
extension ChatServiceSafety on ChatService {
  // --- USERNAME ---
  Future<bool> isUsernameAvailable(String username) async {
    final snap = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  Future<void> setUsername(String username) async {
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid).update({
      'username': username.toLowerCase().trim(),
    });
  }

  Future<UserModel?> searchByUsername(String username) async {
    final snap = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromMap(snap.docs.first.data());
  }

  // --- CONTACT REQUESTS ---
  Future<void> sendContactRequest(String toUid, String message) async {
    final uid = currentUserId;
    final user = await getCurrentUser().first;
    if (user == null) return;

    // Check if request already exists
    final existing = await _firestore
        .collection('contact_requests')
        .where('fromUid', isEqualTo: uid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) return;

    final id = _uuid.v4();
    await _firestore.collection('contact_requests').doc(id).set({
      'id': id,
      'fromUid': uid,
      'fromName': user.name,
      'fromUsername': user.username,
      'fromPhoto': user.photoUrl,
      'toUid': toUid,
      'message': message,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<Map<String, dynamic>>> getIncomingRequests() {
    final uid = currentUserId;
    return _firestore
        .collection('contact_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => d.data()).toList();
      list.sort((a, b) =>
          (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
      return list;
    });
  }

  Stream<int> getPendingRequestCount() {
    return getIncomingRequests().map((l) => l.length);
  }

  Future<void> acceptContactRequest(String requestId, String fromUid) async {
    await _firestore
        .collection('contact_requests')
        .doc(requestId)
        .update({'status': 'accepted'});
    // Add to contacts
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid).collection('contacts').doc(fromUid).set({
      'uid': fromUid,
      'addedAt': DateTime.now().toIso8601String(),
    });
    await _firestore.collection('users').doc(fromUid).collection('contacts').doc(uid).set({
      'uid': uid,
      'addedAt': DateTime.now().toIso8601String(),
    });
    // Create chat room
    await createOrGetChatRoom(fromUid);
  }

  Future<void> rejectContactRequest(String requestId) async {
    await _firestore
        .collection('contact_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  // --- CONTACTS LIST ---
  Stream<List<String>> getMyContactUids() {
    final uid = currentUserId;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  Future<List<UserModel>> getMyContacts() async {
    final uid = currentUserId;
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .get();
    final list = <UserModel>[];
    for (var doc in snap.docs) {
      final u = await getUserById(doc.id);
      if (u != null) list.add(u);
    }
    return list;
  }

  Future<bool> isContact(String otherUid) async {
    final uid = currentUserId;
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .doc(otherUid)
        .get();
    return doc.exists;
  }

  // --- BLOCK/UNBLOCK ---
  Future<void> blockUser(String otherUid) async {
    final uid = currentUserId;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(otherUid)
        .set({
      'uid': otherUid,
      'blockedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> unblockUser(String otherUid) async {
    final uid = currentUserId;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(otherUid)
        .delete();
  }

  Future<bool> isBlocked(String otherUid) async {
    final uid = currentUserId;
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(otherUid)
        .get();
    return doc.exists;
  }

  Stream<List<String>> getBlockedUids() {
    final uid = currentUserId;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  // --- REPORT ---
  Future<void> reportUser(String otherUid, String reason) async {
    final uid = currentUserId;
    await _firestore.collection('reports').add({
      'reporterUid': uid,
      'reportedUid': otherUid,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // --- PRIVACY SETTINGS ---
  Future<void> updatePrivacySettings({
    String? whoCanMessage,
    String? whoCanSeeProfile,
    bool? readReceipts,
    bool? lastSeenVisible,
  }) async {
    final uid = currentUserId;
    final updates = <String, dynamic>{};
    if (whoCanMessage != null) updates['whoCanMessage'] = whoCanMessage;
    if (whoCanSeeProfile != null) updates['whoCanSeeProfile'] = whoCanSeeProfile;
    if (readReceipts != null) updates['readReceipts'] = readReceipts;
    if (lastSeenVisible != null) updates['lastSeenVisible'] = lastSeenVisible;
    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  // --- CHECK IF CAN MESSAGE ---
  Future<bool> canMessage(String otherUid) async {
    final other = await getUserById(otherUid);
    if (other == null) return false;

    // Blocked check both ways
    if (await isBlocked(otherUid)) return false;
    final uid = currentUserId;
    final otherBlocked = await _firestore
        .collection('users')
        .doc(otherUid)
        .collection('blocked')
        .doc(uid)
        .get();
    if (otherBlocked.exists) return false;

    // Privacy check
    switch (other.whoCanMessage) {
      case 'nobody':
        return false;
      case 'contacts':
        return await isContact(otherUid);
      case 'everyone':
      default:
        return true;
    }
  }
}

// Status only from contacts
Stream<List<StatusModel>> getStatusesFromContacts() {
  final uid = currentUserId;
  return _firestore
      .collection('users')
      .doc(uid)
      .collection('contacts')
      .snapshots()
      .asyncMap((contactSnap) async {
    final contactUids = contactSnap.docs.map((d) => d.id).toList();
    if (contactUids.isEmpty) return <StatusModel>[];
    final statusSnap = await _firestore.collection('statuses').get();
    return statusSnap.docs
        .map((d) => StatusModel.fromMap(d.data(), d.id))
        .where((s) =>
            !s.isExpired &&
            s.userId != uid &&
            contactUids.contains(s.userId))
        .toList();
  });
}
