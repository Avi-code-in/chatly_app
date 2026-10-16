import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import 'new_chat_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'status_screen.dart';
import 'create_group_screen.dart';
import 'contact_requests_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _ChatsTab(),
      const StatusScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFF5B4DFF),
            unselectedItemColor: const Color(0xFF8F92A1),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_time),
                activeIcon: Icon(Icons.access_time_filled),
                label: 'Status',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatsTab extends StatefulWidget {
  const _ChatsTab();

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  int _filterIndex = 0;
  final _chatService = ChatService();
  Set<String> _favouriteUids = {};

  @override
  void initState() {
    super.initState();
    _chatService.getFavouriteUids().listen((f) {
      if (mounted) setState(() => _favouriteUids = f.toSet());
    });
    _startWorker();
  }

  void _startWorker() {
    _chatService.processAllScheduledMessages();
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) _startWorker();
    });
  }

  void _showUserOptions(UserModel u, bool isFav, bool isBlocked) {
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
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF5B4DFF).withOpacity(0.15),
                child: Text(
                  u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Color(0xFF5B4DFF), fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(u.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text('@${u.username}',
                  style: const TextStyle(color: Color(0xFF8F92A1))),
            ),
            const Divider(),
            ListTile(
              leading: Icon(isFav ? Icons.star : Icons.star_border,
                  color: Colors.amber),
              title:
                  Text(isFav ? 'Remove from Favourites' : 'Add to Favourites'),
              onTap: () async {
                await _chatService.toggleFavourite(u.uid);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(isBlocked ? Icons.lock_open : Icons.block,
                  color: isBlocked ? const Color(0xFF5B4DFF) : Colors.red),
              title: Text(isBlocked ? 'Unblock' : 'Block',
                  style: TextStyle(
                      color:
                          isBlocked ? const Color(0xFF5B4DFF) : Colors.red)),
              onTap: () async {
                if (isBlocked) {
                  await _chatService.unblockUser(u.uid);
                } else {
                  await _chatService.blockUser(u.uid);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(String chatId, UserModel u) async {
    if (await _chatService.isBlocked(u.uid)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${u.name} is blocked'),
          action: SnackBarAction(
              label: 'Unblock',
              onPressed: () => _chatService.unblockUser(u.uid)),
        ));
      }
      return;
    }
    final hasPin = await _chatService.hasChatPin(chatId);
    if (hasPin) {
      final stored = await _chatService.getChatPin(chatId);
      if (!mounted) return;
      final entered = await _askPin();
      if (entered != stored) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Wrong PIN'), backgroundColor: Colors.red));
        }
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserName: u.name,
          otherUserPhoto: u.photoUrl,
        ),
      ),
    );
  }

  Future<String?> _askPin() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter PIN'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
              counterText: '',
              hintText: '----',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4DFF),
                foregroundColor: Colors.white),
            child: const Text('Unlock'),
          ),
        ],
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
                  const Color(0xFFD5DDFF).withOpacity(0.7),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFE5D9FF).withOpacity(0.5),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    _squareBtn(Icons.menu, () {}),
                    const SizedBox(width: 12),
                    const Text('Chatly',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0B1F3A),
                          letterSpacing: -1,
                        )),
                    const Spacer(),
                    _squareBtn(Icons.search, () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NewChatScreen()));
                    }),
                    const SizedBox(width: 8),
                    _squareBtn(Icons.person_add_alt_1, () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NewChatScreen()));
                    }),
                  ],
                ),
              ),

              // FILTER CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _chip('All', 0),
                    const SizedBox(width: 8),
                    _chip('Unread', 1),
                    const SizedBox(width: 8),
                    _chip('Groups', 2),
                    const SizedBox(width: 8),
                    _chip('Favourites', 3),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // LIST
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatService.getChats(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF5B4DFF)));
                    }
                    if (!snap.hasData || snap.data!.isEmpty) {
                      return _empty();
                    }
                    var list = snap.data!
                        .where((c) =>
                            (c['lastMessage'] ?? '').toString().isNotEmpty)
                        .toList();
                    if (_filterIndex == 2) {
                      list = list
                          .where((c) => c['isGroup'] == true)
                          .toList();
                    }
                    if (list.isEmpty) return _empty();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final d = list[i];
                        final cid = d['chatId'] as String;
                        final isGroup = d['isGroup'] == true;
                        if (isGroup) {
                          return _groupTile(cid, d, d['groupName'] ?? 'Group');
                        }
                        return FutureBuilder<UserModel?>(
                          future: _chatService.getOtherUser(cid),
                          builder: (ctx, us) {
                            if (!us.hasData || us.data == null) {
                              return const SizedBox.shrink();
                            }
                            final u = us.data!;
                            final fav = _favouriteUids.contains(u.uid);
                            if (_filterIndex == 3 && !fav) {
                              return const SizedBox.shrink();
                            }
                            return _chatTile(cid, d, u, fav);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Request FAB
          Positioned(
            right: 16,
            bottom: 90,
            child: StreamBuilder<int>(
              stream: _chatService.getPendingRequestCount(),
              builder: (ctx, s) {
                final c = s.data ?? 0;
                if (c == 0) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ContactRequestsScreen())),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12),
                          ],
                        ),
                        child: const Icon(Icons.person_add,
                            color: Color(0xFF5B4DFF), size: 22),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(
                              minWidth: 20, minHeight: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B4DFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text('$c',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Edit FAB
          Positioned(
            right: 16,
            bottom: 20,
            child: GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NewChatScreen())),
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
                child: const Icon(Icons.edit, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _squareBtn(IconData i, VoidCallback t) => GestureDetector(
        onTap: t,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(i, color: const Color(0xFF0B1F3A), size: 22),
        ),
      );

  Widget _chip(String t, int i) {
    final s = _filterIndex == i;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: s
              ? const LinearGradient(colors: [
                  Color(0xFF5B4DFF),
                  Color(0xFF7C4DFF),
                ])
              : null,
          color: s ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: s
                    ? const Color(0xFF5B4DFF).withOpacity(0.3)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Text(t,
            style: TextStyle(
              color: s ? Colors.white : const Color(0xFF5A6B8A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFFEDE5FF),
                  Color(0xFFD5DDFF),
                ]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 55, color: Color(0xFF5B4DFF)),
            ),
            const SizedBox(height: 24),
            const Text('No chats yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1F3A),
                )),
            const SizedBox(height: 8),
            const Text('Start a new chat or create a group',
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF8F92A1))),
          ],
        ),
      );

  Widget _groupTile(String cid, Map<String, dynamic> d, String name) {
    final photo = d['groupPhoto'] as String?;
    final has = photo != null && photo.isNotEmpty;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ChatScreen(chatId: cid, otherUserName: name))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: has
                    ? null
                    : const LinearGradient(colors: [
                        Color(0xFF5B4DFF),
                        Color(0xFF7C4DFF),
                      ]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: has
                    ? (photo.startsWith('data:image')
                        ? Image.memory(_b64(photo), fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: photo,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => const Icon(Icons.group,
                                color: Colors.white, size: 24),
                          ))
                    : const Icon(Icons.group,
                        color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF0B1F3A),
                      )),
                  const SizedBox(height: 4),
                  Text(d['lastMessage'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8F92A1),
                        fontSize: 14,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatTile(String cid, Map<String, dynamic> d, UserModel u, bool fav) {
    final last = d['lastMessage'] ?? '';
    final sender = d['lastMessageSender'] ?? '';
    final isMe = sender == _chatService.currentUserId;
    final hasImg = u.photoUrl != null &&
        u.photoUrl!.isNotEmpty &&
        (u.photoUrl!.startsWith('data:image') ||
            u.photoUrl!.startsWith('http'));

    return GestureDetector(
      onTap: () => _openChat(cid, u),
      onLongPress: () async {
        final blocked = await _chatService.isBlocked(u.uid);
        if (!mounted) return;
        _showUserOptions(u, fav, blocked);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasImg
                        ? null
                        : const LinearGradient(colors: [
                            Color(0xFF5B4DFF),
                            Color(0xFF7C4DFF),
                          ]),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    backgroundImage: hasImg
                        ? (u.photoUrl!.startsWith('data:image')
                            ? MemoryImage(_b64(u.photoUrl!))
                            : CachedNetworkImageProvider(u.photoUrl!))
                        : null,
                    child: !hasImg
                        ? Text(
                            u.name.isNotEmpty
                                ? u.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ))
                        : null,
                  ),
                ),
                if (u.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(u.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Color(0xFF0B1F3A),
                                  )),
                            ),
                            if (fav) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.star,
                                  size: 14, color: Colors.amber),
                            ],
                          ],
                        ),
                      ),
                      Text(_fmtTime(d['lastMessageTime']),
                          style: const TextStyle(
                            color: Color(0xFF8F92A1),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isMe)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.done_all,
                              size: 16, color: Color(0xFF5B4DFF)),
                        ),
                      Expanded(
                        child: Text(last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8F92A1),
                              fontSize: 14,
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    try {
      final d = DateTime.parse(ts);
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (_) {
      return '';
    }
  }

  Uint8List _b64(String d) => base64Decode(d.split(',').last);
}
