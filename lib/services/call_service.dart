import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // 🔴 RENDER BACKEND URL
  static const String _backendUrl = 'https://chatly-call-backend.onrender.com';

  // STUN servers (free)
  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
        ],
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  // ==================== START CALL ====================
  Future<String> startCall(String receiverId, String callType) async {
    final callId = _firestore.collection('calls').doc().id;

    final callerDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final callerName = callerDoc.data()?['name'] ?? 'Someone';
    final callerPhoto = callerDoc.data()?['photoUrl'];

    // Save call document
    await _firestore.collection('calls').doc(callId).set({
      'callId': callId,
      'callerId': currentUserId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'callType': callType,
      'status': 'ringing',
      'createdAt': DateTime.now().toIso8601String(),
      'offer': null,
      'answer': null,
      'callerCandidates': [],
      'receiverCandidates': [],
    });

    // Set caller in-call status
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('call_status')
        .doc('current')
        .set({
      'inCall': true,
      'callId': callId,
      'startedAt': DateTime.now().toIso8601String(),
    });

    // Add to receiver's incoming_calls
    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('incoming_calls')
        .doc(callId)
        .set({
      'callId': callId,
      'callerId': currentUserId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'callType': callType,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Send FCM via backend (works even if receiver app is killed)
    _sendBackendCall(receiverId, callId, callType, callerName);

    return callId;
  }

  // ==================== BACKEND FCM CALL ====================
  Future<void> _sendBackendCall(
    String receiverId,
    String callId,
    String callType,
    String callerName,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/send-call'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'receiverId': receiverId,
              'callerId': currentUserId,
              'callerName': callerName,
              'callType': callType,
              'callId': callId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      print('✅ Backend call: ${response.statusCode} ${response.body}');
    } catch (e) {
      print('❌ Backend call failed: $e');
    }
  }

  // ==================== ACCEPT / REJECT / END ====================
  Future<void> acceptCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'accepted',
      'acceptedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'endedAt': DateTime.now().toIso8601String(),
      });
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('incoming_calls')
          .doc(callId)
          .delete();
    } catch (_) {}
  }

  Future<void> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('call_status')
          .doc('current')
          .delete();
    } catch (_) {}
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('incoming_calls')
          .doc(callId)
          .delete();
    } catch (_) {}
  }

  // ==================== LISTENERS ====================
  Stream<DocumentSnapshot?> listenIncomingCalls() {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }

  Stream<DocumentSnapshot> listenCallStatus(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  // ==================== WEBRTC ====================
  Future<RTCPeerConnection> createPeerConnection(String callId) async {
    final pc = await createPeerConnection(_iceConfig);

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _firestore.collection('calls').doc(callId).update({
          'callerCandidates': FieldValue.arrayUnion([
            {
              'candidate': candidate.candidate,
              'sdpMLineIndex': candidate.sdpMLineIndex,
              'sdpMid': candidate.sdpMid,
            }
          ]),
        });
      }
    };

    pc.onConnectionState = (state) {
      print('Connection: $state');
    };

    return pc;
  }

  Future<void> sendOffer(String callId, RTCSessionDescription offer) async {
    await _firestore.collection('calls').doc(callId).update({
      'offer': {'type': offer.type, 'sdp': offer.sdp},
    });
  }

  Future<void> sendAnswer(String callId, RTCSessionDescription answer) async {
    await _firestore.collection('calls').doc(callId).update({
      'answer': {'type': answer.type, 'sdp': answer.sdp},
    });
  }

  Future<void> addIceCandidate(
    String callId,
    RTCIceCandidate candidate,
    bool isCaller,
  ) async {
    final field = isCaller ? 'callerCandidates' : 'receiverCandidates';
    try {
      await _firestore.collection('calls').doc(callId).update({
        field: FieldValue.arrayUnion([
          {
            'candidate': candidate.candidate,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'sdpMid': candidate.sdpMid,
          }
        ]),
      });
    } catch (_) {}
  }

  Future<bool> isUserInCall(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('call_status')
          .doc('current')
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}
