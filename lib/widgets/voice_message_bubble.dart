import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../theme.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String voiceUrl;
  final int duration;
  final bool isMe;
  final String? transcribedText;

  const VoiceMessageBubble({
    super.key,
    required this.voiceUrl,
    required this.duration,
    required this.isMe,
    this.transcribedText,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  bool _showTranscription = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
            _player.seek(Duration.zero);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      try {
        if (_player.audioSource == null) {
          await _player.setUrl(widget.voiceUrl);
        }
        await _player.play();
      } catch (e) {
        print('Audio play error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration > 0
        ? _position.inMilliseconds / (widget.duration * 1000)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Waveform / progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          progress: progress,
                          color: widget.isMe
                              ? AppColors.primary
                              : AppColors.primary,
                          bgColor: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        size: const Size(double.infinity, 24),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(Duration(seconds: widget.duration)),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Transcription toggle
          if (widget.transcribedText != null &&
              widget.transcribedText!.isNotEmpty)
            GestureDetector(
              onTap: () =>
                  setState(() => _showTranscription = !_showTranscription),
              child: Container(
                margin: const EdgeInsets.only(top: 6, left: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.text_fields,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _showTranscription ? 'Hide text' : 'Show transcription',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_showTranscription && widget.transcribedText != null)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.transcribedText!,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 30;
    final barWidth = size.width / (barCount * 2);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth * 2) + barWidth;
      final heightFactor = (i % 3 == 0)
          ? 0.9
          : (i % 3 == 1)
              ? 0.5
              : 0.7;
      final barHeight = size.height * heightFactor;
      final isPlayed = i / barCount <= progress;
      paint.color = isPlayed ? color : bgColor;
      paint.strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x, (size.height - barHeight) / 2),
        Offset(x, (size.height + barHeight) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.progress != progress;
}
