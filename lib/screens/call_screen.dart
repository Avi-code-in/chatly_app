import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../theme.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String callType; // 'audio' or 'video'
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

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription? _callStatusSub;

  bool _muted = false;
  bool _videoEnabled = false;
  bool _frontCamera = true;
  bool _speakerOn = true;
  bool _connected = false;
  bool _showControls = true;
  String _status = 'Calling...';
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _videoEnabled = widget.callType == 'video';
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initRenderers();
    _listenToCallStatus();

    if (widget.isCaller) {
      _startAsCaller();
    } else {
      _startAsReceiver();
    }

    // Auto-hide controls after 4 sec
    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _connected) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }

  void _listenToCallStatus() {
    _callStatusSub =
        _callService.listenCallStatus(widget.callId).listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'rejected') {
        _cleanup();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call declined')),
          );
        }
      } else if (status == 'ended') {
        _cleanup();
        if (mounted) Navigator.pop(context);
      }

      if (widget.isCaller &&
          status == 'accepted' &&
          data['answer'] != null &&
          _peerConnection != null) {
        _handleAnswer(data['answer']);
      }
    });
  }

  Future<void> _startAsCaller() async {
    await _getUserMedia();
    _peerConnection = await _callService.createPeerConnection(widget.callId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _callService.sendOffer(widget.callId, offer);

    _callService.listenCallStatus(widget.callId).listen((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      final candidates = data['receiverCandidates'] as List<dynamic>? ?? [];
      for (var c in candidates) {
        _peerConnection?.addCandidate(RTCIceCandidate(
          c['candidate'],
          c['sdpMLineIndex'],
          c['sdpMid'],
        ));
      }
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> answerData) async {
    final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
    await _peerConnection!.setRemoteDescription(answer);
    if (mounted) {
      setState(() {
        _connected = true;
        _status = 'Connected';
      });
      _startDurationTimer();
      _scheduleHideControls();
    }

    _callService.listenCallStatus(widget.callId).listen((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      final candidates = data['callerCandidates'] as List<dynamic>? ?? [];
      for (var c in candidates) {
        _peerConnection?.addCandidate(RTCIceCandidate(
          c['candidate'],
          c['sdpMLineIndex'],
          c['sdpMid'],
        ));
      }
    });
  }

  Future<void> _startAsReceiver() async {
    await _getUserMedia();

    _callService.listenCallStatus(widget.callId).listen((doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      final offerData = data['offer'] as Map<String, dynamic>?;
      if (offerData != null && _peerConnection == null) {
        await _handleOffer(offerData);
      }
    });
  }

  Future<void> _handleOffer(Map<String, dynamic> offerData) async {
    _peerConnection = await _callService.createPeerConnection(widget.callId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await _callService.sendAnswer(widget.callId, answer);

    if (mounted) {
      setState(() {
        _connected = true;
        _status = 'Connected';
      });
      _startDurationTimer();
      _scheduleHideControls();
    }

    _callService.listenCallStatus(widget.callId).listen((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      final candidates = data['callerCandidates'] as List<dynamic>? ?? [];
      for (var c in candidates) {
        _peerConnection?.addCandidate(RTCIceCandidate(
          c['candidate'],
          c['sdpMLineIndex'],
          c['sdpMid'],
        ));
      }
    });
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
        track.enabled = !_videoEnabled;
      }
      setState(() => _videoEnabled = !_videoEnabled);
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
    await _cleanup();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cleanup() async {
    _durationTimer?.cancel();
    await _localStream?.dispose();
    await _peerConnection?.close();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    _callStatusSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';
    final hasImage = widget.otherUserPhoto != null &&
        widget.otherUserPhoto!.isNotEmpty &&
        (widget.otherUserPhoto!.startsWith('data:image') ||
            widget.otherUserPhoto!.startsWith('http'));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // ============ BACKGROUND ============
            if (isVideo && _connected)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1A2340),
                        const Color(0xFF0A0E1A),
                      ],
                    ),
                  ),
                ),
              ),

            // ============ AUDIO CALL BACKGROUND ============
            if (!isVideo || !_connected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2196F3).withOpacity(0.15),
                        Colors.transparent,
                        const Color(0xFF1976D2).withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              ),

            // ============ AUDIO CALL AVATAR ============
            if (!isVideo || !_connected)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing ring
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 180 + (_pulseController.value * 40),
                          height: 180 + (_pulseController.value * 40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2196F3)
                                  .withOpacity(1 - _pulseController.value),
                              width: 2,
                            ),
                          ),
                          child: Center(child: child),
                        );
                      },
                      child: _buildAvatar(hasImage, 70),
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
                    const SizedBox(height: 10),
                    _buildStatusPill(),
                  ],
                ),
              ),

            // ============ VIDEO CALL - LOCAL PIP ============
            if (isVideo && _videoEnabled)
              Positioned(
                top: 100,
                right: 20,
                child: GestureDetector(
                  onTap: _toggleControls,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showControls ? 1 : 0.85,
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
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ============ TOP BAR ============
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
                            _iconButton(
                              icon: Icons.arrow_back_ios_new,
                              onTap: () {},
                            ),
                            const SizedBox(width: 14),
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
                                  const SizedBox(height: 2),
                                  Text(
                                    _connected
                                        ? _formatDuration(_callDuration)
                                        : _status,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF00C853)
                                      .withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00C853),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
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

            // ============ BOTTOM CONTROLS ============
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Speaker toggle
                          _controlButton(
                            icon: _speakerOn
                                ? Icons.volume_up
                                : Icons.volume_off,
                            label: 'Speaker',
                            onTap: () =>
                                setState(() => _speakerOn = !_speakerOn),
                          ),
                          const SizedBox(width: 20),

                          // Mute
                          _controlButton(
                            icon: _muted ? Icons.mic_off : Icons.mic,
                            label: 'Mute',
                            active: _muted,
                            onTap: _toggleMute,
                          ),
                          const SizedBox(width: 20),

                          // Video toggle
                          if (isVideo) ...[
                            _controlButton(
                              icon: _videoEnabled
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              label: 'Video',
                              active: !_videoEnabled,
                              onTap: _toggleVideo,
                            ),
                            const SizedBox(width: 20),
                            _controlButton(
                              icon: Icons.flip_camera_ios,
                              label: 'Flip',
                              onTap: _switchCamera,
                            ),
                            const SizedBox(width: 20),
                          ],

                          // End call
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
                    ],
                  ),
                ),
              ),
            ),

            // Connection info banner
            if (_connected)
              Positioned(
                top: 110,
                left: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _showControls ? 1 : 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00C853),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_callDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
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

  Widget _buildAvatar(bool hasImage, double radius) {
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
                    base64Decode(widget.otherUserPhoto!.split(',').last),
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

  Widget _buildStatusPill() {
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
            _connected ? _formatDuration(_callDuration) : _status,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _controlButton({
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
              color: active
                  ? Colors.white
                  : Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFF0A0E1A) : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
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
