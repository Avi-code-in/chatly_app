import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/socket_service.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String otherUserEmail; // Phone ki jagah Email
  final String callType; 
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.callId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.otherUserEmail,
    required this.callType,
    required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _socketService = SocketService();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool _muted = false;
  bool _videoOn = false;
  bool _frontCam = true;
  bool _speaker = false;
  bool _connected = false;
  bool _accepted = false;
  bool _ended = false;
  String _status = 'Calling...';
  Duration _duration = Duration.zero;
  Timer? _timer;

  bool get isVideo => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    _videoOn = isVideo;
    _initRenderers();
    _setupSocketListeners();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupSocketListeners() {
    _socketService.connect();

    if (widget.isCaller) {
      _startCall();
    } else {
      setState(() => _status = 'Incoming ${isVideo ? "Video" : "Voice"} Call...');
    }

    _socketService.socket.on('call-accepted', (data) async {
      if (mounted) setState(() => _accepted = true);
      await _handleAnswer(data);
    });

    _socketService.socket.on('call-made', (data) async {
      if (!widget.isCaller) {
        await _handleOffer(data);
      }
    });

    _socketService.socket.on('ice-candidate', (data) async {
      if (_pc != null && data['candidate'] != null) {
        try {
          await _pc!.addCandidate(RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ));
        } catch (e) { print('ICE Error: $e'); }
      }
    });

    _socketService.socket.on('call-ended', (data) => _endCallUI(silent: true));
    _socketService.socket.on('call-rejected', (data) => _endCallUI(silent: true));
  }

  Future<void> _startCall() async {
    await _setupPeerConnection();
    await _setupMedia();
    
    final offer = await _pc!.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': isVideo});
    await _pc!.setLocalDescription(offer);

    _socketService.emitCallUser({
      'callId': widget.callId,
      'callerId': widget.otherUserId,
      'receiverId': widget.otherUserId,
      'callType': widget.callType,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Future<void> _acceptCall() async {
    setState(() { _accepted = true; _status = 'Connecting...'; });
  }

  Future<void> _setupPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };
    _pc = await createPeerConnection(config);

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        _socketService.emitIceCandidate({
          'callId': widget.callId,
          'candidate': {
            'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex
          }
        });
      }
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
        if (mounted) setState(() => _connected = true);
      }
    };
  }

  Future<void> _setupMedia() async {
    await [Permission.microphone, Permission.camera].request();
    final constraints = {
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _localRenderer.srcObject = _localStream;

    for (var track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
  }

  Future<void> _handleOffer(dynamic data) async {
    await _setupPeerConnection();
    await _setupMedia();
    
    await _pc!.setRemoteDescription(RTCSessionDescription(data['offer']['sdp'], data['offer']['type']));
    final answer = await _pc!.createAnswer({'offerToReceiveAudio': true, 'offerToReceiveVideo': isVideo});
    await _pc!.setLocalDescription(answer);

    _socketService.emitAnswerCall({
      'callId': widget.callId,
      'answer': {'sdp': answer.sdp, 'type': answer.type}
    });
  }

  Future<void> _handleAnswer(dynamic data) async {
    if (_pc != null) {
      await _pc!.setRemoteDescription(RTCSessionDescription(data['answer']['sdp'], data['answer']['type']));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && !_ended) {
        setState(() {
          _duration += const Duration(seconds: 1);
          _status = _formatDuration(_duration);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String m = d.inMinutes.toString().padLeft(2, '0');
    String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> _endCallUI({bool silent = false}) async {
    if (_ended) return;
    setState(() => _ended = true);
    
    if (!silent) {
      _socketService.emitEndCall({'callId': widget.callId});
    }

    _timer?.cancel();
    await _localStream?.dispose();
    await _pc?.close();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
  }

  void _toggleMute() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !t.enabled);
    setState(() => _muted = !_muted);
  }

  void _toggleVideo() {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !t.enabled);
    setState(() => _videoOn = !_videoOn);
  }

  void _switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks().first);
      setState(() => _frontCam = !_frontCam);
    }
  }

  void _toggleSpeaker() {
    Helper.setSpeakerphoneOn(!_speaker);
    setState(() => _speaker = !_speaker);
  }

  @override
  void dispose() {
    _socketService.socket.off('call-accepted');
    _socketService.socket.off('call-made');
    _socketService.socket.off('ice-candidate');
    _socketService.socket.off('call-ended');
    _socketService.socket.off('call-rejected');
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ================= UI BUILDING =================
  @override
  Widget build(BuildContext context) {
    if (_ended) return _buildEndedScreen();
    if (isVideo && _connected && _accepted) return _buildVideoActiveScreen();
    if (isVideo && !_accepted && widget.isCaller) return _buildOutgoingVideoScreen();
    if (isVideo && !_accepted && !widget.isCaller) return _buildIncomingVideoScreen();
    
    if (!_accepted && !widget.isCaller) return _buildIncomingVoiceScreen();
    if (_accepted || widget.isCaller) return _buildVoiceActiveScreen();

    return _buildIncomingVoiceScreen();
  }

  BoxDecoration get _bgGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF06142E), Color(0xFF0B224A), Color(0xFF071021)],
    ),
  );

  Widget _avatar({double size = 120}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: ClipOval(
          child: widget.otherUserPhoto != null
              ? CachedNetworkImage(imageUrl: widget.otherUserPhoto!, fit: BoxFit.cover)
              : Container(
                  color: Colors.blueGrey[800],
                  child: Center(child: Text(widget.otherUserName[0].toUpperCase(), style: TextStyle(fontSize: size * 0.4, color: Colors.white))),
                ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback onTap, {bool active = false, Color? color}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: active ? Colors.white : (color ?? Colors.white.withOpacity(0.1)),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? Colors.black : (color != null ? Colors.white : Colors.white), size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildIncomingVoiceScreen() {
    return Scaffold(
      body: Container(
        decoration: _bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text("Incoming voice call...", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              _avatar(size: 130),
              const SizedBox(height: 24),
              Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(widget.otherUserEmail, style: const TextStyle(color: Colors.white70, fontSize: 16)), // Email yahan dikh rahi hai
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconBtn(Icons.call_end, "Decline", () => _endCallUI(), color: Colors.red),
                  _iconBtn(Icons.call, "Accept", () { _acceptCall(); }, color: Colors.green),
                ],
              ),
              const SizedBox(height: 20),
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.message, color: Colors.white), label: const Text("Message", style: TextStyle(color: Colors.white))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutgoingVideoScreen() {
    return Scaffold(
      body: Container(
        decoration: _bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text("Calling...", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              _avatar(size: 120),
              const SizedBox(height: 24),
              Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(widget.otherUserEmail, style: const TextStyle(color: Colors.white70, fontSize: 16)), // Email yahan dikh rahi hai
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconBtn(Icons.mic_off, "Mute", _toggleMute, active: _muted),
                  _iconBtn(Icons.dialpad, "Keypad", () {}),
                  _iconBtn(Icons.volume_up, "Speaker", _toggleSpeaker, active: _speaker),
                ],
              ),
              const SizedBox(height: 30),
              _iconBtn(Icons.call_end, "", () => _endCallUI(), color: Colors.red),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceActiveScreen() {
    if (!_connected && _accepted) _startTimer();
    return Scaffold(
      body: Container(
        decoration: _bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              _avatar(size: 120),
              const SizedBox(height: 24),
              Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconBtn(Icons.mic_off, "Mute", _toggleMute, active: _muted),
                  _iconBtn(Icons.dialpad, "Keypad", () {}),
                  _iconBtn(Icons.volume_up, "Speaker", _toggleSpeaker, active: _speaker),
                  _iconBtn(Icons.more_horiz, "More", () {}),
                ],
              ),
              const SizedBox(height: 40),
              _iconBtn(Icons.call_end, "", () => _endCallUI(), color: Colors.red),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingVideoScreen() {
    return Scaffold(
      body: Container(
        decoration: _bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text("Incoming video call...", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              _avatar(size: 130),
              const SizedBox(height: 24),
              Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(widget.otherUserEmail, style: const TextStyle(color: Colors.white70, fontSize: 16)), // Email yahan dikh rahi hai
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconBtn(Icons.call_end, "Decline", () => _endCallUI(), color: Colors.red),
                  _iconBtn(Icons.videocam, "Accept", () { _acceptCall(); }, color: Colors.green),
                ],
              ),
              const SizedBox(height: 20),
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.message, color: Colors.white), label: const Text("Message", style: TextStyle(color: Colors.white))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoActiveScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),
          Positioned(
            top: 50, left: 20,
            child: SafeArea(
              child: Text(_status, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Positioned(
            top: 50, right: 20,
            child: SafeArea(
              child: Container(
                width: 100, height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: RTCVideoView(_localRenderer, mirror: _frontCam, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _iconBtn(Icons.mic_off, "Mute", _toggleMute, active: _muted),
                _iconBtn(Icons.videocam_off, "Camera", _toggleVideo, active: !_videoOn),
                _iconBtn(Icons.flip_camera_ios, "Switch", _switchCamera),
                _iconBtn(Icons.call_end, "", () => _endCallUI(), color: Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedScreen() {
    return Scaffold(
      body: Container(
        decoration: _bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                ),
                child: const Center(child: Icon(Icons.call_end, color: Colors.blue, size: 60)),
              ),
              const SizedBox(height: 30),
              const Text("Call Ended", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text("You've ended the call with ${widget.otherUserName}", style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 55, width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF2E5EBA)]),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(child: Text("Back to Chat", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
