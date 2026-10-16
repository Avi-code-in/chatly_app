import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_cloud_messaging_dart/firebase_cloud_messaging_dart.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // ICE servers — free STUN servers (80-90% connections handle karega)
  final Map<String, dynamic> _iceServers = {
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

  // ============ START CALL ============
  Future<String> startCall(String receiverId, String callType) async {
    final callId = _firestore.collection('calls').doc().id;

    await _firestore.collection('calls').doc(callId).set({
      'callId': callId,
      'callerId': currentUserId,
      'receiverId': receiverId,
      'callType': callType, // 'audio' or 'video'
      'status': 'ringing', // ringing, accepted, rejected, ended
      'createdAt': DateTime.now().toIso8601String(),
      'offer': null,
      'answer': null,
      'callerCandidates': [],
      'receiverCandidates': [],
    });

    // Set caller status
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

    // Send FCM notification to receiver
    await _sendCallNotification(receiverId, callId, callType, callerName);

    return callId;
  }

  Future<void> _sendCallNotification(
    String receiverId,
    String callId,
    String callType,
    String callerName,
  ) async {
    try {
      // Get receiver's FCM token
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final token = receiverDoc.data()?['fcmToken'] as String?;
      if (token == null || token.isEmpty) return;

      // Load service account
      final jsonString = await rootBundle.loadString('assets/serviceAccountKey.json');
      final server = FirebaseCloudMessagingServer.fromServiceAccountJson(jsonString);

      // Send high priority notification
      await server.send(
        FcmMessage(
          token: token,
          android: const FcmAndroidConfig(
            priority: 'high',
            ttl: '30s',
          ),
          data: {
            'type': 'incoming_call',
            'callId': callId,
            'callerId': currentUserId,
            'callerName': callerName,
            'callType': callType,
          },
        ),
      );
      print('✅ Call notification sent');
    } catch (e) {
      print('❌ FCM send error: $e');
    }
  }

  // ============ ACCEPT CALL ============
  Future<void> acceptCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'accepted',
      'acceptedAt': DateTime.now().toIso8601String(),
    });
  }

  // ============ REJECT CALL ============
  Future<void> rejectCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'rejected',
      'endedAt': DateTime.now().toIso8601String(),
    });
  }

  // ============ END CALL ============
  Future<void> endCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'ended',
      'endedAt': DateTime.now().toIso8601String(),
    });

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('call_status')
        .doc('current')
        .delete();
  }

  // ============ LISTEN TO INCOMING CALLS ============
  Stream<DocumentSnapshot> listenIncomingCalls() {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null)
        .where((doc) => doc != null)
        .map((doc) => doc!);
  }

  // ============ LISTEN TO CALL STATUS ============
  Stream<DocumentSnapshot> listenCallStatus(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  // ============ WEBRTC SIGNALING ============
  Future<RTCPeerConnection> createPeerConnection(String callId) async {
    final Map<String, dynamic> config = {
      'iceServers': [
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
          ],
        },
      ],
      'sdpSemantics': 'unified-plan',
    };
    final pc = await createPeerConnection(config);

    // ICE candidates collect karo
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

    // Remote stream track
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        // Remote stream received
        print('Remote stream received: ${event.streams[0].id}');
      }
    };

    pc.onConnectionState = (state) {
      print('Connection state: $state');
    };

    return pc;
  }

  // ============ SEND OFFER ============
  Future<void> sendOffer(String callId, RTCSessionDescription offer) async {
    await _firestore.collection('calls').doc(callId).update({
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
    });
  }

  // ============ SEND ANSWER ============
  Future<void> sendAnswer(String callId, RTCSessionDescription answer) async {
    await _firestore.collection('calls').doc(callId).update({
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
    });
  }

  // ============ ADD ICE CANDIDATE ============
  Future<void> addIceCandidate(
    String callId,
    RTCIceCandidate candidate,
    bool isCaller,
  ) async {
    final field = isCaller ? 'callerCandidates' : 'receiverCandidates';
    await _firestore.collection('calls').doc(callId).update({
      field: FieldValue.arrayUnion([
        {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        }
      ]),
    });
  }

  // ============ CHECK IF USER IS IN CALL ============
  Future<bool> isUserInCall(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('call_status')
        .doc('current')
        .get();
    return doc.exists;
  }
}
