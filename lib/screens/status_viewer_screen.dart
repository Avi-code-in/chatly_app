import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/chat_service.dart';
import '../models/status_model.dart';
import '../theme.dart';

class StatusViewerScreen extends StatefulWidget {
  final List<StatusModel> statuses;
  final bool isMyStatus;

  const StatusViewerScreen({
    super.key,
    required this.statuses,
    required this.isMyStatus,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  final _service = ChatService();
  late AnimationController _progressController;
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(vsync: this);
    _startProgress();
  }

  void _startProgress() {
    _progressController.reset();
    final status = widget.statuses[_currentIndex];
    // 5 seconds for images/text, video uses its own duration
    final duration = status.type == 'video'
        ? const Duration(seconds: 15)
        : const Duration(seconds: 5);

    _progressController.duration = duration;
    _progressController.forward().then((_) {
      _goToNext();
    });
  }

  void _goToNext() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startProgress();
    } else {
      Navigator.pop(context);
    }
  }

  void _goToPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startProgress();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _deleteCurrentStatus() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Status?'),
        content: const Text('This status will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteStatus(widget.statuses[_currentIndex].id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Progress bars
            Positioned(
              top: 12,
              left: 10,
              right: 10,
              child: Row(
                children: List.generate(
                  widget.statuses.length,
                  (index) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: index < _currentIndex
                                ? 1.0
                                : index == _currentIndex
                                    ? _progressController.value
                                    : 0.0,
                            backgroundColor: Colors.white30,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 3,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Header
            Positioned(
              top: 24,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    backgroundImage:
                        widget.statuses[_currentIndex].userPhoto != null &&
                                widget.statuses[_currentIndex]
                                    .userPhoto!
                                    .startsWith('data:image')
                            ? MemoryImage(_decodeBase64(widget.statuses[_currentIndex].userPhoto!))
                            : null,
                    child: widget.statuses[_currentIndex].userPhoto == null ||
                            !widget.statuses[_currentIndex]
                                .userPhoto!
                                .startsWith('data:image')
                        ? Text(
                            widget.statuses[_currentIndex].userName.isNotEmpty
                                ? widget.statuses[_currentIndex].userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.isMyStatus
                          ? 'My Status'
                          : widget.statuses[_currentIndex].userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (widget.isMyStatus)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: _deleteCurrentStatus,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                _startProgress();
              },
              itemCount: widget.statuses.length,
              itemBuilder: (context, index) {
                final status = widget.statuses[index];
                return _buildContent(status);
              },
            ),

            // Tap zones (left = prev, right = next)
            Positioned.fill(
              top: 60,
              bottom: 0,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _goToPrev,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _goToNext,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StatusModel status) {
    if (status.type == 'video' && status.videoUrl != null) {
      return VideoStatusPlayer(url: status.videoUrl!);
    }
    if (status.type == 'image' && status.imageUrl != null) {
      return Center(
        child: Image.network(
          status.imageUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (context, error, stack) {
            return const Center(
              child: Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          status.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Uint8List _decodeBase64(String dataUrl) {
    final base64String = dataUrl.split(',').last;
    return base64Decode(base64String);
  }
}

class VideoStatusPlayer extends StatefulWidget {
  final String url;
  const VideoStatusPlayer({super.key, required this.url});

  @override
  State<VideoStatusPlayer> createState() => _VideoStatusPlayerState();
}

class _VideoStatusPlayerState extends State<VideoStatusPlayer> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _controller.value.isInitialized
          ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          : const CircularProgressIndicator(color: Colors.white),
    );
  }
}
