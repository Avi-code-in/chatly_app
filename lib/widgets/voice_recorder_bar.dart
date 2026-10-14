import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../theme.dart';

class VoiceRecorderBar extends StatefulWidget {
  final Function(File file, int duration, String? transcription) onSend;
  final VoidCallback onCancel;

  const VoiceRecorderBar({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _path;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _path!,
        );

        setState(() => _isRecording = true);
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) setState(() => _seconds++);
          if (_seconds >= 300) _stopAndSend(); // Max 5 min
        });
      }
    } catch (e) {
      print('Record start error: $e');
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      if (path != null && _seconds >= 1) {
        widget.onSend(File(path), _seconds, null);
      } else {
        widget.onCancel();
      }
    } catch (e) {
      print('Record stop error: $e');
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
      if (_path != null) {
        final file = File(_path!);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      print('Cancel error: $e');
    }
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel
            GestureDetector(
              onTap: _cancelRecording,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.red, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Recording indicator
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_seconds),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            // Waveform animation
            Expanded(
              child: SizedBox(
                height: 30,
                child: _RecordingWave(),
              ),
            ),
            const SizedBox(width: 12),
            // Send
            GestureDetector(
              onTap: _stopAndSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.blueGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.blueShadow,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int s) {
    final min = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

class _RecordingWave extends StatefulWidget {
  @override
  State<_RecordingWave> createState() => _RecordingWaveState();
}

class _RecordingWaveState extends State<_RecordingWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(25, (i) {
            final phase = (_c.value + i * 0.1) % 1.0;
            final height = 8 + (16 * (0.5 + 0.5 * (1 - (phase * 2 - 1).abs())));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
