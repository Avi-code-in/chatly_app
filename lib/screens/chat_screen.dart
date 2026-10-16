import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../services/call_service.dart';
import '../services/translation_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../theme.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/location_message_bubble.dart';
import '../widgets/voice_recorder_bar.dart';
import '../widgets/full_screen_image.dart';
import '../widgets/video_player_widget.dart';
import 'group_info_screen.dart';
import 'call_screen.dart';
import 'schedule_message_screen.dart';
import 'pin_setup_screen.dart';
import 'pin_unlock_screen.dart';

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
  final _chatService = ChatService();
  final _cloudinary = CloudinaryService();
  final _translationService = TranslationService();

  MessageModel? _replyTo;
  Timer? _typingTimer;
  bool _liveTypingOn = true;
  String? _otherTypingText;
  String? _otherUserId;
  bool _recording = false;
  bool _chatLocked = false;
  bool _unlocked = false;
  bool _initialCheckDone = false;

  bool _selectionMode = false;
  final Set<String> _selectedMessages = {};
  final Map<String, String> _translatedMessages = {};
  final Map<String, String> _translatedLanguages = {};
  String _myLanguage = 'en';

  bool get isGroupChat => widget.chatId.startsWith('group_');
  String get groupId =>
      isGroupChat ? widget.chatId.replaceFirst('group_', '') : '';

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsSeen(widget.chatId);
    _checkLock();
    _startWorker();
    _loadLanguage();
    _loadOtherUserId();
    _loadLiveTypingSetting();
  }

  Future<void> _loadOtherUserId() async {
    try {
      final u = await _chatService.getOtherUser(widget.chatId);
      if (u != null && mounted) {
        setState(() => _otherUserId = u.uid);
        _listenOtherTyping();
      }
    } catch (_) {}
  }

  void _listenOtherTyping() {
    if (_otherUserId == null) return;
    _chatService.listenOtherUserTyping(widget.chatId, _otherUserId!).listen((txt) {
      if (!mounted) return;
      setState(() => _otherTypingText = txt);
    });
  }

  Future<void> _loadLiveTypingSetting() async {
    try {
      final user = await _chatService.getCurrentUser().first;
      if (user != null && mounted) {
        setState(() => _liveTypingOn = user.liveTypingEnabled);
      }
    } catch (_) {}
  }

  void _onMessageChanged(String text) {
    if (!_liveTypingOn) return;
    _typingTimer?.cancel();
    if (text.trim().isEmpty) {
      _chatService.clearTypingStatus(widget.chatId);
      return;
    }
    _typingTimer = Timer(const Duration(milliseconds: 400), () {
      _chatService.updateTypingStatus(widget.chatId, text);
    });
  }

  Future<void> _loadLanguage() async {
    try {
      final user = await _chatService.getCurrentUser().first;
      if (user != null && mounted) {
        setState(() => _myLanguage = user.preferredLanguage);
      }
    } catch (_) {}
  }

  void _startWorker() {
    _chatService.deleteExpiredMessages(widget.chatId);
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) _startWorker();
    });
  }

  Future<void> _checkLock() async {
    try {
      final hasPin = await _chatService.hasChatPin(widget.chatId);
      if (mounted) {
        setState(() {
          _chatLocked = hasPin;
          _unlocked = !hasPin;
          _initialCheckDone = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialCheckDone = true;
          _unlocked = true;
        });
      }
    }
  }

  // ==================== CALL ====================
  Future<void> _startCall(String type) async {
    if (isGroupChat) {
      _snack('Group calls coming soon');
      return;
    }
    try {
      final otherUser = await _chatService.getOtherUser(widget.chatId);
      if (otherUser == null) {
        _snack('User not found');
        return;
      }
      final callId = await CallService().startCall(otherUser.uid, type);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: callId,
              otherUserId: otherUser.uid,
              otherUserName: otherUser.name,
              otherUserPhoto: otherUser.photoUrl,
              callType: type,
              isCaller: true,
            ),
          ),
        );
      }
    } catch (e) {
      _snack('Call failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ==================== SEND ====================
  void _sendText(String text) {
    if (text.trim().isEmpty) return;
    if (_replyTo != null) {
      final reply = _replyTo!;
      _chatService.sendReplyMessage(
        widget.chatId,
        text,
        replyToId: reply.id,
        replyToText: reply.type == 'text' ? reply.text : 'Attachment',
        replyToSender: reply.senderId,
      );
    } else {
      _chatService.sendMessageWithAutoReply(widget.chatId, text);
    }
  }

  // ==================== VOICE ====================
  Future<void> _onVoiceSend(File file, int duration, String? txt) async {
    setState(() => _recording = false);
    _loader('Sending voice...');
    final url = await _cloudinary.uploadVoice(file);
    if (mounted) Navigator.pop(context);
    if (url != null) {
      await _chatService.sendVoiceMessage(widget.chatId, url, duration, txt);
    } else {
      _snack('Voice upload failed');
    }
  }

  // ==================== LOCATION ====================
  Future<void> _sendLocation({bool isLive = false}) async {
    final st = await Permission.location.request();
    if (!st.isGranted) {
      _snack('Location permission denied');
      return;
    }
    _loader('Getting location...');
    try {
      final pos = await Geolocator.getCurrentPosition();
      final addr =
          '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      await _chatService.sendLocationMessage(
        widget.chatId,
        pos.latitude,
        pos.longitude,
        addr,
        isLive: isLive,
        liveDuration: isLive ? const Duration(hours: 1) : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack('Location error');
    }
  }

  void _loader(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF2196F3)),
                const SizedBox(height: 16),
                Text(msg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TRANSLATION ====================
  String? _getTranslation(MessageModel msg) => _translatedMessages[msg.id];
  String? _getTranslationLang(MessageModel msg) =>
      _translatedLanguages[msg.id];

  void _showTranslateDialog(MessageModel msg) {
    String selected = _myLanguage;
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.translate, color: Color(0xFF2196F3)),
              SizedBox(width: 10),
              Text('Translate'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Original:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(msg.text, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 16),
              const Text('Translate to:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selected,
                    isExpanded: true,
                    items: TranslationService.languages.entries
                        .map((e) =>
                            DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDlg(() => selected = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      setDlg(() => loading = true);
                      final t = await _translationService.translate(
                          msg.text, selected);
                      setDlg(() => loading = false);
                      if (t != null && mounted) {
                        setState(() {
                          _translatedMessages[msg.id] = t;
                          _translatedLanguages[msg.id] =
                              TranslationService.languages[selected] ?? '';
                        });
                      }
                      Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Translate'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DELETE ====================
  Future<void> _deleteSelected() async {
    if (_selectedMessages.isEmpty) return;
    final c = _selectedMessages.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $c message${c > 1 ? 's' : ''}?'),
        content: const Text('Deleted for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      for (var id in _selectedMessages) {
        await _chatService.deleteMessage(widget.chatId, id);
      }
      _clearSel();
    }
  }

  void _toggleSel(String id) {
    setState(() {
      if (_selectedMessages.contains(id)) {
        _selectedMessages.remove(id);
        if (_selectedMessages.isEmpty) _selectionMode = false;
      } else {
        _selectedMessages.add(id);
        _selectionMode = true;
      }
    });
  }

  void _clearSel() {
    setState(() {
      _selectionMode = false;
      _selectedMessages.clear();
    });
  }

  // ==================== FORWARD ====================
  void _showForwardDialog(List<MessageModel> msgs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final sel = <String>{};
        return StatefulBuilder(
          builder: (ctx, setS) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Forward ${msgs.length} message${msgs.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('${sel.length}/10',
                    style: const TextStyle(
                        color: Color(0xFF8F92A1), fontSize: 13)),
                const Divider(),
                SizedBox(
                  height: 350,
                  child: StreamBuilder<List<UserModel>>(
                    stream: _chatService.getMySpaceUsers(),
                    builder: (ctx, s) {
                      if (!s.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF2196F3)));
                      }
                      return ListView.builder(
                        itemCount: s.data!.length,
                        itemBuilder: (ctx, i) {
                          final u = s.data![i];
                          return CheckboxListTile(
                            value: sel.contains(u.uid),
                            onChanged: (v) {
                              if (v == true && sel.length < 10) {
                                setS(() => sel.add(u.uid));
                              } else if (v == false) {
                                setS(() => sel.remove(u.uid));
                              }
                            },
                            title: Text(u.name),
                            secondary: CircleAvatar(
                                child: Text(u.name[0].toUpperCase())),
                            activeColor: const Color(0xFF2196F3),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: sel.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            for (var m in msgs) {
                              await _chatService.forwardMessage(
                                  m, sel.toList());
                            }
                            _clearSel();
                            _snack('Forwarded to ${sel.length} chats');
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Forward',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== REACTION SHEET ====================
  void _showReactionSheet(MessageModel msg, bool isMe) {
    final emojis = ['❤️', '😂', '😮', '😢', '👍', '🙏'];
    final myR = msg.reactions.entries
        .where((e) => e.value.contains(_chatService.currentUserId))
        .map((e) => e.key)
        .firstOrNull;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(28)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((e) {
                    final s = myR == e;
                    return Flexible(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          if (s) {
                            await _chatService.removeReaction(
                                widget.chatId, msg.id);
                          } else {
                            await _chatService.addReaction(
                                widget.chatId, msg.id, e);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: s
                                ? const Color(0xFF2196F3).withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(e,
                              style: const TextStyle(fontSize: 26),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            _optItem(Icons.check_circle_outline, 'Select', () {
              Navigator.pop(ctx);
              _toggleSel(msg.id);
            }),
            if (msg.type == 'text')
              _optItem(Icons.copy_outlined, 'Copy', () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.text));
                _snack('Copied');
              }),
            _optItem(Icons.reply, 'Reply', () {
              Navigator.pop(ctx);
              setState(() => _replyTo = msg);
            }),
            if (msg.type == 'text' && _getTranslation(msg) == null)
              _optItem(Icons.translate, 'Translate', () {
                Navigator.pop(ctx);
                _showTranslateDialog(msg);
              }),
            if (_getTranslation(msg) != null)
              _optItem(Icons.translate, 'Show original', () {
                Navigator.pop(ctx);
                setState(() {
                  _translatedMessages.remove(msg.id);
                  _translatedLanguages.remove(msg.id);
                });
              }),
            _optItem(Icons.forward, 'Forward', () {
              Navigator.pop(ctx);
              _showForwardDialog([msg]);
            }),
            _optItem(
              msg.isStarredBy(_chatService.currentUserId)
                  ? Icons.star
                  : Icons.star_border,
              msg.isStarredBy(_chatService.currentUserId) ? 'Unstar' : 'Star',
              () {
                Navigator.pop(ctx);
                _chatService.toggleStar(widget.chatId, msg.id);
              },
              iconColor: Colors.amber,
            ),
            if (isMe)
              _optItem(Icons.delete_outline, 'Delete', () async {
                Navigator.pop(ctx);
                await _chatService.deleteMessage(widget.chatId, msg.id);
              }, iconColor: Colors.red, labelColor: Colors.red),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _optItem(IconData i, String l, VoidCallback onTap,
      {Color? iconColor, Color? labelColor}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(i, color: iconColor ?? const Color(0xFF1A1A2E), size: 22),
            const SizedBox(width: 18),
            Text(l,
                style: TextStyle(
                    color: labelColor ?? const Color(0xFF1A1A2E),
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: groupId)));
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F4FF),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF2196F3))),
      );
    }

    if (_chatLocked && !_unlocked) {
      return PinUnlockScreen(
        chatId: widget.chatId,
        chatName: widget.otherUserName,
        onUnlock: () => setState(() => _unlocked = true),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8EEFF),
      appBar: _selectionMode ? _selAppBar() : _buildNormalAppBar(false),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEAF1FF),
              Color(0xFFF5F8FF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _chatService.getMessages(widget.chatId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF2196F3)));
                  }
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return _emptyState();
                  }
                  final messages =
                      snap.data!.where((m) => !m.isExpired).toList();

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = messages[i];
                      final isMe =
                          msg.senderId == _chatService.currentUserId;
                      final sel = _selectedMessages.contains(msg.id);
                      return _SwipeReply(
                        key: ValueKey(msg.id),
                        isMe: isMe,
                        onReply: () {
                          if (_selectionMode) return;
                          setState(() => _replyTo = msg);
                        },
                        child: GestureDetector(
                          onLongPress: () {
                            if (_selectionMode) {
                              _toggleSel(msg.id);
                            } else {
                              _showReactionSheet(msg, isMe);
                            }
                          },
                          onTap: _selectionMode
                              ? () => _toggleSel(msg.id)
                              : null,
                          child: _bubble(msg, isMe, sel),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyTo != null && !_selectionMode) _replyPreview(),
            if (_recording && !_selectionMode)
              VoiceRecorderBar(
                onSend: _onVoiceSend,
                onCancel: () => setState(() => _recording = false),
              )
            else if (!_selectionMode)
              _ChatInputBar(
                key: const ValueKey('input_bar'),
                onSend: (text) {
                  _sendText(text);
                  if (_replyTo != null) {
                    setState(() => _replyTo = null);
                  }
                },
                onTranslate: (text) async {
                  return await _showTranslateBeforeSend(text);
                },
                onAttach: _showAttachSheet,
                onCamera: _pickCam,
              ),
          ],
        ),
      ),
    );
  }

  // ==================== INPUT BAR ====================
  Widget _replyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Replying to',
                    style: TextStyle(
                        color: Color(0xFF2196F3),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                Text(
                  _replyTo!.type == 'text' ? _replyTo!.text : 'Attachment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF8F92A1), fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _replyTo = null)),
        ],
      ),
    );
  }

  Future<String?> _showTranslateBeforeSend(String text) async {
    return await showDialog<String>(
      context: context,
      builder: (ctx) {
        String sel = 'en';
        bool loading = false;
        String? result;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Translate before send'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(text, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(10)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sel,
                      isExpanded: true,
                      items: TranslationService.languages.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setD(() => sel = v);
                      },
                    ),
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF2196F3), width: 1.5)),
                    child: Text(result!,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              if (result == null)
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setD(() => loading = true);
                          final t =
                              await _translationService.translate(text, sel);
                          setD(() {
                            result = t;
                            loading = false;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Translate'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, result),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==================== APP BARS ====================
  PreferredSizeWidget _selAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2196F3),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _clearSel,
      ),
      title: Text('${_selectedMessages.length}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20)),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy, color: Colors.white),
          onPressed: () {
            final txt = _selectedMessages.map((id) {
              final m = _allMsgs.firstWhere((m) => m.id == id,
                  orElse: () => MessageModel(
                      id: id, senderId: '', text: '', timestamp: DateTime.now()));
              return m.text;
            }).where((t) => t.isNotEmpty).join('\n');
            if (txt.isEmpty) {
              _snack('No text to copy');
              return;
            }
            Clipboard.setData(ClipboardData(text: txt));
            _snack('Copied');
            _clearSel();
          },
        ),
        IconButton(
          icon: const Icon(Icons.forward, color: Colors.white),
          onPressed: () {
            final msgs = _allMsgs
                .where((m) => _selectedMessages.contains(m.id))
                .toList();
            if (msgs.isNotEmpty) _showForwardDialog(msgs);
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: _deleteSelected,
        ),
      ],
    );
  }

  List<MessageModel> _allMsgs = [];

  PreferredSizeWidget _buildNormalAppBar(bool hasImage) {
    return AppBar(
      backgroundColor: const Color(0xFF5B4DFF),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: ClipOval(
                  child: hasImage
                      ? (widget.otherUserPhoto!.startsWith('data:image')
                          ? Image.memory(
                              _decodeBase64(widget.otherUserPhoto!),
                              fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: widget.otherUserPhoto!,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) =>
                                  _avFallback(widget.otherUserName),
                            ))
                      : isGroupChat
                          ? Container(
                              color: Colors.white.withOpacity(0.25),
                              child: const Icon(Icons.group,
                                  color: Colors.white, size: 20),
                            )
                          : _avFallback(widget.otherUserName),
                ),
              ),
              if (!isGroupChat)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(widget.otherUserName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified,
                        color: Color(0xFFB8D4FF), size: 15),
                  ],
                ),
                Text(
                  isGroupChat ? 'Tap for group info' : 'Online',
                  style: TextStyle(
                      color: const Color(0xFFB8D4FF).withOpacity(0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!isGroupChat) ...[
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white, size: 22),
              onPressed: () => _startCall('video'),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.call, color: Colors.white, size: 20),
              onPressed: () => _startCall('audio'),
            ),
          ),
          const SizedBox(width: 6),
        ],
        PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.more_vert, color: Colors.white, size: 20),
          ),
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          onSelected: (v) async {
            switch (v) {
              case 'view_contact': _showContactInfo(); break;
              case 'media': _showMediaInfo(); break;
              case 'search': _showSearchInChat(); break;
              case 'disappearing': _showDisappearingOptions(); break;
              case 'lock':
                if (_chatLocked) {
                  final r = await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PinSetupScreen(
                      chatId: widget.chatId,
                      chatName: widget.otherUserName,
                      isRemoving: true,
                    ),
                  ));
                  if (r == true && mounted) {
                    setState(() { _chatLocked = false; _unlocked = true; });
                  }
                } else {
                  final r = await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PinSetupScreen(
                      chatId: widget.chatId,
                      chatName: widget.otherUserName,
                    ),
                  ));
                  if (r == true && mounted) {
                    setState(() => _chatLocked = true);
                  }
                }
                break;
              case 'schedule':
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ScheduleMessageScreen(chatId: widget.chatId),
                ));
                break;
              case 'mute': _snackCall('Notifications muted'); break;
              case 'clear': _clearChat(); break;
              case 'block': _blockUser(); break;
              case 'report': _reportUser(); break;
              case 'group_info': _showGroupInfo(); break;
            }
          },
          itemBuilder: (ctx) => [
            _menuItem('view_contact', Icons.person_outline, 'View contact'),
            _menuItem('media', Icons.photo_library_outlined, 'Media, links, docs'),
            _menuItem('search', Icons.search, 'Search in chat'),
            _menuItem('disappearing', Icons.timer_outlined, 'Disappearing messages'),
            _menuItem('lock',
                _chatLocked ? Icons.lock_open : Icons.lock_outline,
                _chatLocked ? 'Remove lock' : 'Lock chat'),
            _menuItem('schedule', Icons.schedule, 'Schedule message'),
            _menuItem('mute', Icons.notifications_off_outlined, 'Mute notifications'),
            if (isGroupChat)
              _menuItem('group_info', Icons.info_outline, 'Group info'),
            _menuItem('clear', Icons.cleaning_services_outlined, 'Clear chat'),
            if (!isGroupChat)
              _menuItem('block', Icons.block, 'Block user', color: Colors.red),
            _menuItem('report', Icons.flag_outlined, 'Report', color: Colors.red),
          ],
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String v, IconData i, String l,
      {Color? color}) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(i, size: 20, color: color ?? const Color(0xFF1A1A2E)),
            const SizedBox(width: 14),
            Text(l,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: color ?? const Color(0xFF1A1A2E))),
          ],
        ),
      );

  void _showContactInfo() async {
    final u = await _chatService.getOtherUser(widget.chatId);
    if (u == null || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contact info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${u.name}'),
            const SizedBox(height: 6),
            Text('Username: @${u.username}'),
            if (u.email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Email: ${u.email}'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showMediaInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Media, links and docs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: List.generate(
                    6,
                    (i) => Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B4DFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.image_outlined,
                              color: Color(0xFF5B4DFF), size: 30),
                        )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchInChat() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Search in chat'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Type to search...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final q = ctrl.text.trim();
              Navigator.pop(ctx);
              if (q.isNotEmpty) _snackCall('Searching "$q"');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4DFF),
                foregroundColor: Colors.white),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    final c = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear chat?'),
        content: const Text('All messages will be removed for you only.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (c == true) _snackCall('Chat cleared');
  }

  Future<void> _blockUser() async {
    final u = await _chatService.getOtherUser(widget.chatId);
    if (u == null) return;
    final c = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Block ${u.name}?'),
        content: const Text('Blocked contacts cannot message you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (c == true) {
      await _chatService.blockUser(u.uid);
      if (mounted) _snackCall('User blocked');
    }
  }

  Future<void> _reportUser() async {
    final u = await _chatService.getOtherUser(widget.chatId);
    if (u == null) return;
    final c = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Report ${u.name}?'),
        content: const Text('Report this user for spam or abuse?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Report', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (c == true) {
      await _chatService.reportUser(u.uid, 'User reported');
      if (mounted) _snackCall('User reported. Thank you!');
    }
  }


  Widget _avFallback(String name) {
    return Container(
      color: Colors.white.withOpacity(0.25),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  // ==================== MESSAGE BUBBLE ====================
  Widget _bubble(MessageModel msg, bool isMe, bool isSel) {
    final star = msg.isStarredBy(_chatService.currentUserId);
    final trans = _getTranslation(msg);
    final transLang = _getTranslationLang(msg);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe && !_selectionMode) ...[
            _miniAvatar(msg),
            const SizedBox(width: 6),
          ],
          if (_selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                isSel ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSel
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF8F92A1),
                size: 22,
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.74),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4A90E2), Color(0xFF2196F3)])
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMe ? 20 : 4),
                  topRight: Radius.circular(isMe ? 4 : 20),
                  bottomLeft: const Radius.circular(20),
                  bottomRight: const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? const Color(0xFF2196F3).withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name (only for received)
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        widget.otherUserName,
                        style: const TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isMe)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'You',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3),
                      ),
                    ),
                  // Reply preview
                  if (msg.replyToId != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                            left: BorderSide(
                                color: isMe
                                    ? Colors.white
                                    : const Color(0xFF2196F3),
                                width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              msg.replyToSender == _chatService.currentUserId
                                  ? 'You'
                                  : widget.otherUserName,
                              style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF2196F3),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          Text(msg.replyToText ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isMe
                                      ? Colors.white70
                                      : const Color(0xFF8F92A1),
                                  fontSize: 12.5)),
                        ],
                      ),
                    ),
                  // Content
                  _content(msg, isMe),
                  // Translated text
                  if (trans != null && msg.type == 'text') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(
                                  color: isMe
                                      ? Colors.white.withOpacity(0.3)
                                      : const Color(0xFF2196F3)
                                          .withOpacity(0.3),
                                  width: 1))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.translate,
                                  size: 12,
                                  color: isMe
                                      ? Colors.white70
                                      : const Color(0xFF2196F3)),
                              const SizedBox(width: 4),
                              Text(transLang ?? 'Translated',
                                  style: TextStyle(
                                      color: isMe
                                          ? Colors.white70
                                          : const Color(0xFF2196F3),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(trans,
                              style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                  fontSize: 15,
                                  height: 1.35,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                  // Time + star + ticks
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (star)
                          const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.star,
                                  size: 12, color: Colors.amber)),
                        Text(
                          _fmtTime(msg.timestamp),
                          style: TextStyle(
                            color: isMe
                                ? Colors.white.withOpacity(0.85)
                                : const Color(0xFF8F92A1),
                            fontSize: 11,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            msg.seen ? Icons.done_all : Icons.done,
                            size: 15,
                            color: msg.seen
                                ? Colors.lightBlue[100]
                                : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe && !_selectionMode) ...[
            const SizedBox(width: 6),
            _miniAvatar(msg),
          ],
        ],
      ),
    );
  }

  Widget _miniAvatar(MessageModel msg) {
    return FutureBuilder<UserModel?>(
      future: _chatService.getUserById(msg.senderId),
      builder: (ctx, s) {
        if (!s.hasData || s.data == null) {
          return const SizedBox(width: 30, height: 30);
        }
        final u = s.data!;
        final has = u.photoUrl != null &&
            u.photoUrl!.isNotEmpty &&
            (u.photoUrl!.startsWith('data:image') ||
                u.photoUrl!.startsWith('http'));
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: has
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF2196F3)]),
          ),
          child: ClipOval(
            child: has
                ? (u.photoUrl!.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(u.photoUrl!.split(',').last),
                        fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: u.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (c, uu, e) => Center(
                            child: Text(
                                u.name.isNotEmpty
                                    ? u.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold))),
                      ))
                : Center(
                    child: Text(
                        u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold))),
          ),
        );
      },
    );
  }

  Widget _content(MessageModel msg, bool isMe) {
    switch (msg.type) {
      case 'image':
        if (msg.imageUrl == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showFullScreenImage(context, msg.imageUrl!,
              senderName: isMe ? 'You' : widget.otherUserName),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: msg.imageUrl!,
              width: 220,
              fit: BoxFit.cover,
              errorWidget: (c, u, e) => const SizedBox(
                  width: 220, height: 100, child: Icon(Icons.broken_image)),
            ),
          ),
        );
      case 'video':
        if (msg.videoUrl == null) return const SizedBox.shrink();
        return VideoThumbnail(
          url: msg.videoUrl!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenVideoPlayer(
                  url: msg.videoUrl!,
                  senderName: isMe ? 'You' : widget.otherUserName),
            ),
          ),
        );
      case 'voice':
        if (msg.voiceUrl == null) return const SizedBox.shrink();
        return VoiceMessageBubble(
            voiceUrl: msg.voiceUrl!,
            duration: msg.voiceDuration ?? 0,
            isMe: isMe,
            transcribedText: msg.transcribedText);
      case 'location':
        if (msg.latitude == null || msg.longitude == null) {
          return const SizedBox.shrink();
        }
        return LocationMessageBubble(
            latitude: msg.latitude!,
            longitude: msg.longitude!,
            address: msg.locationAddress,
            isLive: msg.isLiveLocation,
            liveExpiresAt: msg.liveLocationExpiresAt,
            isMe: isMe);
      case 'file':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file,
                color: isMe ? Colors.white : const Color(0xFF2196F3),
                size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(msg.fileName ?? 'File',
                  style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        );
      default:
        return Text(
          msg.text,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 15,
            height: 1.35,
          ),
        );
    }
  }

  // ==================== ATTACH ====================
  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _att(Icons.photo_library, 'Gallery', const Color(0xFF9C27B0), () {
              Navigator.pop(ctx);
              _pickImg(false);
            }),
            _att(Icons.camera_alt, 'Camera', const Color(0xFFE91E63), () {
              Navigator.pop(ctx);
              _pickImg(true);
            }),
            _att(Icons.insert_drive_file, 'Document', const Color(0xFF2196F3),
                () {
              Navigator.pop(ctx);
              _pickDoc();
            }),
            _att(Icons.videocam, 'Video', const Color(0xFFFF5722), () {
              Navigator.pop(ctx);
              _pickVid();
            }),
            _att(Icons.location_on, 'Location', const Color(0xFF4CAF50), () {
              Navigator.pop(ctx);
              _sendLocation();
            }),
            _att(Icons.my_location, 'Live', const Color(0xFF00BCD4), () {
              Navigator.pop(ctx);
              _sendLocation(isLive: true);
            }),
          ],
        ),
      ),
    );
  }

  Widget _att(IconData i, String l, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: c.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(i, color: c, size: 26),
          ),
          const SizedBox(height: 8),
          Text(l,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _pickImg(bool cam) async {
    final p = await ImagePicker().pickImage(
        source: cam ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 75);
    if (p == null) return;
    _uploadSend(p.path, 'image');
  }

  Future<void> _pickVid() async {
    final p = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (p == null) return;
    _uploadSend(p.path, 'video');
  }

  Future<void> _pickDoc() async {
    final r = await FilePicker.pickFiles(type: FileType.any);
    if (r == null || r.isEmpty) return;
    if (r.first.path == null) return;
    _uploadSend(r.first.path!, 'file');
  }

  Future<void> _pickCam() async {
    await _pickImg(true);
  }

  Future<void> _uploadSend(String path, String type) async {
    _loader('Uploading...');
    final f = File(path);
    String? url;
    if (type == 'image') {
      url = await _cloudinary.uploadImage(f);
    } else if (type == 'video') {
      url = await _cloudinary.uploadVideo(f);
    } else {
      url = await _cloudinary.uploadFile(f, path.split('/').last);
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
      _snack('Upload failed');
    }
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 60, color: const Color(0xFF8F92A1).withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No messages yet.\nSay hi!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8F92A1), fontSize: 14)),
        ],
      ),
    );
  }

  Uint8List _decodeBase64(String d) => base64Decode(d.split(',').last);

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showDisappearingOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StreamBuilder<int?>(
        stream: _chatService.getDisappearingHours(widget.chatId),
        builder: (ctx, snap) {
          final cur = snap.data;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text('Disappearing messages',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _dOpt('Off', null, cur),
                _dOpt('24 hours', 24, cur),
                _dOpt('7 days', 168, cur),
                _dOpt('90 days', 2160, cur),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dOpt(String label, int? hours, int? cur) {
    final sel = hours == cur;
    return ListTile(
      leading: Icon(
        sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: sel ? const Color(0xFF5B4DFF) : const Color(0xFF8F92A1),
      ),
      title: Text(label),
      onTap: () async {
        await _chatService.setDisappearingMessages(widget.chatId, hours);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _snackCall(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
  }
}

// ==================== INPUT BAR WIDGET ====================
class _ChatInputBar extends StatefulWidget {
  final void Function(String) onSend;
  final Future<String?> Function(String) onTranslate;
  final VoidCallback onAttach;
  final VoidCallback onCamera;

  const _ChatInputBar({
    super.key,
    required this.onSend,
    required this.onTranslate,
    required this.onAttach,
    required this.onCamera,
  });

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _hasText = false;
    setState(() => _showEmoji = false);
    widget.onSend(text);
  }

  Future<void> _translateSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final result = await widget.onTranslate(text);
    if (result != null && result.isNotEmpty) {
      _controller.clear();
      _hasText = false;
      setState(() => _showEmoji = false);
      widget.onSend(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showEmoji)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              onEmojiSelected: (cat, e) {
                _controller.text += e.emoji;
                _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: _controller.text.length));
              },
              config: const Config(
                  height: 280, checkPlatformCompatibility: true),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4FB),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            _showEmoji
                                ? Icons.keyboard
                                : Icons.emoji_emotions_outlined,
                            color: const Color(0xFF8F92A1),
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() => _showEmoji = !_showEmoji);
                            if (!_showEmoji) _focus.requestFocus();
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            textCapitalization:
                                TextCapitalization.sentences,
                            maxLines: null,
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                  color: Color(0xFF8F92A1), fontSize: 15),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 14),
                            ),
                            onTap: () {
                              if (_showEmoji) {
                                setState(() => _showEmoji = false);
                              }
                            },
                          ),
                        ),
                        if (_hasText)
                          IconButton(
                            icon: const Icon(Icons.translate,
                                color: Color(0xFF2196F3), size: 22),
                            onPressed: _translateSend,
                          ),
                        IconButton(
                          icon: const Icon(Icons.attach_file,
                              color: Color(0xFF8F92A1), size: 24),
                          onPressed: widget.onAttach,
                        ),
                        if (!_hasText)
                          IconButton(
                            icon: const Icon(Icons.camera_alt,
                                color: Color(0xFF8F92A1), size: 24),
                            onPressed: widget.onCamera,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF2196F3)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(_hasText ? Icons.send : Icons.mic,
                        color: Colors.white, size: 22),
                    onPressed: _hasText ? _send : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== SWIPE TO REPLY ====================
class _SwipeReply extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback onReply;

  const _SwipeReply({
    super.key,
    required this.child,
    required this.isMe,
    required this.onReply,
  });

  @override
  State<_SwipeReply> createState() => _SwipeReplyState();
}

class _SwipeReplyState extends State<_SwipeReply> {
  double _offset = 0;
  final double _max = 80;

  void _upd(DragUpdateDetails d) {
    setState(() {
      _offset += d.delta.dx;
      if (_offset < 0) _offset = 0;
      if (_offset > _max) _offset = _max;
    });
  }

  void _end(DragEndDetails d) {
    if (_offset >= _max * 0.7) {
      widget.onReply();
      HapticFeedback.mediumImpact();
    }
    setState(() => _offset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = (_offset / _max).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _upd,
      onHorizontalDragEnd: _end,
      child: Stack(
        children: [
          Positioned(
            left: widget.isMe ? null : 12 + (_offset * 0.3),
            right: widget.isMe ? 12 + (_offset * 0.3) : null,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: p,
                child: Transform.scale(
                  scale: 0.5 + (p * 0.5),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Color(0xFF2196F3), shape: BoxShape.circle),
                    child: const Icon(Icons.reply,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(widget.isMe ? -_offset : _offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }

  
}
