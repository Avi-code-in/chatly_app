import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';

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
  StreamSubscription? _sub;

  bool _muted = false;
  bool _videoOn = false;
  bool _frontCam = true;
  bool _speaker = false;
  bool _connected = false;
  bool _ended = false;
  bool _remoteVideoReady = false;
  String _status = 'Connecting...';
  Duration _dur = Duration.zero;
  Timer? _t;
  String _contact = '';

  bool get isVideo => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    _videoOn = isVideo;
    _loadInfo();
    _startRing();
    _initCall();
  }

  Future<void> _loadInfo() async {
    try {
      final u = await _chatService.getUserById(widget.otherUserId);
      if (u != null && mounted) {
        setState(() {
          _contact = u.email.isNotEmpty
              ? u.email
              : (u.phone.isNotEmpty ? u.phone : '@${u.username}');
        });
      }
    } catch (_) {}
  }

  Future<void> _startRing() async {
    if (!widget.isCaller) return;
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: true,
        volume: 0.4,
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
      await _setupMedia();
      _pc = await _callService.createCallPeer(widget.callId);
      _setupPeer();

      if (widget.isCaller) {
        await _asCaller();
      } else {
        _asReceiver();
      }
      _listenCall();
    } catch (e) {
      print('Init error: $e');
      if (mounted) setState(() => _status = 'Failed to connect');
    }
  }

  Future<void> _setupMedia() async {
    final constraints = {
      'audio': true,
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _localRenderer.srcObject = _localStream;

    for (var track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
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

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
        if (mounted) {
          setState(() => _remoteVideoReady = true);
        }
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

      // Handle offer
      final offerData = d['offer'] as Map<String, dynamic>?;
      if (offerData != null && _pc?.getRemoteDescription() == null) {
        try {
          await _pc!.setRemoteDescription(
            RTCSessionDescription(
              offerData['sdp'] as String,
              offerData['type'] as String,
            ),
          );
          final ans = await _pc!.createAnswer({
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': isVideo,
          });
          await _pc!.setLocalDescription(ans);
          await _callService.sendAnswer(widget.callId, ans);
        } catch (e) {
          print('Offer/Answer error: $e');
        }
      }

      // Add caller ICE
      final cc = d['callerCandidates'] as List<dynamic>? ?? [];
      for (var c in cc) {
        try {
          await _pc?.addCandidate(RTCIceCandidate(
            c['candidate'] as String?,
            c['sdpMid'] as String?,
            c['sdpMLineIndex'] as int?,
          ));
        } catch (_) {}
      }

      if (d['status'] == 'rejected' || d['status'] == 'ended') {
        if (mounted && !_ended) _end(silent: true);
      }
    });
  }

  void _listenCall() {
    _sub = _callService.listenCallStatus(widget.callId).listen((doc) async {
      if (!doc.exists) return;
      final d = doc.data() as Map<String, dynamic>?;
      if (d == null) return;

      // Caller: handle answer
      if (widget.isCaller &&
          d['status'] == 'accepted' &&
          d['answer'] != null &&
          _pc?.getRemoteDescription() == null) {
        try {
          final ans = d['answer'] as Map<String, dynamic>;
          await _pc!.setRemoteDescription(
            RTCSessionDescription(
              ans['sdp'] as String,
              ans['type'] as String,
            ),
          );
        } catch (e) {
          print('Answer error: $e');
        }
      }

      // Caller: add receiver ICE
      if (widget.isCaller) {
        final rc = d['receiverCandidates'] as List<dynamic>? ?? [];
        for (var c in rc) {
          try {
            await _pc?.addCandidate(RTCIceCandidate(
              c['candidate'] as String?,
              c['sdpMid'] as String?,
              c['sdpMLineIndex'] as int?,
            ));
          } catch (_) {}
        }
      }

      if (d['status'] == 'rejected' || d['status'] == 'ended') {
        if (mounted && !_ended) _end(silent: true);
      }
    });
  }

  void _markConnected() {
    if (_connected || _ended) return;
    _stopRing();
    if (mounted) {
      setState(() {
        _connected = true;
        _status = '00:00';
      });
    }
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_ended) {
        setState(() {
          _dur += const Duration(seconds: 1);
          _status = _fmt(_dur);
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
      await Helper.setSpeakerphoneOn(!_speaker);
    } catch (_) {}
    setState(() => _speaker = !_speaker);
  }

  Future<void> _switchCam() async {
    if (_localStream == null) return;
    final tracks = _localStream!.getVideoTracks();
    if (tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
      setState(() => _frontCam = !_frontCam);
    }
  }

  Future<void> _end({bool silent = false}) async {
    if (_ended) return;
    _ended = true;
    await _stopRing();
    if (!silent) await _callService.endCall(widget.callId);
    _t?.cancel();
    await _localStream?.dispose();
    await _pc?.close();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.pop(context);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
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
    _sub?.cancel();
    _t?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _pc?.close();
    _stopRing();
    super.dispose();
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (_ended) return _endedScreen();
    if (isVideo && _connected && _remoteVideoReady) return _videoConnected();
    if (isVideo) return _videoWaiting();
    return _voiceScreen();
  }

  // ==================== BACKGROUND ====================
  Widget _bg() => Container(
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
      );

  // ==================== TOP BAR ====================
  Widget _topBar() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              if (widget.isCaller)
                GestureDetector(
                  onTap: () => _end(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                )
              else
                const SizedBox(width: 38),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF2874C7)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Chatly',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 38),
            ],
          ),
        ),
      );

  // ==================== AVATAR ====================
  Widget _avatar(double r) {
    final has = _hasImg(widget.otherUserPhoto);
    return Container(
      width: r * 2,
      height: r * 2,
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
          child: has
              ? (widget.otherUserPhoto!.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(widget.otherUserPhoto!.split(',').last),
                      fit: BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      imageUrl: widget.otherUserPhoto!,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => _avatarFallback(r),
                    ))
              : _avatarFallback(r),
        ),
      ),
    );
  }

  Widget _avatarFallback(double r) => Container(
        color: const Color(0xFF3B82F6),
        child: Center(
          child: Text(
            widget.otherUserName.isNotEmpty
                ? widget.otherUserName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: r * 0.85,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  // ==================== CIRCLE BUTTON ====================
  Widget _btn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) =>
      Column(
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

  // ==================== END BUTTON ====================
  Widget _endBtn() => GestureDetector(
        onTap: () => _end(),
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
          child: const Icon(Icons.call_end, color: Colors.white, size: 30),
        ),
      );

  // ==================== INCOMING/RINGING ====================
  Widget _voiceScreen() {
    final incoming = !widget.isCaller && !_connected;

    return Scaffold(
      backgroundColor: const Color(0xFF06101E),
      body: Container(
        decoration: _bg().decoration,
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              const SizedBox(height: 20),
              Text(
                widget.isCaller
                    ? (isVideo ? 'Outgoing video call...' : 'Calling...')
                    : (isVideo
                        ? 'Incoming video call...'
                        : 'Incoming voice call...'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              _avatar(65),
              const SizedBox(height: 28),
              Text(
                widget.otherUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_contact.isNotEmpty)
                Text(
                  _contact,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 15,
                  ),
                ),
              if (_connected) ...[
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 15,
                  ),
                ),
              ],
              const Spacer(flex: 2),

              // ============ INCOMING: Decline + Accept ============
              if (incoming)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _actionBtn(
                        icon: Icons.call_end,
                        label: 'Decline',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4A4A), Color(0xFFE53935)],
                        ),
                        onTap: () async {
                          await _callService.rejectCall(widget.callId);
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                      _actionBtn(
                        icon: isVideo ? Icons.videocam : Icons.call,
                        label: 'Accept',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                        ),
                        onTap: () async {
                          await _callService.acceptCall(widget.callId);
                        },
                      ),
                    ],
                  ),
                )

              // ============ OUTGOING / CONNECTED ============
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _btn(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      label: 'Mute',
                      active: _muted,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 22),
                    _btn(
                      icon: _speaker ? Icons.volume_up : Icons.volume_down,
                      label: 'Speaker',
                      active: _speaker,
                      onTap: _toggleSpeaker,
                    ),
                    const SizedBox(width: 22),
                    _btn(
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                _endBtn(),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ACTION BUTTON (Incoming) ====================
  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );

  // ==================== VIDEO WAITING ====================
  Widget _videoWaiting() {
    return Scaffold(
      backgroundColor: const Color(0xFF06101E),
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: _bg().decoration)),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _avatar(65),
                  const SizedBox(height: 28),
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _connected ? _status : 'Connecting...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_localRenderer.srcObject != null && _videoOn)
            Positioned(
              top: 90,
              right: 20,
              child: GestureDetector(
                onTap: _switchCam,
                child: Container(
                  width: 110,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
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
                    borderRadius: BorderRadius.circular(15),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: _frontCam,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            ),
          _topBar(),
          _videoBottomBar(),
        ],
      ),
    );
  }

  // ==================== VIDEO CONNECTED ====================
  Widget _videoConnected() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          if (_localRenderer.srcObject != null && _videoOn)
            Positioned(
              top: 90,
              right: 20,
              child: GestureDetector(
                onTap: _switchCam,
                child: Container(
                  width: 110,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: _frontCam,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
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
          _topBar(),
          // Timer top-left
          Positioned(
            top: 70,
            left: 20,
            child: Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
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
                _btn(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: 'Mute',
                  active: _muted,
                  onTap: _toggleMute,
                ),
                const SizedBox(width: 22),
                _btn(
                  icon: _videoOn ? Icons.videocam : Icons.videocam_off,
                  label: 'Camera',
                  active: !_videoOn,
                  onTap: _toggleVideo,
                ),
                const SizedBox(width: 22),
                _btn(
                  icon: Icons.flip_camera_ios,
                  label: 'Switch',
                  onTap: _switchCam,
                ),
                const SizedBox(width: 22),
                _endBtn(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== VIDEO BOTTOM BAR (waiting) ====================
  Widget _videoBottomBar() => Positioned(
        bottom: 40,
        left: 0,
        right: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _btn(
              icon: _muted ? Icons.mic_off : Icons.mic,
              label: 'Mute',
              active: _muted,
              onTap: _toggleMute,
            ),
            const SizedBox(width: 22),
            _btn(
              icon: _videoOn ? Icons.videocam : Icons.videocam_off,
              label: 'Camera',
              active: !_videoOn,
              onTap: _toggleVideo,
            ),
            const SizedBox(width: 22),
            _btn(
              icon: Icons.flip_camera_ios,
              label: 'Switch',
              onTap: _switchCam,
            ),
            const SizedBox(width: 22),
            _endBtn(),
          ],
        ),
      );

  // ==================== ENDED ====================
  Widget _endedScreen() => Scaffold(
        backgroundColor: const Color(0xFF06101E),
        body: Container(
          decoration: _bg().decoration,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF0A1628)],
                    ),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
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
                        ),
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 42,
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
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You\'ve ended the call with ${widget.otherUserName}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 15,
                  ),
                ),
                const Spacer(flex: 3),
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
