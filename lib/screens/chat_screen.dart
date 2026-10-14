import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../theme.dart';

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
  bool _showEmoji = false;

  bool get isGroupChat => widget.chatId.startsWith('group_');
  String get groupId => isGroupChat ? widget.chatId.replaceFirst('group_', '') : '';

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsSeen(widget.chatId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    setState(() => _showEmoji = false);
    await _chatService.sendMessage(widget.chatId, text);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 70);
    if (picked == null) return;

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    final url = await _cloudinary.uploadImage(File(picked.path));
    if (mounted) Navigator.pop(context);

    if (url != null) await _chatService.sendImageUrlMessage(widget.chatId, url);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.isEmpty) return;
    final file = result.first;

    final lower = file.name.toLowerCase();
    final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp');

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));

    if (isImage) {
      final url = await _cloudinary.uploadImage(File(file.path!));
      if (mounted) Navigator.pop(context);
      if (url != null) await _chatService.sendImageUrlMessage(widget.chatId, url);
    } else {
      final url = await _cloudinary.uploadFile(File(file.path!), file.name);
      if (mounted) Navigator.pop(context);
      if (url != null) await _chatService.sendFileUrlMessage(widget.chatId, file.name, url);
    }
  }

  // Group management UI
  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return FutureBuilder<GroupModel?>(
            future: _chatService.getGroupById(groupId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              final group = snapshot.data!;
              final isAdmin = group.admins.contains(_chatService.currentUserId);
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.group, color: AppColors.primary, size: 40),
                        ),
                        const SizedBox(height: 12),
                        Text(group.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('${group.members.length} members', style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...group.members.map((uid) {
                    return FutureBuilder<UserModel?>(
                      future: _chatService.getUserById(uid),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData || userSnap.data == null) return const SizedBox.shrink();
                        final user = userSnap.data!;
                        final isUserAdmin = group.admins.contains(uid);
                        return ListTile(
                          leading: CircleAvatar(child: Text(user.name[0].toUpperCase())),
                          title: Text(user.name),
                          subtitle: Text(isUserAdmin ? 'Admin' : 'Member'),
                          trailing: isAdmin && uid != _chatService.currentUserId
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () async {
                                    await _chatService.removeMemberFromGroup(groupId, uid);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed')));
                                  },
                                )
                              : null,
                        );
                      },
                    );
                  }).toList(),
                  const Divider(),
                  if (isAdmin)
                    ListTile(
                      leading: const Icon(Icons.person_add, color: AppColors.primary),
                      title: const Text('Add Member'),
                      onTap: () async {
                        Navigator.pop(context);
                        _showAddMemberDialog(groupId, group.members);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                    title: const Text('Leave Group'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _chatService.leaveGroup(groupId);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  if (isAdmin)
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Delete Group'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _chatService.deleteGroup(groupId);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAddMemberDialog(String groupId, List<String> currentMembers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => FutureBuilder<List<UserModel>>(
        future: _chatService.getUsers().first,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          final users = snapshot.data!.where((u) => !currentMembers.contains(u.uid)).toList();
          if (users.isEmpty) return const Center(child: Text('No new users to add'));
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(child: Text(user.name[0].toUpperCase())),
                title: Text(user.name),
                onTap: () async {
                  await _chatService.addMemberToGroup(groupId, user.uid);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added')));
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showMessageOptions(MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            if (msg.type == 'text')
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.textPrimary),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
                },
              ),
            ListTile(
              leading: const Icon(Icons.forward, color: AppColors.textPrimary),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                _showForwardDialog(msg);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _chatService.deleteMessage(widget.chatId, msg.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showForwardDialog(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        Set<String> selectedUsers = {};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Text('Forward to (${selectedUsers.length}/10)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: StreamBuilder<List<UserModel>>(
                      stream: _chatService.getUsers(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        final users = snapshot.data!;
                        return ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final isSelected = selectedUsers.contains(user.uid);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (v) {
                                if (v == true && selectedUsers.length < 10) {
                                  setModalState(() => selectedUsers.add(user.uid));
                                } else if (v == false) {
                                  setModalState(() => selectedUsers.remove(user.uid));
                                }
                              },
                              title: Text(user.name),
                              secondary: CircleAvatar(child: Text(user.name[0].toUpperCase())),
                              activeColor: AppColors.primary,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: selectedUsers.isEmpty ? null : () async {
                        Navigator.pop(context);
                        await _chatService.forwardMessage(msg, selectedUsers.toList());
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message forwarded!')));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Forward', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.otherUserPhoto != null && widget.otherUserPhoto!.startsWith('data:image');

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: isGroupChat ? null : () {
                if (hasImage) {
                  showDialog(context: context, builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: InteractiveViewer(child: Image.memory(_decodeBase64(widget.otherUserPhoto!))),
                  ));
                }
              },
              child: isGroupChat
                  ? Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.group, color: Colors.white, size: 22))
                  : CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      backgroundImage: hasImage ? MemoryImage(_decodeBase64(widget.otherUserPhoto!)) : null,
                      child: !hasImage ? Text(widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)) : null,
                    ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUserName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                Text(isGroupChat ? 'Group' : 'Online', style: const TextStyle(color: AppColors.online, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          if (!isGroupChat) ...[
            IconButton(icon: const Icon(Icons.videocam_outlined, color: AppColors.primary), onPressed: () {}),
            IconButton(icon: const Icon(Icons.call_outlined, color: AppColors.primary), onPressed: () {}),
          ],
          if (isGroupChat)
            IconButton(icon: const Icon(Icons.info_outline, color: AppColors.primary), onPressed: _showGroupInfo),
          IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textPrimary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: AppColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('No messages yet.\nSend the first message!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  );
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _chatService.currentUserId;
                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(msg, isMe),
                      child: _buildMessageBubble(msg, isMe),
                    );
                  },
                );
              },
            ),
          ),
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                  setState(() {});
                },
                config: const Config(height: 280, checkPlatformCompatibility: true),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), AppColors.primaryLight.withOpacity(0.1)]), shape: BoxShape.circle),
                    child: IconButton(icon: const Icon(Icons.add, color: AppColors.primary, size: 22), onPressed: _pickFile),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      onTap: () { if (_showEmoji) setState(() => _showEmoji = false); },
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: AppColors.textSecondary), onPressed: () => setState(() => _showEmoji = !_showEmoji)),
                  IconButton(icon: const Icon(Icons.attach_file, color: AppColors.textSecondary), onPressed: _pickFile),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.bubbleMe : AppColors.bubbleOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
          boxShadow: isMe ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.type == 'image' && msg.imageUrl != null)
              GestureDetector(
                onTap: () => showDialog(context: context, builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(10),
                  child: InteractiveViewer(child: Image.network(msg.imageUrl!)),
                )),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(msg.imageUrl!, width: 200, fit: BoxFit.cover)),
              )
            else if (msg.type == 'video' && msg.videoUrl != null)
              Container(
                width: 200, height: 150,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50)),
              )
            else if (msg.type == 'file' && msg.fileName != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file, color: isMe ? Colors.white : AppColors.primary),
                  const SizedBox(width: 8),
                  Flexible(child: Text(msg.fileName!, style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14))),
                ],
              )
            else
              Text(msg.text, style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 15, height: 1.4)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatMsgTime(msg.timestamp), style: TextStyle(color: isMe ? Colors.white70 : AppColors.textSecondary, fontSize: 11)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(msg.seen ? Icons.done_all : Icons.done, size: 14, color: msg.seen ? Colors.lightBlueAccent : Colors.white70),
                ],
              ],
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

  String _formatMsgTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}
