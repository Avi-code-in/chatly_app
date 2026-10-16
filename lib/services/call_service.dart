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

  static const String _backendUrl = 'https://chatly-call-backend.onrender.com';

  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun3.l.google.com:19302',
          'stun:stun4.l.google.com:19302',
        ],
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  // ==================== START CALL ====================
  Future<String> startCall(String receiverId, String callType) async {
    final callId = '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';

    final callerDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final callerName = callerDoc.data()?['name'] ?? 'Someone';
    final callerPhoto = callerDoc.data()?['photoUrl'];

    await _firestore.collection('calls').doc(callId).set({
      'callId': callId,
      'callerId': currentUserId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'callType': callType,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
      'offer': null,
      'answer': null,
      'callerCandidates': [],
      'receiverCandidates': [],
      'callerConnected': false,
      'receiverConnected': false,
    });

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('call_status')
        .doc('current')
        .set({
      'inCall': true,
      'callId': callId,
      'startedAt': FieldValue.serverTimestamp(),
    });

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
      'timestamp': FieldValue.serverTimestamp(),
    });

    _sendBackendCall(receiverId, callId, callType, callerName);

    return callId;
  }

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
      print('✅ Backend: ${response.statusCode}');
    } catch (e) {
      print('❌ Backend error: $e');
    }
  }

  // ==================== ACCEPT ====================
  Future<void> acceptCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Mark receiver in-call
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('call_status')
        .doc('current')
        .set({
      'inCall': true,
      'callId': callId,
      'startedAt': FieldValue.serverTimestamp(),
    });

    // Delete incoming_call notification
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('incoming_calls')
          .doc(callId)
          .delete();
    } catch (_) {}
  }

  // ==================== REJECT / END ====================
  Future<void> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    await _cleanup(callId);
  }

  Future<void> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    await _cleanup(callId);
  }

  Future<void> _cleanup(String callId) async {
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

  // ==================== WEBRTC PEER ====================
  Future<RTCPeerConnection> createPeerConnection(String callId) async {
    final pc = await createPeerConnection(_iceConfig);

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        final field = currentUserId.toString().contains('_caller_')
            ? 'callerCandidates'
            : 'callerCandidates';
        _firestore
            .collection('calls')
            .doc(callId)
            .update({
          'callerCandidates': FieldValue.arrayUnion([
            {
              'candidate': candidate.candidate,
              'sdpMLineIndex': candidate.sdpMLineIndex,
              'sdpMid': candidate.sdpMid,
            }
          ]),
        }).catchError((_) {});
      }
    };

    return pc;
  }

  // Caller's ICE
  Future<void> sendCallerCandidate(
      String callId, RTCIceCandidate candidate) async {
    await _firestore.collection('calls').doc(callId).update({
      'callerCandidates': FieldValue.arrayUnion([
        {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        }
      ]),
    });
  }

  // Receiver's ICE
  Future<void> sendReceiverCandidate(
      String callId, RTCIceCandidate candidate) async {
    await _firestore.collection('calls').doc(callId).update({
      'receiverCandidates': FieldValue.arrayUnion([
        {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        }
      ]),
    });
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
