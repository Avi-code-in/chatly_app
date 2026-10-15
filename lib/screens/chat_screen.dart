import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../theme.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/location_message_bubble.dart';
import '../widgets/voice_recorder_bar.dart';
import '../widgets/full_screen_image.dart';
import 'group_info_screen.dart';
import 'chat_lock_screen.dart';
import 'schedule_message_screen.dart';
import 'qr_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String? otherUserPhoto;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _chatService = ChatService();
  final _cloudinary = CloudinaryService();
  final _imagePicker = ImagePicker();
  bool _showEmoji = false;
  MessageModel? _replyTo;
  bool _recording = false;

  // Chat lock
  bool _isLocked = false;
  bool _unlocked = false;

  bool get isGroupChat => widget.chatId.startsWith('group_');
  String get groupId =>
      isGroupChat ? widget.chatId.replaceFirst('group_', '') : '';

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsSeen(widget.chatId);
    _chatService.deleteExpiredMessages(widget.chatId);
    _checkLock();
  }

  Future<void> _checkLock() async {
    try {
      final locked = await _chatService.isChatLocked(widget.chatId).first;
      if (mounted) {
        setState(() {
          _isLocked = locked;
          _unlocked = !locked;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _unlocked = true);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // ============ SEND TEXT ============
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_replyTo != null) {
      await _chatService.sendReplyMessage(
        widget.chatId,
        text,
        replyToId: _replyTo!.id,
        replyToText: _replyTo!.type == 'text'
            ? _replyTo!.text
            : _replyTo!.type == 'image'
                ? '📷 Photo'
                : _replyTo!.type == 'voice'
                    ? '🎤 Voice'
                    : _replyTo!.type == 'location'
                        ? '📍 Location'
                        : '📎 File',
        replyToSender: _replyTo!.senderId,
      );
      setState(() => _replyTo = null);
    } else {
      await _chatService.sendMessage(widget.chatId, text);
    }

    _messageController.clear();
    setState(() => _showEmoji = false);
  }

  // ============ VOICE ============
  Future<void> _onVoiceSend(
      File file, int duration, String? transcription) async {
    setState(() => _recording = false);
    _showLoader('Sending voice...');
    final url = await _cloudinary.uploadVoice(file);
    if (mounted) Navigator.pop(context);
    if (url != null) {
      await _chatService.sendVoiceMessage(
          widget.chatId, url, duration, transcription);
    } else {
      _showError('Voice upload failed');
    }
  }

  // ============ LOCATION ============
  Future<void> _sendCurrentLocation({bool isLive = false}) async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      _showError('Location permission denied');
      return;
    }
    _showLoader('Getting location...');
    try {
      final pos = await Geolocator.getCurrentPosition();
      final address =
          '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';

      await _chatService.sendLocationMessage(
        widget.chatId,
        pos.latitude,
        pos.longitude,
        address,
        isLive: isLive,
        liveDuration: isLive ? const Duration(hours: 1) : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Location error: \${e}');
    }
  }

  // ============ DISAPPEARING ============
  void _showDisappearingOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StreamBuilder<int?>(
        stream: _chatService.getDisappearingHours(widget.chatId),
        builder: (context, snapshot) {
          final current = snapshot.data;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text('Disappearing messages',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'New messages will disappear after selected time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                _disappearingOption('Off', null, current),
                _disappearingOption('24 hours', 24, current),
                _disappearingOption('7 days', 24 * 7, current),
                _disappearingOption('90 days', 24 * 90, current),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _disappearingOption(String label, int? hours, int? current) {
    final selected = hours == current;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(label),
      onTap: () async {
        await _chatService.setDisappearingMessages(widget.chatId, hours);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  // ============ ATTACHMENT ============
  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _attachItem(Icons.photo_library, 'Gallery',
                const Color(0xFF9C27B0), () {
              Navigator.pop(context);
              _pickImageFromGallery();
            }),
            _attachItem(Icons.camera_alt, 'Camera', const Color(0xFFE91E63),
                () {
              Navigator.pop(context);
              _pickImageFromCamera();
            }),
            _attachItem(Icons.insert_drive_file, 'Document',
                const Color(0xFF2196F3), () {
              Navigator.pop(context);
              _pickDocument();
            }),
            _attachItem(Icons.videocam, 'Video', const Color(0xFFFF5722), () {
              Navigator.pop(context);
              _pickVideo();
            }),
            _attachItem(Icons.location_on, 'Location',
                const Color(0xFF4CAF50), () {
              Navigator.pop(context);
              _sendCurrentLocation();
            }),
            _attachItem(Icons.my_location, 'Live Location',
                const Color(0xFF00BCD4), () {
              Navigator.pop(context);
              _sendCurrentLocation(isLive: true);
            }),
          ],
        ),
      ),
    );
  }

  Widget _attachItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 75);
    if (picked == null) return;
    _uploadAndSend(picked.path, 'image');
  }

  Future<void> _pickImageFromCamera() async {
    final picked = await _imagePicker.pickImage(
        source: ImageSource.camera, maxWidth: 1600, imageQuality: 75);
    if (picked == null) return;
    _uploadAndSend(picked.path, 'image');
  }

  Future<void> _pickVideo() async {
    final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    _uploadAndSend(picked.path, 'video');
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.isEmpty) return;
    final file = result.first;
    if (file.path == null) return;
    _uploadAndSend(file.path!, 'file');
  }

  Future<void> _uploadAndSend(String path, String type) async {
    _showLoader('Uploading...');
    final file = File(path);
    String? url;
    if (type == 'image') {
      url = await _cloudinary.uploadImage(file);
    } else if (type == 'video') {
      url = await _cloudinary.uploadVideo(file);
    } else {
      url = await _cloudinary.uploadFile(file, path.split('/').last);
    }
    if (mounted) Navigator.pop(context);
    if (url != null) {
      if (type == 'image') {
        await _chatService.sendImageUrlMessage(widget.chatId, url);
      } else if (type == 'video') {
        await _chatService.sendVideoUrlMessage(widget.chatId, url);
      } else {
        await _chatService.sendFileUrlMessage(
            widget.chatId, path.split('/').last, url);
      }
    } else {
      _showError('Upload failed. Check Cloudinary.');
    }
  }

  void _showLoader(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(msg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4)),
    );
  }

  // ============ REACTIONS ============
  void _showReactionSheet(MessageModel msg, bool isMe) {
    final quickEmojis = ['❤️', '😂', '😮', '😢', '👍', '🙏'];
    final myReaction = msg.reactions.entries
        .where((e) => e.value.contains(_chatService.currentUserId))
        .map((e) => e.key)
        .firstOrNull;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: quickEmojis.map((emoji) {
                  final sel = myReaction == emoji;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      if (sel) {
                        await _chatService.removeReaction(
                            widget.chatId, msg.id);
                      } else {
                        await _chatService.addReaction(
                            widget.chatId, msg.id, emoji);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary.withOpacity(0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child:
                          Text(emoji, style: const TextStyle(fontSize: 30)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            if (msg.type == 'text')
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text));
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = msg);
              },
            ),
            ListTile(
              leading: Icon(
                msg.isStarredBy(_chatService.currentUserId)
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.amber,
              ),
              title: Text(msg.isStarredBy(_chatService.currentUserId)
                  ? 'Unstar'
                  : 'Star'),
              onTap: () {
                Navigator.pop(context);
                _chatService.toggleStar(widget.chatId, msg.id);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _chatService.deleteMessage(widget.chatId, msg.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: groupId)));
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    // CHAT LOCK CHECK
    if (_isLocked && !_unlocked) {
      return ChatLockScreen(
        onUnlock: () => setState(() => _unlocked = true),
      );
    }

    final hasImage = widget.otherUserPhoto != null &&
        widget.otherUserPhoto!.isNotEmpty &&
        (widget.otherUserPhoto!.startsWith('data:image') ||
         widget.otherUserPhoto!.startsWith('http'));

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            GestureDetector(
              onTap: isGroupChat
                  ? _showGroupInfo
                  : () => showProfilePicture(
                        context,
                        name: widget.otherUserName,
                        photoUrl: widget.otherUserPhoto,
                        subtitle: 'Online',
                      ),
              child: isGroupChat
                  ? Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.group,
                          color: Colors.white, size: 22),
                    )
                  : CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      child: ClipOval(
                        child: hasImage
                            ? (widget.otherUserPhoto!.startsWith('data:image')
                                ? Image.memory(
                                    _decodeBase64(widget.otherUserPhoto!),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: widget.otherUserPhoto!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    placeholder: (c, u) => const Icon(Icons.person, color: Colors.white),
                                    errorWidget: (c, u, e) => const Icon(Icons.person, color: Colors.white),
                                  ))
                            : Center(
                                child: Text(
                                  widget.otherUserName.isNotEmpty
                                      ? widget.otherUserName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  StreamBuilder<int?>(
                    stream:
                        _chatService.getDisappearingHours(widget.chatId),
                    builder: (context, snap) {
                      if (snap.data != null) {
                        return const Row(
                          children: [
                            Icon(Icons.timer,
                                color: Colors.white70, size: 11),
                            SizedBox(width: 3),
                            Text('Disappearing messages',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        );
                      }
                      return Text(
                        isGroupChat ? 'Tap for group info' : 'Online',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isGroupChat) ...[
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: () {},
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'disappearing') _showDisappearingOptions();
              if (value == 'group_info' && isGroupChat) _showGroupInfo();
              if (value == 'lock') {
                await _chatService.lockChat(widget.chatId, !_isLocked);
                setState(() => _isLocked = !_isLocked);
              }
              if (value == 'schedule') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ScheduleMessageScreen(chatId: widget.chatId),
                  ),
                );
              }
              if (value == 'qr') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QRChatScreen(
                      chatId: widget.chatId,
                      userName: widget.otherUserName,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'disappearing',
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 20),
                    SizedBox(width: 12),
                    Text('Disappearing messages'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'lock',
                child: Row(
                  children: [
                    Icon(_isLocked ? Icons.lock : Icons.lock_open, size: 20),
                    const SizedBox(width: 12),
                    Text(_isLocked ? 'Unlock chat' : 'Lock chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'schedule',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20),
                    SizedBox(width: 12),
                    Text('Schedule message'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'qr',
                child: Row(
                  children: [
                    Icon(Icons.qr_code, size: 20),
                    SizedBox(width: 12),
                    Text('Share QR code'),
                  ],
                ),
              ),
              if (isGroupChat)
                const PopupMenuItem(
                  value: 'group_info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Group info'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyState();
                }
                final messages =
                    snapshot.data!.where((m) => !m.isExpired).toList();
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _chatService.currentUserId;
                    return GestureDetector(
                      onLongPress: () => _showReactionSheet(msg, isMe),
                      child: _buildMessageBubble(msg, isMe),
                    );
                  },
                );
              },
            ),
          ),
          if (_replyTo != null) _replyPreview(),
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                  setState(() {});
                },
                config: const Config(
                    height: 280, checkPlatformCompatibility: true),
              ),
            ),
          if (_recording)
            VoiceRecorderBar(
              onSend: _onVoiceSend,
              onCancel: () => setState(() => _recording = false),
            )
          else
            _buildInputBar(),
        ],
      ),
    );
  }

  Widget _replyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.white,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Replying to',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                Text(
                  _replyTo!.type == 'text'
                      ? _replyTo!.text
                      : _replyTo!.type == 'image'
                          ? '📷 Photo'
                          : _replyTo!.type == 'voice'
                              ? '🎤 Voice'
                              : _replyTo!.type == 'location'
                                  ? '📍 Location'
                                  : '📎 File',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _showEmoji
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                      onPressed: () =>
                          setState(() => _showEmoji = !_showEmoji),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        maxLines: null,
                        onTap: () {
                          if (_showEmoji)
                            setState(() => _showEmoji = false);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file,
                          color: AppColors.textSecondary, size: 24),
                      onPressed: _showAttachmentSheet,
                    ),
                    if (_messageController.text.isEmpty)
                      IconButton(
                        icon: const Icon(Icons.camera_alt,
                            color: AppColors.textSecondary, size: 24),
                        onPressed: _pickImageFromCamera,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.blueGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.blueShadow,
              ),
              child: IconButton(
                icon: Icon(
                  _messageController.text.isEmpty ? Icons.mic : Icons.send,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: _messageController.text.isEmpty
                    ? () => setState(() => _recording = true)
                    : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 60,
              color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No messages yet.\nSend the first message!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final isStarred = msg.isStarredBy(_chatService.currentUserId);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.all(8),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFDCF8C6) : AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isMe
                    ? const Radius.circular(12)
                    : const Radius.circular(2),
                bottomRight: isMe
                    ? const Radius.circular(2)
                    : const Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.replyToId != null) _replyPreviewInBubble(msg),
                if (msg.type == 'image' && msg.imageUrl != null)
                  GestureDetector(
                    onTap: () => showFullScreenImage(
                      context,
                      msg.imageUrl!,
                      senderName: isMe ? 'You' : widget.otherUserName,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: msg.imageUrl!,
                        width: 220,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(
                          width: 220,
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        errorWidget: (c, u, e) => const SizedBox(
                            width: 220,
                            height: 100,
                            child: Icon(Icons.broken_image)),
                      ),
                    ),
                  )
                else if (msg.type == 'video' && msg.videoUrl != null)
                  Container(
                    width: 220,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 50),
                  )
                else if (msg.type == 'voice' && msg.voiceUrl != null)
                  VoiceMessageBubble(
                    voiceUrl: msg.voiceUrl!,
                    duration: msg.voiceDuration ?? 0,
                    isMe: isMe,
                    transcribedText: msg.transcribedText,
                  )
                else if (msg.type == 'location' &&
                    msg.latitude != null &&
                    msg.longitude != null)
                  LocationMessageBubble(
                    latitude: msg.latitude!,
                    longitude: msg.longitude!,
                    address: msg.locationAddress,
                    isLive: msg.isLiveLocation,
                    liveExpiresAt: msg.liveLocationExpiresAt,
                    isMe: isMe,
                  )
                else if (msg.type == 'file')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file,
                          color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          msg.fileName ?? 'File',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          height: 1.3),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.expiresAt != null)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.timer,
                              size: 11, color: Colors.grey),
                        ),
                      if (isStarred)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child:
                              Icon(Icons.star, size: 12, color: Colors.amber),
                        ),
                      Text(
                        _formatMsgTime(msg.timestamp),
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.seen ? Icons.done_all : Icons.done,
                          size: 14,
                          color: msg.seen
                              ? const Color(0xFF53BDEB)
                              : Colors.grey[600],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (msg.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: msg.reactions.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.key,
                              style: const TextStyle(fontSize: 14)),
                          if (entry.value.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Text(
                                '${entry.value.length}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _replyPreviewInBubble(MessageModel msg) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.replyToSender == _chatService.currentUserId
                ? 'You'
                : widget.otherUserName,
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            msg.replyToText ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Uint8List _decodeBase64(String dataUrl) {
    final base64String = dataUrl.split(',').last;
    return base64Decode(base64String);
  }

  String _formatMsgTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}
