import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../models/status_model.dart';
import '../theme.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _service = ChatService();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: AppColors.primary, size: 28),
                  onPressed: () => _showAddStatusSheet(context),
                ),
              ],
            ),
          ),
          _myStatusTile(context),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent updates',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StatusModel>>(
              stream: _service.getStatuses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time,
                            size: 80,
                            color:
                                AppColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No status updates yet',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final statuses = snapshot.data!
                    .where((s) => s.userId != _service.currentUserId)
                    .toList();
                if (statuses.isEmpty) {
                  return const Center(
                    child: Text(
                      'No status updates from others',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: statuses.length,
                  itemBuilder: (context, index) {
                    return _statusTile(context, statuses[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _myStatusTile(BuildContext context) {
    return StreamBuilder(
      stream: _service.getCurrentUser(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final user = snapshot.data!;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: _avatar(user.photoUrl, user.name, 28, true),
          title: const Text(
            'My Status',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: const Text(
            'Tap to add status update',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          onTap: () => _showAddStatusSheet(context),
        );
      },
    );
  }

  Widget _statusTile(BuildContext context, StatusModel status) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: _avatar(status.userPhoto, status.userName, 28, false),
      title: Text(
        status.userName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        _formatTime(status.timestamp),
        style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13),
      ),
      onTap: () {
        _service.markStatusViewed(status.id);
        _showStatusViewer(context, status);
      },
    );
  }

  Widget _avatar(
      String? photo, String name, double radius, bool addIcon) {
    final hasImage = photo != null && photo.startsWith('data:image');
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.white,
            backgroundImage: hasImage
                ? MemoryImage(_decodeBase64(photo))
                : null,
            child: !hasImage
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.7,
                    ),
                  )
                : null,
          ),
        ),
        if (addIcon)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add,
                  color: Colors.white, size: 14),
            ),
          ),
      ],
    );
  }

  void _showAddStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.text_fields,
                  color: AppColors.primary),
              title: const Text('Text Status'),
              onTap: () {
                Navigator.pop(context);
                _addTextStatus(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: AppColors.primary),
              title: const Text('Image Status'),
              onTap: () {
                Navigator.pop(context);
                _addImageStatus(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _addTextStatus(BuildContext context) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Text Status'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type your status...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      await _service.uploadTextStatus(text);
    }
  }

  Future<void> _addImageStatus(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    await _service.uploadImageStatus(base64Image);
  }

  void _showStatusViewer(BuildContext context, StatusModel status) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: status.type == 'image' && status.imageData != null
                  ? Image.memory(_decodeBase64(status.imageData!))
                  : Container(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        status.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      status.userName.isNotEmpty
                          ? status.userName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
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
