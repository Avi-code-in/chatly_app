import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../models/status_model.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _service = ChatService();
  final _cloudinary = CloudinaryService();
  bool _uploading = false;

  Future<void> _handleUpload(Future<String?> Function() up, String t) async {
    setState(() => _uploading = true);
    final url = await up();
    if (url != null) {
      if (t == 'image') {
        await _service.uploadImageUrlStatus(url);
      } else {
        await _service.uploadVideoUrlStatus(url);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$t uploaded!'),
          backgroundColor: Colors.green,
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Upload failed'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _sheetItem(Icons.text_fields, 'Text Status', () {
              Navigator.pop(ctx);
              _addText();
            }),
            _sheetItem(Icons.image, 'Image Status', () {
              Navigator.pop(ctx);
              _pickImg();
            }),
            _sheetItem(Icons.videocam, 'Video Status', () {
              Navigator.pop(ctx);
              _pickVid();
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(IconData i, String t, VoidCallback tap) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF5B4DFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(i, color: const Color(0xFF5B4DFF), size: 22),
        ),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: tap,
      );

  Future<void> _addText() async {
    final ctrl = TextEditingController();
    final t = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Text Status'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Type your status...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4DFF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    if (t != null && t.isNotEmpty) await _service.uploadTextStatus(t);
  }

  Future<void> _pickImg() async {
    final p = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 70);
    if (p == null) return;
    await _handleUpload(() => _cloudinary.uploadImage(File(p.path)), 'image');
  }

  Future<void> _pickVid() async {
    final p = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (p == null) return;
    await _handleUpload(() => _cloudinary.uploadVideo(File(p.path)), 'video');
  }

  void _openViewer(List<StatusModel> statuses, int idx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StatusViewer(statuses: statuses, start: idx, service: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFD5DDFF).withOpacity(0.6),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B1F3A),
                              letterSpacing: -0.5,
                            )),
                        const SizedBox(height: 2),
                        Text('Share your moments with your contacts',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.black.withOpacity(0.5),
                            )),
                        const SizedBox(height: 6),
                        Container(
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFF5B4DFF),
                              Color(0xFF7C4DFF)
                            ]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt_outlined,
                          color: Color(0xFF0B1F3A), size: 22),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // MY STATUS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder(
                  stream: _service.getCurrentUser(),
                  builder: (ctx, snap) {
                    if (!snap.hasData || snap.data == null) {
                      return const SizedBox.shrink();
                    }
                    final u = snap.data!;
                    return StreamBuilder<List<StatusModel>>(
                      stream: _service.getMyStatuses(),
                      builder: (ctx, ms) {
                        final has = ms.hasData && ms.data!.isNotEmpty;
                        return GestureDetector(
                          onTap: () {
                            if (has) {
                              _openViewer(ms.data!, 0);
                            } else {
                              _showAddSheet();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE8F0FF),
                                  Color(0xFFEDE5FF),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: has
                                            ? const LinearGradient(colors: [
                                                Color(0xFF5B4DFF),
                                                Color(0xFF7C4DFF)
                                              ])
                                            : null,
                                        border: has
                                            ? null
                                            : Border.all(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                width: 2),
                                      ),
                                      child: CircleAvatar(
                                        radius: 26,
                                        backgroundColor: Colors.white,
                                        backgroundImage: u.photoUrl != null &&
                                                u.photoUrl!.isNotEmpty &&
                                                (u.photoUrl!
                                                        .startsWith('data:image') ||
                                                    u.photoUrl!
                                                        .startsWith('http'))
                                            ? (u.photoUrl!
                                                    .startsWith('data:image')
                                                ? MemoryImage(_b64(u.photoUrl!))
                                                : CachedNetworkImageProvider(
                                                    u.photoUrl!))
                                            : null,
                                        child: u.photoUrl == null ||
                                                u.photoUrl!.isEmpty ||
                                                (!u.photoUrl!
                                                        .startsWith('data:image') &&
                                                    !u.photoUrl!
                                                        .startsWith('http'))
                                            ? Text(
                                                u.name.isNotEmpty
                                                    ? u.name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Color(0xFF5B4DFF),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ))
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF5B4DFF),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.add,
                                            color: Colors.white, size: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('My Status',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0B1F3A),
                                          )),
                                      SizedBox(height: 4),
                                      Text('Tap to add status update',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF5A6B8A),
                                          )),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 14, color: Color(0xFF8F92A1)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // RECENT UPDATES
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recent updates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black.withOpacity(0.75),
                      )),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<List<StatusModel>>(
                  stream: _service.getStatusesFromContacts(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF5B4DFF)));
                    }
                    final list = (snap.data ?? [])
                        .where((s) =>
                            s.userId != _service.currentUserId &&
                            !s.isExpired)
                        .toList();
                    if (list.isEmpty) return _emptyState();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final s = list[i];
                        return GestureDetector(
                          onTap: () => _openViewer(list, i),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              children: [
                                _ringAvatar(s.userPhoto, s.userName, 26,
                                    !s.viewers.contains(_service.currentUserId)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.userName,
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0B1F3A),
                                          )),
                                      const SizedBox(height: 3),
                                      Text(_fmtTime(s.timestamp),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF8F92A1),
                                          )),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.more_horiz,
                                    color: Color(0xFF8F92A1)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // FAB
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTap: _uploading ? null : _showAddSheet,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B4DFF), Color(0xFF7C4DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B4DFF).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _uploading
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Icon(Icons.edit, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.access_time,
                    size: 100,
                    color: const Color(0xFF8F92A1).withOpacity(0.35)),
                Positioned(
                  top: 10,
                  right: 0,
                  child: Icon(Icons.star,
                      size: 14, color: const Color(0xFF9C8FFF).withOpacity(0.6)),
                ),
                Positioned(
                  bottom: 10,
                  left: 5,
                  child: Icon(Icons.star,
                      size: 10, color: const Color(0xFF9C8FFF).withOpacity(0.5)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('No status updates yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1F3A),
                )),
            const SizedBox(height: 8),
            const Text('Tap the edit button to add a status',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF8F92A1),
                )),
          ],
        ),
      );

  Widget _ringAvatar(String? photo, String name, double r, bool isNew) {
    final has = photo != null &&
        photo.isNotEmpty &&
        (photo.startsWith('data:image') || photo.startsWith('http'));
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isNew
            ? const LinearGradient(colors: [
                Color(0xFF5B4DFF),
                Color(0xFF7C4DFF),
              ])
            : null,
        border: isNew
            ? null
            : Border.all(color: Colors.black.withOpacity(0.08), width: 2),
      ),
      child: CircleAvatar(
        radius: r,
        backgroundColor: const Color(0xFF5B4DFF).withOpacity(0.15),
        backgroundImage: has
            ? (photo.startsWith('data:image')
                ? MemoryImage(_b64(photo))
                : CachedNetworkImageProvider(photo) as ImageProvider)
            : null,
        child: !has
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFF5B4DFF),
                    fontSize: 18,
                    fontWeight: FontWeight.bold))
            : null,
      ),
    );
  }

  String _fmtTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Uint8List _b64(String d) => base64Decode(d.split(',').last);
}

// ==================== VIEWER ====================
class _StatusViewer extends StatefulWidget {
  final List<StatusModel> statuses;
  final int start;
  final ChatService service;
  const _StatusViewer(
      {required this.statuses, required this.start, required this.service});

  @override
  State<_StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<_StatusViewer> {
  late PageController _pc;
  late int _cur;

  @override
  void initState() {
    super.initState();
    _cur = widget.start;
    _pc = PageController(initialPage: _cur);
    widget.service.markStatusViewed(widget.statuses[_cur].id);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pc,
              onPageChanged: (i) {
                setState(() => _cur = i);
                widget.service.markStatusViewed(widget.statuses[i].id);
              },
              itemCount: widget.statuses.length,
              itemBuilder: (c, i) {
                final s = widget.statuses[i];
                if (s.type == 'image' && s.imageUrl != null) {
                  return Center(
                      child: CachedNetworkImage(
                          imageUrl: s.imageUrl!, fit: BoxFit.contain));
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(s.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
            // Progress
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: List.generate(
                    widget.statuses.length,
                    (i) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 3,
                            decoration: BoxDecoration(
                              color: i <= _cur ? Colors.white : Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        )),
              ),
            ),
            // Header
            Positioned(
              top: 24,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Text(widget.statuses[_cur].userName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
