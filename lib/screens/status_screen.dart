import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../models/status_model.dart';
import '../theme.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _service = ChatService();
  final _cloudinary = CloudinaryService();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.white,
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: () => _showAddStatusSheet(context),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Status', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Share your moments with your contacts', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.search, color: AppColors.textPrimary), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textPrimary), onPressed: () {}),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _myStatusTile(context)),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Recent updates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<StatusModel>>(
                stream: _service.getStatuses(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyState();
                  final statuses = snapshot.data!.where((s) => s.userId != _service.currentUserId).toList();
                  if (statuses.isEmpty) return const Center(child: Text('No recent updates from others', style: TextStyle(color: AppColors.textSecondary)));
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: statuses.length,
                    itemBuilder: (context, index) => _statusTile(context, statuses[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myStatusTile(BuildContext context) {
    return StreamBuilder(
      stream: _service.getCurrentUser(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
        final user = snapshot.data!;
        return StreamBuilder<List<StatusModel>>(
          stream: _service.getMyStatuses(),
          builder: (context, myStatusSnapshot) {
            final hasStatus = myStatusSnapshot.hasData && myStatusSnapshot.data!.isNotEmpty;
            return GestureDetector(
              onTap: () {
                if (hasStatus) {
                  _showMyStatusViewer(context, myStatusSnapshot.data!);
                } else {
                  _showAddStatusSheet(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasStatus ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]) : null,
                            border: hasStatus ? null : Border.all(color: AppColors.textSecondary.withOpacity(0.3), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.white,
                            backgroundImage: user.photoUrl != null && user.photoUrl!.startsWith('data:image') ? MemoryImage(_decodeBase64(user.photoUrl!)) : null,
                            child: user.photoUrl == null || !user.photoUrl!.startsWith('data:image') ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20)) : null,
                          ),
                        ),
                        Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 16))),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(hasStatus ? 'Tap to view your status' : 'Tap to add status update', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.camera_alt_outlined, color: AppColors.textPrimary), onPressed: () => _showAddStatusSheet(context)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusTile(BuildContext context, StatusModel status) {
    final isNew = !status.viewers.contains(_service.currentUserId);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: _ringAvatar(status.userPhoto, status.userName, 28, isNew),
      title: Text(status.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
      subtitle: Text(_formatTime(status.timestamp), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
      onTap: () {
        _service.markStatusViewed(status.id);
        _showStatusViewer(context, status);
      },
    );
  }

  Widget _ringAvatar(String? photo, String name, double radius, bool isNew) {
    final hasImage = photo != null && photo.startsWith('data:image');
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isNew ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        border: isNew ? null : Border.all(color: AppColors.textSecondary.withOpacity(0.3), width: 2),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.white,
        backgroundImage: hasImage ? MemoryImage(_decodeBase64(photo)) : null,
        child: !hasImage ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20)) : null,
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No status updates yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Tap the edit button to add a status', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  void _showAddStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Add Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _sheetItem(Icons.text_fields, 'Text Status', () { Navigator.pop(context); _addTextStatus(context); }),
            _sheetItem(Icons.image, 'Image Status', () { Navigator.pop(context); _addImageStatus(context); }),
            _sheetItem(Icons.videocam, 'Video Status', () { Navigator.pop(context); _addVideoStatus(context); }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primary)),
      title: Text(title),
      onTap: onTap,
    );
  }

  Future<void> _addTextStatus(BuildContext context) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Text Status'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Type your status...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Upload')),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) await _service.uploadTextStatus(text);
  }

  Future<void> _addImageStatus(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 70);
    if (picked == null) return;

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    final url = await _cloudinary.uploadImage(File(picked.path));
    if (mounted) Navigator.pop(context);

    if (url != null) await _service.uploadImageUrlStatus(url);
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red));
  }

  Future<void> _addVideoStatus(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    final url = await _cloudinary.uploadVideo(File(picked.path));
    if (mounted) Navigator.pop(context);

    if (url != null) await _service.uploadVideoUrlStatus(url);
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video upload failed'), backgroundColor: Colors.red));
  }

  void _showMyStatusViewer(BuildContext context, List<StatusModel> statuses) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: statuses.length,
              itemBuilder: (context, index) => _buildStatusContent(statuses[index]),
            ),
            Positioned(top: 40, left: 16, child: Row(children: [
              const CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              const Text('My Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ])),
            Positioned(top: 40, right: 16, child: Row(children: [
              IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Status?'), content: const Text('This status will be permanently deleted.'), actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                ]));
                if (confirm == true) for (var s in statuses) await _service.deleteStatus(s.id);
              }),
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(StatusModel status) {
    if (status.type == 'video' && status.videoUrl != null) return VideoStatusPlayer(url: status.videoUrl!);
    if (status.type == 'image' && status.imageUrl != null) return Center(child: Image.network(status.imageUrl!, fit: BoxFit.contain));
    return Center(child: Container(padding: const EdgeInsets.all(40), child: Text(status.text, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center)));
  }

  void _showStatusViewer(BuildContext context, StatusModel status) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            _buildStatusContent(status),
            Positioned(top: 40, left: 16, child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.primary, backgroundImage: status.userPhoto != null && status.userPhoto!.startsWith('data:image') ? MemoryImage(_decodeBase64(status.userPhoto!)) : null, child: status.userPhoto == null || !status.userPhoto!.startsWith('data:image') ? Text(status.userName.isNotEmpty ? status.userName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null),
              const SizedBox(width: 10),
              Text(status.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ])),
            Positioned(top: 40, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  Uint8List _decodeBase64(String dataUrl) {
    final base64String = dataUrl.split(',').last;
    return base64Decode(base64String);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
          ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
          : const CircularProgressIndicator(color: Colors.white),
    );
  }
}
