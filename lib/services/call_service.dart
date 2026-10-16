import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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

    return callId;
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
    final pc = await createPeerConnection(_iceServers);

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
