import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/call_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String callType;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.callType,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final _callService = CallService();
  late AnimationController _pulse;
  bool _processing = false;

  bool get isVideo => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _startRingtone();
    _startVibration();
    _autoRejectTimer();
  }

  void _autoRejectTimer() {
    // Auto-reject after 60 seconds
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && !_processing) {
        _decline();
      }
    });
  }

  Future<void> _startRingtone() async {
    try {
      await FlutterRingtonePlayer().playRingtone(
        looping: true,
        volume: 1.0,
      );
    } catch (e) {
      try {
        await FlutterRingtonePlayer().playAlarm(
          looping: true,
          volume: 1.0,
        );
      } catch (_) {}
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await FlutterRingtonePlayer().stop();
    } catch (_) {}
  }

  Future<void> _startVibration() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
      }
    } catch (_) {}
  }

  Future<void> _stopVibration() async {
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  Future<void> _accept() async {
    if (_processing) return;
    setState(() => _processing = true);

    HapticFeedback.mediumImpact();
    await _stopRingtone();
    await _stopVibration();

    await _callService.acceptCall(widget.callId);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: widget.callId,
            otherUserId: widget.callerId,
            otherUserName: widget.callerName,
            otherUserPhoto: widget.callerPhoto,
            callType: widget.callType,
            isCaller: false,
          ),
        ),
      );
    }
  }

  Future<void> _decline() async {
    if (_processing) return;
    setState(() => _processing = true);

    HapticFeedback.mediumImpact();
    await _stopRingtone();
    await _stopVibration();
    await _callService.rejectCall(widget.callId);

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _stopRingtone();
    _stopVibration();
    _pulse.dispose();
    super.dispose();
  }

  bool _hasImage(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('data:image') || url.startsWith('http');
  }

  @override
  Widget build(BuildContext context) {
    final hasImg = _hasImage(widget.callerPhoto);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.5,
              colors: [
                Color(0xFF1A2E4A),
                Color(0xFF0B1220),
                Color(0xFF050810),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Call type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVideo ? Icons.videocam : Icons.call,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVideo
                            ? 'Incoming Video Call'
                            : 'Incoming Voice Call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Pulsing avatar
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final scale = 1 + (_pulse.value * 0.15);
                    final opacity = 0.4 + (_pulse.value * 0.3);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF3B82F6)
                                  .withOpacity(opacity * 0.5),
                              width: 2,
                            ),
                          ),
                        ),
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6)
                                    .withOpacity(opacity * 0.6),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: scale,
                          child: _buildAvatar(hasImg, 75),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Caller name
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  isVideo ? 'Video call from...' : 'Calling you...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),

                const Spacer(flex: 2),

                // ==================== BUTTONS ====================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // DECLINE
                      _actionButton(
                        icon: Icons.call_end,
                        label: 'Decline',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3B30), Color(0xFFD32F2F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: _processing ? null : _decline,
                      ),

                      // ACCEPT
                      _actionButton(
                        icon: isVideo ? Icons.videocam : Icons.call,
                        label: 'Accept',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: _processing ? null : _accept,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool hasImg, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImg
            ? null
            : const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 3,
        ),
      ),
      child: ClipOval(
        child: hasImg
            ? (widget.callerPhoto!.startsWith('data:image')
                ? Image.memory(
                    base64Decode(widget.callerPhoto!.split(',').last),
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: widget.callerPhoto!,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => _fallback(radius),
                  ))
            : _fallback(radius),
      ),
    );
  }

  Widget _fallback(double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: const Color(0xFF3B82F6),
      child: Center(
        child: Text(
          widget.callerName.isNotEmpty
              ? widget.callerName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
