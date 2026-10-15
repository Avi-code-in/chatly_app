import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../models/status_model.dart';
import '../theme.dart';
import 'status_viewer_screen.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _service = ChatService();
  final _cloudinary = CloudinaryService();
  bool _uploading = false;
  String _uploadStatus = '';

  Future<void> _handleUpload(Future<String?> Function() upload, String type) async {
    setState(() {
      _uploading = true;
      _uploadStatus = 'Uploading $type...';
    });

    final url = await upload();

    if (url != null) {
      if (type == 'image') {
        await _service.uploadImageUrlStatus(url);
      } else if (type == 'video') {
        await _service.uploadVideoUrlStatus(url);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$type uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$type upload failed. Check Cloudinary preset.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _uploading = false;
        _uploadStatus = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.white,
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: _uploading ? null : () => _showAddStatusSheet(context),
          child: _uploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Icon(Icons.edit, color: Colors.white),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Share your moments with your contacts',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.search, color: AppColors.textPrimary),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // My Status Tile
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _myStatusTile(context),
                ),
                const SizedBox(height: 24),

                // Recent Updates Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent updates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status GRID
                Expanded(
                  child: StreamBuilder<List<StatusModel>>(
                    stream: _service.getStatusesFromContacts(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _emptyState();
                      }
                      final statuses = snapshot.data!
                          .where((s) => s.userId != _service.currentUserId)
                          .toList();
                      if (statuses.isEmpty) {
                        return const Center(
                          child: Text(
                            'No recent updates from others',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }

                      // GRID LAYOUT (Side by side - 2 columns)
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: statuses.length,
                        itemBuilder: (context, index) {
                          return _statusGridTile(context, statuses[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // Upload overlay
            if (_uploading)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          _uploadStatus,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
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

  Widget _myStatusTile(BuildContext context) {
    return StreamBuilder(
      stream: _service.getCurrentUser(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final user = snapshot.data!;
        return StreamBuilder<List<StatusModel>>(
          stream: _service.getMyStatuses(),
          builder: (context, myStatusSnapshot) {
            final hasStatus = myStatusSnapshot.hasData &&
                myStatusSnapshot.data!.isNotEmpty;
            return GestureDetector(
              onTap: () {
                if (hasStatus) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatusViewerScreen(
                        statuses: myStatusSnapshot.data!,
                        isMyStatus: true,
                      ),
                    ),
                  );
                } else {
                  _showAddStatusSheet(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasStatus
                                ? const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryLight
                                    ],
                                  )
                                : null,
                            border: hasStatus
                                ? null
                                : Border.all(
                                    color: AppColors.textSecondary.withOpacity(0.3),
                                    width: 2,
                                  ),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.white,
                            backgroundImage: user.photoUrl != null &&
                                    user.photoUrl!.startsWith('data:image')
                                ? MemoryImage(_decodeBase64(user.photoUrl!))
                                : null,
                            child: user.photoUrl == null ||
                                    !user.photoUrl!.startsWith('data:image')
                                ? Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasStatus
                                ? 'Tap to view your status'
                                : 'Tap to add status update',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => _showAddStatusSheet(context),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // GRID TILE for each status
  Widget _statusGridTile(BuildContext context, StatusModel status) {
    final isNew = !status.viewers.contains(_service.currentUserId);
    return GestureDetector(
      onTap: () {
        _service.markStatusViewed(status.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatusViewerScreen(
              statuses: [status],
              isMyStatus: false,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Preview area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  width: double.infinity,
                  color: AppColors.background,
                  child: _buildPreview(status),
                ),
              ),
            ),
            // Info area
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Avatar with ring
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isNew
                          ? const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryLight
                              ],
                            )
                          : null,
                      border: isNew
                          ? null
                          : Border.all(
                              color: AppColors.textSecondary.withOpacity(0.3),
                              width: 2,
                            ),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.white,
                      backgroundImage: status.userPhoto != null &&
                              status.userPhoto!.startsWith('data:image')
                          ? MemoryImage(_decodeBase64(status.userPhoto!))
                          : null,
                      child: status.userPhoto == null ||
                              !status.userPhoto!.startsWith('data:image')
                          ? Text(
                              status.userName.isNotEmpty
                                  ? status.userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _formatTime(status.timestamp),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
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

  Widget _buildPreview(StatusModel status) {
    if (status.type == 'video' && status.videoUrl != null) {
      // Video thumbnail with play icon
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black12),
          Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      );
    }
    if (status.type == 'image' && status.imageUrl != null) {
      return Image.network(
        status.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        },
        errorBuilder: (context, error, stack) {
          return const Center(
            child: Icon(Icons.broken_image, color: AppColors.textSecondary),
          );
        },
      );
    }
    // Text status
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(
          status.text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No status updates yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the edit button to add a status',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Add Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _sheetItem(Icons.text_fields, 'Text Status', () {
              Navigator.pop(context);
              _addTextStatus(context);
            }),
            _sheetItem(Icons.image, 'Image Status', () {
              Navigator.pop(context);
              _addImageStatus(context);
            }),
            _sheetItem(Icons.videocam, 'Video Status', () {
              Navigator.pop(context);
              _addVideoStatus(context);
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
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
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Type your status...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
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
      maxWidth: 1200,
      imageQuality: 70,
    );
    if (picked == null) return;
    await _handleUpload(() => _cloudinary.uploadImage(File(picked.path)), 'image');
  }

  Future<void> _addVideoStatus(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    await _handleUpload(() => _cloudinary.uploadVideo(File(picked.path)), 'video');
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
