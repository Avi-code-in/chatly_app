import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<RTCPeerConnection> createCallPeer(String callId) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };
    return await createPeerConnection(config);
  }

  Future<void> sendOffer(String callId, RTCSessionDescription offer) async {
    await _db.collection('calls').doc(callId).set({
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendAnswer(String callId, RTCSessionDescription answer) async {
    await _db.collection('calls').doc(callId).update({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'status': 'accepted',
    });
  }

  Future<void> sendCallerCandidate(String callId, RTCIceCandidate candidate) async {
    await _db.collection('calls').doc(callId).update({
      'callerCandidates': FieldValue.arrayUnion([{
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }])
    });
  }

  Future<void> sendReceiverCandidate(String callId, RTCIceCandidate candidate) async {
    await _db.collection('calls').doc(callId).update({
      'receiverCandidates': FieldValue.arrayUnion([{
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }])
    });
  }

  Stream<DocumentSnapshot> listenCallStatus(String callId) {
    return _db.collection('calls').doc(callId).snapshots();
  }

  Future<void> acceptCall(String callId) async {
    await _db.collection('calls').doc(callId).update({'status': 'accepted'});
  }

  Future<void> rejectCall(String callId) async {
    await _db.collection('calls').doc(callId).update({'status': 'rejected'});
  }

  Future<void> endCall(String callId) async {
    await _db.collection('calls').doc(callId).update({'status': 'ended'});
  }
}
