import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';
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

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  final _callService = CallService();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  StreamSubscription? _callSub;

  bool _muted = false;
  bool _videoOn = false;
  bool _frontCamera = true;
  bool _speakerOn = true;
  bool _connected = false;
  bool _showControls = true;
  String _status = 'Calling...';
  Duration _duration = Duration.zero;
  Timer? _timer;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _videoOn = widget.callType == 'video';

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initAll();
    _hideTimer();
  }

  void _hideTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _connected) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _hideTimer();
  }

  Future<void> _initAll() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      await _getUserMedia();

      if (widget.isCaller) {
        await _startAsCaller();
      } else {
        await _startAsReceiver();
      }
      _listenCallStatus();
    } catch (e) {
      print('Init error: $e');
      setState(() => _status = 'Failed to connect');
    }
  }

  Future<void> _getUserMedia() async {
    final constraints = {
      'audio': true,
      'video': widget.callType == 'video'
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _localRenderer.srcObject = _localStream;
    if (mounted) setState(() {});
  }

  // ============ CALLER ============
  Future<void> _startAsCaller() async {
    _pc = await _callService.createPeerConnection(widget.callId);

    for (var track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _callService.sendOffer(widget.callId, offer);

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        if (mounted) setState(() {});
      }
    };

    // Listen for receiver candidates
    _callService.listenCallStatus(widget.callId).listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      final candidates = data['receiverCandidates'] as List<dynamic>? ?? [];
      for (var c in candidates) {
        try {
          _pc?.addCandidate(RTCIceCandidate(
            c['candidate'],
            c['sdpMLineIndex'],
            c['sdpMid'],
          ));
        } catch (_) {}
      }
    });
  }

  // ============ RECEIVER ============
  Future<void> _startAsReceiver() async {
    _pc = await _callService.createPeerConnection(widget.callId);

    for (var track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        if (mounted) setState(() {});
      }
    };

    // Wait for offer
    _callService.listenCallStatus(widget.callId).listen((doc) async {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final offerData = data['offer'] as Map<String, dynamic>?;
      if (offerData != null && _pc?.getRemoteDescription() == null) {
        final offer =
            RTCSessionDescription(offerData['sdp'], offerData['type']);
        await _pc!.setRemoteDescription(offer);

        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        await _callService.sendAnswer(widget.callId, answer);
      }

      final candidates = data['callerCandidates'] as List<dynamic>? ?? [];
      for (var c in candidates) {
        try {
          _pc?.addCandidate(RTCIceCandidate(
            c['candidate'],
            c['sdpMLineIndex'],
            c['sdpMid'],
          ));
        } catch (_) {}
      }
    });
  }

  // ============ STATUS LISTENER ============
  void _listenCallStatus() {
    _callSub = _callService.listenCallStatus(widget.callId).listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;

      // Caller: handle answer
      if (widget.isCaller &&
          status == 'accepted' &&
          data['answer'] != null &&
          _connected == false) {
        final answerData = data['answer'] as Map<String, dynamic>;
        _handleAnswer(answerData);
      }

      // Receiver: update status on accept
      if (!widget.isCaller && status == 'accepted' && _connected == false) {
        _markConnected();
      }

      if (status == 'rejected' || status == 'ended') {
        _cleanup();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> answerData) async {
    try {
      final answer =
          RTCSessionDescription(answerData['sdp'], answerData['type']);
      await _pc!.setRemoteDescription(answer);
      _markConnected();
    } catch (e) {
      print('Answer error: $e');
    }
  }

  void _markConnected() {
    if (_connected) return;
    if (mounted) {
      setState(() {
        _connected = true;
        _status = 'Connected';
      });
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
    _hideTimer();
  }

  // ============ CONTROLS ============
  void _toggleMute() {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = _muted;
      }
      setState(() => _muted = !_muted);
    }
  }

  void _toggleVideo() {
    if (_localStream != null && widget.callType == 'video') {
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = !_videoOn;
      }
      setState(() => _videoOn = !_videoOn);
    }
  }

  Future<void> _switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
      setState(() => _frontCamera = !_frontCamera);
    }
  }

  Future<void> _endCall() async {
    await _callService.endCall(widget.callId);
    _cleanup();
    if (mounted) Navigator.pop(context);
  }

  void _cleanup() {
    _timer?.cancel();
    _localStream?.dispose();
    _pc?.close();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _callSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _pc?.close();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';
    final hasImage = _hasImage(widget.otherUserPhoto);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A2340),
                      const Color(0xFF0A0E1A),
                      const Color(0xFF151B2E),
                    ],
                  ),
                ),
              ),
            ),

            // Remote video
            if (isVideo && _connected && _remoteRenderer.srcObject != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),

            // Avatar (audio call or video connecting)
            if (!isVideo || !_connected)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          return Container(
                            width: 170 + (_pulse.value * 40),
                            height: 170 + (_pulse.value * 40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2196F3).withOpacity(
                                  1 - _pulse.value,
                                ),
                                width: 2,
                              ),
                            ),
                            child: Center(child: child),
                          );
                        },
                        child: _avatar(hasImage, 65),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        widget.otherUserName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _statusPill(),
                    ],
                  ),
                ),
              ),

            // Local PiP video
            if (isVideo && _videoOn && _localRenderer.srcObject != null)
              Positioned(
                top: 100,
                right: 20,
                child: Container(
                  width: 110,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: _frontCamera,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Top info bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showControls ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: isVideo
                      ? Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.otherUserName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _connected
                                        ? _fmt(_duration)
                                        : _status,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_connected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C853)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF00C853)
                                        .withOpacity(0.4),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle,
                                        color: Color(0xFF00C853), size: 6),
                                    SizedBox(width: 6),
                                    Text(
                                      'HD',
                                      style: TextStyle(
                                        color: Color(0xFF00C853),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showControls ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ctrlBtn(
                        icon: _speakerOn
                            ? Icons.volume_up
                            : Icons.volume_off,
                        label: 'Speaker',
                        onTap: () =>
                            setState(() => _speakerOn = !_speakerOn),
                      ),
                      const SizedBox(width: 18),
                      _ctrlBtn(
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        label: 'Mute',
                        active: _muted,
                        onTap: _toggleMute,
                      ),
                      const SizedBox(width: 18),
                      if (isVideo) ...[
                        _ctrlBtn(
                          icon: _videoOn
                              ? Icons.videocam
                              : Icons.videocam_off,
                          label: 'Video',
                          active: !_videoOn,
                          onTap: _toggleVideo,
                        ),
                        const SizedBox(width: 18),
                        _ctrlBtn(
                          icon: Icons.flip_camera_ios,
                          label: 'Flip',
                          onTap: _switchCamera,
                        ),
                        const SizedBox(width: 18),
                      ],
                      GestureDetector(
                        onTap: _endCall,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF4D4D),
                                Color(0xFFE53935),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasImage(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('data:image') || url.startsWith('http');
  }

  Widget _avatar(bool hasImage, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage
            ? null
            : const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? (widget.otherUserPhoto!.startsWith('data:image')
                ? Image.memory(
                    base64Decode(
                        widget.otherUserPhoto!.split(',').last),
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    widget.otherUserPhoto!,
                    fit: BoxFit.cover,
                    errorBuilder: (c, u, e) => _fallbackAvatar(),
                  ))
            : _fallbackAvatar(),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFF2196F3),
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty
              ? widget.otherUserName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 50,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_connected)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                color: Color(0xFF2196F3),
                strokeWidth: 2,
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00C853),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 10),
          Text(
            _connected ? _fmt(_duration) : _status,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFF0A0E1A) : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
