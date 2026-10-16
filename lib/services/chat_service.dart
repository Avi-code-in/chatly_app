import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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

  // ==================== USER ====================

  Future<void> createUserIfNotExists(String name, String uid) async {
    if (uid.isEmpty) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'username': '',
        'email': _auth.currentUser?.email ?? '',
        'phone': '',
        'photoUrl': null,
        'isOnline': true,
        'lastSeen': DateTime.now().toIso8601String(),
        'whoCanMessage': 'contacts',
        'whoCanSeeProfile': 'everyone',
        'readReceipts': true,
        'lastSeenVisible': true,
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

  Future<void> updateProfilePicture(String url) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({'photoUrl': url});
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

  // ==================== USERNAME / SEARCH ====================

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

  // ==================== CONTACTS / PERSONAL SPACE ====================

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

  Stream<List<UserModel>> getUsers() {
    return getMySpaceUsers();
  }

  Future<List<UserModel>> getMyContacts() async {
    final uid = currentUserId;
    final snap = await _firestore.collection('users').doc(uid).collection('contacts').get();
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

  // ==================== CONTACT REQUESTS ====================

  Future<void> sendContactRequest(String toUid, String message) async {
    final uid = currentUserId;
    final user = await getCurrentUser().first;
    if (user == null) return;

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
      list.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
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
    final uid = currentUserId;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .doc(fromUid)
        .set({'uid': fromUid, 'addedAt': DateTime.now().toIso8601String()});
    await _firestore
        .collection('users')
        .doc(fromUid)
        .collection('contacts')
        .doc(uid)
        .set({'uid': uid, 'addedAt': DateTime.now().toIso8601String()});
    await createOrGetChatRoom(fromUid);
  }

  Future<void> rejectContactRequest(String requestId) async {
    await _firestore
        .collection('contact_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  // ==================== BLOCK / REPORT ====================

  Future<void> blockUser(String otherUid) async {
    final uid = currentUserId;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(otherUid)
        .set({'uid': otherUid, 'blockedAt': DateTime.now().toIso8601String()});
  }

  Future<void> unblockUser(String otherUid) async {
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid).collection('blocked').doc(otherUid).delete();
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

  Future<void> reportUser(String otherUid, String reason) async {
    await _firestore.collection('reports').add({
      'reporterUid': currentUserId,
      'reportedUid': otherUid,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ==================== PRIVACY SETTINGS ====================

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

  Future<bool> canMessage(String otherUid) async {
    final other = await getUserById(otherUid);
    if (other == null) return false;
    if (await isBlocked(otherUid)) return false;
    final uid = currentUserId;
    final otherBlocked = await _firestore
        .collection('users')
        .doc(otherUid)
        .collection('blocked')
        .doc(uid)
        .get();
    if (otherBlocked.exists) return false;
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

  // ==================== CHATS ====================

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

  // Get chatId for a contact and ensure chat room exists
  Future<String> openChatWithUser(String otherUserId) async {
    // First add to contacts if not already (for safety)
    return await createOrGetChatRoom(otherUserId);
  }

  String _generateChatId(String u1, String u2) {
    final ids = [u1, u2]..sort();
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
        final aT = (a['lastMessageTime'] ?? '').toString();
        final bT = (b['lastMessageTime'] ?? '').toString();
        return bT.compareTo(aT);
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

  // ==================== GROUPS ====================

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
        .map((s) => s.docs.map((d) => GroupModel.fromMap(d.data(), d.id)).toList());
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

  Future<void> updateGroupName(String groupId, String name) async {
    await _firestore.collection('groups').doc(groupId).update({'name': name});
    await _firestore.collection('chats').doc('group_$groupId').update({'groupName': name});
  }

  Future<void> updateGroupSettings(
    String groupId, {
    bool? membersCanAdd,
    bool? membersCanSend,
    bool? membersCanEditInfo,
  }) async {
    final updates = <String, dynamic>{};
    if (membersCanAdd != null) updates['membersCanAdd'] = membersCanAdd;
    if (membersCanSend != null) updates['membersCanSend'] = membersCanSend;
    if (membersCanEditInfo != null) updates['membersCanEditInfo'] = membersCanEditInfo;
    if (updates.isNotEmpty) {
      await _firestore.collection('groups').doc(groupId).update(updates);
    }
  }

  // ==================== STATUS ====================

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
          .map((d) => StatusModel.fromMap(d.data(), d.id))
          .where((s) => !s.isExpired)
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

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

  Stream<List<StatusModel>> getMyStatuses() {
    return _firestore
        .collection('statuses')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((d) => StatusModel.fromMap(d.data(), d.id))
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

  // ==================== MESSAGES ====================

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
    await _sendMessageData(chatId, data, '🎤 Voice');
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
    await _sendMessageData(chatId, data, isLive ? '📍 Live' : '📍 Location');
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
        .map((s) => s.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList());
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

  // ==================== REACTIONS / STAR ====================

  Future<void> addReaction(String chatId, String messageId, String emoji) async {
    final uid = currentUserId;
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

  // ==================== DISAPPEARING / CHAT LOCK / SCHEDULE ====================

  Future<void> setDisappearingMessages(String chatId, int? hours) async {
    if (hours == null) {
      await _firestore.collection('chats').doc(chatId).update({'disappearingHours': FieldValue.delete()});
    } else {
      await _firestore.collection('chats').doc(chatId).update({'disappearingHours': hours});
    }
  }

  Stream<int?> getDisappearingHours(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((d) => d.data()?['disappearingHours'] as int?);
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

  Future<void> scheduleMessage(String chatId, String text, DateTime scheduledAt) async {
    final id = _uuid.v4();
    await _firestore.collection('scheduled_messages').doc(id).set({
      'id': id,
      'chatId': chatId,
      'senderId': currentUserId,
      'text': text,
      'scheduledAt': scheduledAt.toIso8601String(),
      'isSent': false,
    });
  }

  // ==================== TAGS / BROADCAST / AUTO-REPLY / BACKUP ====================

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

  // ==================== AUTH ====================

  Future<void> signOut() async {
    await updateOnlineStatus(false);
    await _auth.signOut();
  }

  // ==================== FAVOURITE ====================
  Future<void> toggleFavourite(String otherUid) async {
    final uid = currentUserId;
    final doc = await _firestore
        .collection('users').doc(uid)
        .collection('favourites').doc(otherUid).get();
    if (doc.exists) {
      await _firestore.collection('users').doc(uid)
          .collection('favourites').doc(otherUid).delete();
    } else {
      await _firestore.collection('users').doc(uid)
          .collection('favourites').doc(otherUid).set({
        'uid': otherUid,
        'addedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<bool> isFavourite(String otherUid) async {
    final uid = currentUserId;
    final doc = await _firestore.collection('users').doc(uid)
        .collection('favourites').doc(otherUid).get();
    return doc.exists;
  }

  Stream<List<String>> getFavouriteUids() {
    final uid = currentUserId;
    return _firestore.collection('users').doc(uid)
        .collection('favourites').snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  // ==================== PIN LOCK ====================
  Future<void> setChatPin(String chatId, String pin) async {
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid)
        .collection('chat_pins').doc(chatId).set({
      'pin': pin,
      'setAt': DateTime.now().toIso8601String(),
    }).timeout(const Duration(seconds: 5));
  }

  Future<String?> getChatPin(String chatId) async {
    final uid = currentUserId;
    final doc = await _firestore.collection('users').doc(uid)
        .collection('chat_pins').doc(chatId).get();
    if (!doc.exists) return null;
    return doc.data()?['pin'] as String?;
  }

  Future<void> removeChatPin(String chatId) async {
    final uid = currentUserId;
    await _firestore.collection('users').doc(uid)
        .collection('chat_pins').doc(chatId).delete();
  }

  Future<bool> hasChatPin(String chatId) async {
    final pin = await getChatPin(chatId);
    return pin != null && pin.isNotEmpty;
  }

  // ==================== SCHEDULED WORKER ====================
  Future<void> processScheduledMessages() async {
    final uid = currentUserId;
    final now = DateTime.now().toIso8601String();
    final pending = await _firestore.collection('scheduled_messages')
        .where('senderId', isEqualTo: uid)
        .where('isSent', isEqualTo: false)
        .get();
    for (var doc in pending.docs) {
      final data = doc.data();
      final scheduledAt = data['scheduledAt'] as String?;
      if (scheduledAt != null && scheduledAt.compareTo(now) <= 0) {
        await sendMessage(data['chatId'], data['text']);
        await doc.reference.update({'isSent': true});
      }
    }
  }

  // ==================== MULTI-DELETE ====================
  Future<void> deleteMultipleMessages(
      String chatId, List<String> messageIds) async {
    for (var id in messageIds) {
      await _firestore.collection('chats').doc(chatId)
          .collection('messages').doc(id).delete();
    }
  }

  // ==================== STORAGE CALC ====================


  // ==================== AUTO-REPLY TRIGGER ====================
  Future<void> _triggerAutoReplyIfNeeded(String chatId, String receiverUid) async {
    try {
      final receiver = await getUserById(receiverUid);
      if (receiver == null) return;

      // Get receiver's auto-reply
      final userDoc = await _firestore.collection('users').doc(receiverUid).get();
      final autoReply = userDoc.data()?['autoReply'] as Map<String, dynamic>?;
      if (autoReply == null) return;
      if (autoReply['enabled'] != true) return;

      // Check business hours
      final onlyOutside = autoReply['onlyOutsideHours'] ?? false;
      if (onlyOutside == true) {
        final startH = autoReply['startHour'] ?? 22;
        final endH = autoReply['endHour'] ?? 9;
        final now = DateTime.now().hour;
        bool isOutside;
        if (startH < endH) {
          isOutside = now >= startH && now < endH;
        } else {
          isOutside = now >= startH || now < endH;
        }
        if (!isOutside) return;
      }

      final message = autoReply['message'] as String? ?? '';
      if (message.isEmpty) return;

      // Send auto-reply as a special message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': receiverUid,
        'text': message,
        'type': 'text',
        'timestamp': DateTime.now().toIso8601String(),
        'seen': false,
        'isAutoReply': true,
      });

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': '🤖 $message',
        'lastMessageTime': DateTime.now().toIso8601String(),
        'lastMessageSender': receiverUid,
      });
    } catch (e) {
      debugPrint('Auto-reply error: $e');
    }
  }

  // ==================== FAST STORAGE CALC ====================
  Future<Map<String, int>> getStorageStats() async {
    final uid = currentUserId;
    int images = 0, videos = 0, docs = 0, voice = 0, total = 0;
    try {
      final chats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();
      final futures = chats.docs.map((chat) async {
        final msgs = await _firestore
            .collection('chats')
            .doc(chat.id)
            .collection('messages')
            .get();
        int i = 0, v = 0, d = 0, vo = 0;
        for (var m in msgs.docs) {
          final t = m.data()['type'] as String?;
          if (t == 'image') i++;
          if (t == 'video') v++;
          if (t == 'file') d++;
          if (t == 'voice') vo++;
        }
        return [i, v, d, vo];
      });
      final results = await Future.wait(futures);
      for (var r in results) {
        images += r[0];
        videos += r[1];
        docs += r[2];
        voice += r[3];
      }
      total = images + videos + docs + voice;
    } catch (e) {
      debugPrint('Storage error: $e');
    }
    return {
      'images': images,
      'videos': videos,
      'docs': docs,
      'voice': voice,
      'total': total,
    };
  }

  // ==================== SEND MESSAGE WITH AUTO-REPLY ====================
  Future<void> sendMessageWithAutoReply(String chatId, String text) async {
    await sendMessage(chatId, text);
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;
      final participants =
          List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      if (otherId.isEmpty) return;
      await _triggerAutoReplyIfNeeded(chatId, otherId);
    } catch (e) {
      debugPrint('Send message with auto-reply error: $e');
    }
  }

  // Global scheduled messages worker (call on app start)
  Future<void> processAllScheduledMessages() async {
    try {
      final now = DateTime.now().toIso8601String();
      final pending = await _firestore.collection('scheduled_messages')
          .where('isSent', isEqualTo: false)
          .get();
      for (var doc in pending.docs) {
        final data = doc.data();
        if (data['senderId'] != currentUserId) continue;
        final scheduledAt = data['scheduledAt'] as String?;
        if (scheduledAt != null && scheduledAt.compareTo(now) <= 0) {
          await sendMessage(data['chatId'], data['text']);
          await doc.reference.update({'isSent': true});
        }
      }
    } catch (e) {
      debugPrint('Scheduled worker error: $e');
    }
  }

  // ==================== LANGUAGE PREFERENCE ====================
  Future<void> updatePreferredLanguage(String langCode) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'preferredLanguage': langCode,
    });
  }

  // ==================== LIVE TYPING PREVIEW ====================
  Future<void> updateTypingStatus(String chatId, String text) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(uid)
          .set({
        'userId': uid,
        'text': text.length > 60 ? text.substring(text.length - 60) : text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> clearTypingStatus(String chatId) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(uid)
          .delete();
    } catch (_) {}
  }

  Stream<String?> listenOtherUserTyping(String chatId, String otherUserId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(otherUserId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final ts = data['timestamp'] as String?;
      final text = data['text'] as String? ?? '';
      if (ts == null || text.isEmpty) return null;
      try {
        final time = DateTime.parse(ts);
        if (DateTime.now().difference(time).inSeconds > 6) {
          return null;
        }
      } catch (_) {
        return null;
      }
      return text;
    });
  }

  Future<void> updateLiveTypingSetting(bool enabled) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).update({
      'liveTypingEnabled': enabled,
    });
  }

  Stream<bool> getLiveTypingSetting() {
    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(true);
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => d.data()?['liveTypingEnabled'] ?? true);
  }

  Future<bool> isOtherUserLiveTypingEnabled(String otherUid) async {
    try {
      final doc = await _firestore.collection('users').doc(otherUid).get();
      return doc.data()?['liveTypingEnabled'] ?? true;
    } catch (_) {
      return true;
    }
  }

  // ==================== CONTACT SYNC (Email-based) ====================
  Future<List<Map<String, String>>> getPhoneEmails() async {
    try {
      final perm = await FlutterContacts.permissions.request(PermissionType.read);
      if (perm != PermissionStatus.granted) return [];

      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.email},
      );

      final list = <Map<String, String>>[];
      for (var c in contacts) {
        for (var e in c.emails) {
          final email = e.address.trim().toLowerCase();
          if (email.isNotEmpty && email.contains('@')) {
            list.add({
              'name': (c.displayName ?? '').isEmpty ? 'Unknown' : (c.displayName ?? 'Unknown'),
              'email': email,
            });
          }
        }
      }
      return list;
    } catch (e) {
      print('Contact sync error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> findMatchingContacts() async {
    final emails = await getPhoneEmails();
    if (emails.isEmpty) return [];

    final uid = currentUserId;
    final myEmail = _auth.currentUser?.email?.toLowerCase() ?? '';

    // Fetch all users (we'll filter by email)
    final usersSnap = await _firestore.collection('users').get();

    // Map email -> user data
    final userMap = <String, Map<String, dynamic>>{};
    for (var doc in usersSnap.docs) {
      final data = doc.data();
      final email = (data['email'] ?? '').toString().toLowerCase();
      if (email.isNotEmpty && email != myEmail && data['uid'] != uid) {
        userMap[email] = data;
      }
    }

    // Match
    final matched = <Map<String, dynamic>>[];
    final seenUids = <String>{};
    for (var c in emails) {
      final u = userMap[c['email']];
      if (u != null && !seenUids.contains(u['uid'])) {
        seenUids.add(u['uid'] as String);
        matched.add({
          'name': u['name'],
          'email': u['email'],
          'username': u['username'] ?? '',
          'photoUrl': u['photoUrl'],
          'uid': u['uid'],
          'phoneName': c['name'],
        });
      }
    }
    return matched;
  }

  // ==================== BACKUP & RESTORE ====================
  Future<Map<String, dynamic>> exportBackup() async {
    final uid = currentUserId;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    // Get all chats
    final chatsSnap = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    final chatsData = <Map<String, dynamic>>[];
    int totalMessages = 0;

    for (var chat in chatsSnap.docs) {
      final chatData = chat.data();
      // Get messages
      final msgsSnap = await _firestore
          .collection('chats')
          .doc(chat.id)
          .collection('messages')
          .get();

      final msgs = <Map<String, dynamic>>[];
      for (var m in msgsSnap.docs) {
        msgs.add({'id': m.id, ...m.data()});
      }
      totalMessages += msgs.length;

      chatsData.add({
        'chatId': chat.id,
        'chatData': chatData,
        'messages': msgs,
      });
    }

    // Contacts
    final contactsSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .get();
    final contacts = contactsSnap.docs.map((d) => d.id).toList();

    final backup = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'user': userData,
      'contacts': contacts,
      'chats': chatsData,
      'stats': {
        'totalChats': chatsData.length,
        'totalMessages': totalMessages,
      },
    };

    // Save backup metadata + full data in Firestore
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('backups')
        .doc('latest')
        .set(backup);

    // Update user with backup info
    await _firestore.collection('users').doc(uid).update({
      'backup': {
        'lastBackup': DateTime.now().toIso8601String(),
        'totalChats': chatsData.length,
        'totalMessages': totalMessages,
      }
    });

    return backup;
  }

  Future<int> restoreBackup() async {
    final uid = currentUserId;
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('backups')
        .doc('latest')
        .get();

    if (!doc.exists) return 0;
    final data = doc.data();
    if (data == null) return 0;

    final chats = (data['chats'] as List<dynamic>? ?? []);
    int restored = 0;

    for (var chatEntry in chats) {
      final chatId = chatEntry['chatId'] as String;
      final chatData = Map<String, dynamic>.from(chatEntry['chatData'] ?? {});
      final msgs = (chatEntry['messages'] as List<dynamic>? ?? []);

      // Ensure chat exists
      final chatRef = _firestore.collection('chats').doc(chatId);
      final existing = await chatRef.get();
      if (!existing.exists) {
        await chatRef.set(chatData);
      }

      // Write messages in batches (Firestore has 500 write limit per batch)
      final messagesRef = chatRef.collection('messages');
      for (var m in msgs) {
        final msgId = m['id'] as String?;
        if (msgId == null) continue;
        final msgData = Map<String, dynamic>.from(m)..remove('id');
        await messagesRef.doc(msgId).set(msgData);
        restored++;
      }
    }

    // Restore contacts
    final contacts = (data['contacts'] as List<dynamic>? ?? []);
    for (var cid in contacts) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('contacts')
          .doc(cid as String)
          .set({
        'uid': cid,
        'addedAt': DateTime.now().toIso8601String(),
      });
    }

    return restored;
  }

  
}