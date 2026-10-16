import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../theme.dart';
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

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Vibration pattern
    _startVibration();
  }

  void _startVibration() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_processing) {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_processing) {
            HapticFeedback.heavyImpact();
            _startVibration();
          }
        });
      }
    });
  }

  Future<void> _accept() async {
    setState(() => _processing = true);
    await _callService.acceptCall(widget.callId);

    // Remove incoming_calls doc
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
    setState(() => _processing = true);
    await _callService.rejectCall(widget.callId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';
    final hasImage = _hasImage(widget.callerPhoto);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: Container(
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
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Call type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
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
                        isVideo ? 'Incoming Video Call' : 'Incoming Call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Pulsing avatar
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    return Container(
                      width: 200 + (_pulse.value * 50),
                      height: 200 + (_pulse.value * 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF2196F3).withOpacity(
                            0.6 - (_pulse.value * 0.5),
                          ),
                          width: 3,
                        ),
                      ),
                      child: Center(child: child),
                    );
                  },
                  child: _buildAvatar(hasImage, 75),
                ),

                const SizedBox(height: 30),

                // Caller name
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 10),

                // Status
                Text(
                  'is calling you...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 20),

                // Ringing dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        final opacity = ((_pulse.value + i * 0.3) % 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3)
                                .withOpacity(0.3 + (opacity * 0.7)),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    );
                  }),
                ),

                const Spacer(),

                // Accept / Decline buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      _actionButton(
                        icon: Icons.call_end,
                        label: 'Decline',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4D4D), Color(0xFFE53935)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: _processing ? null : _decline,
                      ),

                      // Accept button
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

                // Processing indicator
                if (_processing)
                  const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasImage(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('data:image') || url.startsWith('http');
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.6),
            blurRadius: 50,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? (widget.callerPhoto!.startsWith('data:image')
                ? Image.memory(
                    base64Decode(widget.callerPhoto!.split(',').last),
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    widget.callerPhoto!,
                    fit: BoxFit.cover,
                    errorBuilder: (c, u, e) => _fallbackAvatar(radius),
                  ))
            : _fallbackAvatar(radius),
      ),
    );
  }

  Widget _fallbackAvatar(double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: const Color(0xFF2196F3),
      child: Center(
        child: Text(
          widget.callerName.isNotEmpty
              ? widget.callerName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w700,
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
