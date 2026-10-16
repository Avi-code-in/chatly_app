import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String callType;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.callId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.callType,
    required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _callService = CallService();
  final _chatService = ChatService();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  StreamSubscription? _callSub;

  bool _muted = false;
  bool _videoOn = false;
  bool _frontCamera = true;
  bool _speakerOn = false;
  bool _connected = false;
  bool _callEnded = false;
  String _status = 'Calling...';
  Duration _duration = Duration.zero;
  Timer? _timer;
  String _otherUserContact = '';

  bool get isVideo => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    _videoOn = isVideo;
    _loadOtherInfo();
    _initCall();
    if (widget.isCaller) {
      _startRing();
    }
  }

  Future<void> _loadOtherInfo() async {
    try {
      final u = await _chatService.getUserById(widget.otherUserId);
      if (u != null && mounted) {
        setState(() {
          _otherUserContact = u.email.isNotEmpty
              ? u.email
              : (u.phone.isNotEmpty ? u.phone : '@${u.username}');
        });
      }
    } catch (_) {}
  }

  Future<void> _startRing() async {
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: true,
        volume: 0.5,
      );
    } catch (_) {}
  }

  Future<void> _stopRing() async {
    try {
      await FlutterRingtonePlayer().stop();
    } catch (_) {}
  }

  Future<void> _initCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _getMedia();
      _pc = await _callService.createPeerConnection(widget.callId);
      _setupPeer();
      if (widget.isCaller) {
        await _asCaller();
      } else {
        _asReceiver();
      }
      _listenStatus();
    } catch (e) {
      print('init error: $e');
      if (mounted) setState(() => _status = 'Failed');
    }
  }

  Future<void> _getMedia() async {
    final c = {
      'audio': true,
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(c);
    _localRenderer.srcObject = _localStream;
    for (var t in _localStream!.getTracks()) {
      await _pc!.addTrack(t, _localStream!);
    }
    if (mounted) setState(() {});
  }

  void _setupPeer() {
    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      if (widget.isCaller) {
        _callService.sendCallerCandidate(widget.callId, c);
      } else {
        _callService.sendReceiverCandidate(widget.callId, c);
      }
    };
    _pc!.onTrack = (e) {
      if (e.streams.isNotEmpty) {
        _remoteStream = e.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
        if (mounted) setState(() {});
      }
    };
    _pc!.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markConnected();
      }
    };
    _pc!.onIceConnectionState = (s) {
      if (s == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _markConnected();
      }
    };
  }

  Future<void> _asCaller() async {
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideo,
    });
    await _pc!.setLocalDescription(offer);
    await _callService.sendOffer(widget.callId, offer);
  }

  void _asReceiver() {
    _callService.listenCallStatus(widget.callId).listen((doc) async {
      if (!doc.exists) return;
      final d = doc.data() as Map<String, dynamic>?;
      if (d == null) return;
      final offerData = d['offer'] as Map<String, dynamic>?;
      if (offerData != null && _pc?.getRemoteDescription() == null) {
        try {
          await _pc!.setRemoteDescription(
            RTCSessionDescription(
                offerData['sdp'] as String, offerData['type'] as String),
          );
          final ans = await _pc!.createAnswer({
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': isVideo,
          });
          await _pc!.setLocalDescription(ans);
          await _callService.sendAnswer(widget.callId, ans);
        } catch (e) {
          print('ans error: $e');
        }
      }
      final cc = d['callerCandidates'] as List<dynamic>? ?? [];
      for (var c in cc) {
        try {
          await _pc?.addCandidate(RTCIceCandidate(
              c['candidate'] as String?,
              c['sdpMid'] as String?,
              c['sdpMLineIndex'] as int?));
        } catch (_) {}
      }
      if (d['status'] == 'rejected' || d['status'] == 'ended') {
        if (mounted && !_callEnded) _endClose(silent: true);
      }
    });
  }

  void _listenStatus() {
    _callSub = _callService.listenCallStatus(widget.callId).listen((doc) async {
      if (!doc.exists) return;
      final d = doc.data() as Map<String, dynamic>?;
      if (d == null) return;
      if (widget.isCaller &&
          d['status'] == 'accepted' &&
          d['answer'] != null &&
          _pc?.getRemoteDescription() == null) {
        try {
          final ans = d['answer'] as Map<String, dynamic>;
          await _pc!.setRemoteDescription(
            RTCSessionDescription(
                ans['sdp'] as String, ans['type'] as String),
          );
        } catch (e) {
          print('ans err: $e');
        }
      }
      if (widget.isCaller) {
        final rc = d['receiverCandidates'] as List<dynamic>? ?? [];
        for (var c in rc) {
          try {
            await _pc?.addCandidate(RTCIceCandidate(
                c['candidate'] as String?,
                c['sdpMid'] as String?,
                c['sdpMLineIndex'] as int?));
          } catch (_) {}
        }
      }
      if (d['status'] == 'rejected' || d['status'] == 'ended') {
        if (mounted && !_callEnded) _endClose(silent: true);
      }
    });
  }

  void _markConnected() {
    if (_connected || _callEnded) return;
    _stopRing();
    if (mounted) {
      setState(() {
        _connected = true;
        _status = '00:00';
      });
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_callEnded) {
        setState(() {
          _duration += const Duration(seconds: 1);
          _status = _fmt(_duration);
        });
      }
    });
  }

  Future<void> _toggleMute() async {
    if (_localStream == null) return;
    for (var t in _localStream!.getAudioTracks()) {
      t.enabled = !t.enabled;
    }
    setState(() => _muted = !_muted);
  }

  Future<void> _toggleVideo() async {
    if (_localStream == null || !isVideo) return;
    for (var t in _localStream!.getVideoTracks()) {
      t.enabled = !t.enabled;
    }
    setState(() => _videoOn = !_videoOn);
  }

  Future<void> _toggleSpeaker() async {
    try {
      await Helper.setSpeakerphoneOn(!_speakerOn);
    } catch (_) {}
    setState(() => _speakerOn = !_speakerOn);
  }

  Future<void> _switchCam() async {
    if (_localStream == null) return;
    final t = _localStream!.getVideoTracks();
    if (t.isNotEmpty) {
      await Helper.switchCamera(t.first);
      setState(() => _frontCamera = !_frontCamera);
    }
  }

  Future<void> _endClose({bool silent = false}) async {
    if (_callEnded) return;
    _callEnded = true;
    await _stopRing();
    if (!silent) await _callService.endCall(widget.callId);
    _timer?.cancel();
    await _localStream?.dispose();
    await _pc?.close();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.pop(context);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _hasImg(String? u) {
    if (u == null || u.isEmpty) return false;
    return u.startsWith('data:image') || u.startsWith('http');
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _timer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _pc?.close();
    _stopRing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_callEnded) return _endedScreen();
    if (isVideo && _connected && _remoteRenderer.srcObject != null) {
      return _videoCall();
    }
    return _voiceCall();
  }

  // ==================== VOICE / CALLING ====================
  Widget _voiceCall() {
    final hasImg = _hasImg(widget.otherUserPhoto);

    return Scaffold(
      backgroundColor: const Color(0xFF06101E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.4,
            colors: [
              Color(0xFF1E4976),
              Color(0xFF0A1A2E),
              Color(0xFF050B14),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top: call type text
              const SizedBox(height: 30),
              Text(
                widget.isCaller
                    ? (isVideo ? 'Outgoing video call...' : 'Calling...')
                    : (isVideo
                        ? 'Incoming video call...'
                        : 'Incoming voice call...'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),

              const Spacer(flex: 1),

              // Avatar
              _avatar(hasImg, 65),

              const SizedBox(height: 28),

              // Name
              Text(
                widget.otherUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 8),

              // Contact info (phone/email)
              if (_otherUserContact.isNotEmpty)
                Text(
                  _otherUserContact,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),

              if (_connected) ...[
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // ============ CONTROLS ============
              if (_connected) ...[
                // Active call: Mute, Keypad, Speaker, More
                _activeControls(),
              ] else if (widget.isCaller) ...[
                // Outgoing: Mute, Keypad, Speaker
                _outgoingControls(),
              ] else ...[
                // Incoming: should not reach here (handled by incoming screen)
                _outgoingControls(),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== CONTROLS: OUTGOING ====================
  Widget _outgoingControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _circleBtn(
              icon: _muted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              active: _muted,
              onTap: _toggleMute,
            ),
            const SizedBox(width: 24),
            _circleBtn(
              icon: Icons.dialpad,
              label: 'Keypad',
              onTap: () {},
            ),
            const SizedBox(width: 24),
            _circleBtn(
              icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
              label: 'Speaker',
              active: _speakerOn,
              onTap: _toggleSpeaker,
            ),
          ],
        ),
        const SizedBox(height: 40),
        _endBtn(),
      ],
    );
  }

  // ==================== CONTROLS: ACTIVE ====================
  Widget _activeControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _circleBtn(
              icon: _muted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              active: _muted,
              onTap: _toggleMute,
            ),
            const SizedBox(width: 20),
            _circleBtn(
              icon: Icons.dialpad,
              label: 'Keypad',
              onTap: () {},
            ),
            const SizedBox(width: 20),
            _circleBtn(
              icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
              label: 'Speaker',
              active: _speakerOn,
              onTap: _toggleSpeaker,
            ),
            const SizedBox(width: 20),
            _circleBtn(
              icon: Icons.more_horiz,
              label: 'More',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 40),
        _endBtn(),
      ],
    );
  }

  // ==================== CIRCLE BUTTON ====================
  Widget _circleBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFF06101E) : Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==================== END BUTTON ====================
  Widget _endBtn() {
    return GestureDetector(
      onTap: _endClose,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4A4A), Color(0xFFE53935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4A4A).withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.call_end, color: Colors.white, size: 30),
      ),
    );
  }

  // ==================== AVATAR ====================
  Widget _avatar(bool hasImg, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.9),
            width: 2.5,
          ),
        ),
        child: ClipOval(
          child: hasImg
              ? (widget.otherUserPhoto!.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(widget.otherUserPhoto!.split(',').last),
                      fit: BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      imageUrl: widget.otherUserPhoto!,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => _avFallback(radius),
                    ))
              : _avFallback(radius),
        ),
      ),
    );
  }

  Widget _avFallback(double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF2874C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty
              ? widget.otherUserName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.85,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ==================== VIDEO CALL ====================
  Widget _videoCall() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote full screen
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // Top gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Timer at top
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Local PiP
          if (_videoOn && _localRenderer.srcObject != null)
            Positioned(
              top: 90,
              right: 20,
              child: GestureDetector(
                onTap: _switchCam,
                child: Container(
                  width: 95,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: _frontCamera,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _vCtrlBtn(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: 'Mute',
                  active: _muted,
                  onTap: _toggleMute,
                ),
                const SizedBox(width: 22),
                _vCtrlBtn(
                  icon: _videoOn ? Icons.videocam : Icons.videocam_off,
                  label: 'Camera',
                  active: !_videoOn,
                  onTap: _toggleVideo,
                ),
                const SizedBox(width: 22),
                _vCtrlBtn(
                  icon: Icons.flip_camera_ios,
                  label: 'Switch',
                  onTap: _switchCam,
                ),
                const SizedBox(width: 22),
                GestureDetector(
                  onTap: _endClose,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4A4A), Color(0xFFE53935)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4A4A).withOpacity(0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.call_end,
                        color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vCtrlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFF06101E) : Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==================== ENDED SCREEN ====================
  Widget _endedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF06101E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.4,
            colors: [
              Color(0xFF1E4976),
              Color(0xFF0A1A2E),
              Color(0xFF050B14),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Icon circle with glow
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF1E3A5F),
                      Color(0xFF0A1628),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.25),
                      blurRadius: 50,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF2874C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                'Call Ended',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'You\'ve ended the call with ${widget.otherUserName}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(flex: 3),

              // Back to Chat button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF2874C7)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Back to Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
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
