import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../theme.dart';
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
      backgroundColor: const Color(0xFFF8FAFF),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.08),
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
            selectedItemColor: const Color(0xFF2196F3),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEEF1FF), Color(0xFFE0E6FF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu, color: Color(0xFF2196F3)),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Chatly',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    _modernIconButton(Icons.search, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NewChatScreen()),
                      );
                    }),
                    const SizedBox(width: 8),
                    _modernIconButton(Icons.group_add, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                      );
                    }),
                  ],
                ),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _filterChip('All', 0),
                    const SizedBox(width: 8),
                    _filterChip('Unread', 1),
                    const SizedBox(width: 8),
                    _filterChip('Groups', 2),
                    const SizedBox(width: 8),
                    _filterChip('Favorites', 3),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chats list
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatService.getChats(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF2196F3)),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _emptyState();
                    }

                    var chats = snapshot.data!
                        .where((chat) => (chat['lastMessage'] ?? '').toString().isNotEmpty)
                        .toList();

                    if (_filterIndex == 2) {
                      chats = chats.where((c) => c['isGroup'] == true).toList();
                    }

                    if (chats.isEmpty) return _emptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chatData = chats[index];
                        final chatId = chatData['chatId'] as String;
                        final isGroup = chatData['isGroup'] == true;
                        final groupName = chatData['groupName'] ?? 'Group';

                        if (isGroup) {
                          return _groupTile(context, chatId, chatData, groupName);
                        }

                        return FutureBuilder<UserModel?>(
                          future: _chatService.getOtherUser(chatId),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData || userSnapshot.data == null) {
                              return const SizedBox.shrink();
                            }
                            final user = userSnapshot.data!;
                            return _chatTile(context, chatId, chatData, user);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // ===== FRIEND REQUEST MINI FAB (Bottom-right, above edit FAB) =====
          // Only visible when there are pending requests
          Positioned(
            right: 16,
            bottom: 90,
            child: StreamBuilder<int>(
              stream: _chatService.getPendingRequestCount(),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ContactRequestsScreen()),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      // Red dot with count
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          constraints: const BoxConstraints(
                              minWidth: 20, minHeight: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ===== EDIT FAB (Main, always visible) =====
          Positioned(
            right: 16,
            bottom: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatScreen()),
                );
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.45),
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

  Widget _modernIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF1FF), Color(0xFFE0E6FF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF2196F3)),
        onPressed: onTap,
      ),
    );
  }

  Widget _filterChip(String label, int index) {
    final selected = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF8F92A1),
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEEF1FF), Color(0xFFE0E6FF)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new chat or create a group',
            style: TextStyle(fontSize: 14, color: Color(0xFF8F92A1)),
          ),
        ],
      ),
    );
  }

  Widget _groupTile(BuildContext context, String chatId,
      Map<String, dynamic> chatData, String groupName) {
    final groupPhoto = chatData['groupPhoto'] as String?;
    final hasPhoto = groupPhoto != null && groupPhoto.isNotEmpty;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserName: groupName,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: hasPhoto
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: hasPhoto
                    ? _buildNetworkImage(groupPhoto)
                    : const Icon(Icons.group, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chatData['lastMessage'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8F92A1),
                      fontSize: 14,
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

  Widget _chatTile(BuildContext context, String chatId,
      Map<String, dynamic> chatData, UserModel user) {
    final lastMessage = chatData['lastMessage'] ?? '';
    final lastSender = chatData['lastMessageSender'] ?? '';
    final isMe = lastSender == _chatService.currentUserId;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUserName: user.name,
              otherUserPhoto: user.photoUrl,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            _avatar(user, 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(chatData['lastMessageTime']),
                        style: const TextStyle(
                          color: Color(0xFF8F92A1),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isMe)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.done_all,
                              size: 16, color: Color(0xFF2196F3)),
                        ),
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8F92A1),
                            fontSize: 14,
                          ),
                        ),
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

  Widget _avatar(UserModel user, double radius) {
    final hasImage = _hasImage(user.photoUrl);
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasImage
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: hasImage
                  ? _buildAvatarImage(user.photoUrl!, radius * 2)
                  : Container(
                      width: radius * 2,
                      height: radius * 2,
                      color: const Color(0xFF2196F3).withOpacity(0.15),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: const Color(0xFF2196F3),
                            fontWeight: FontWeight.bold,
                            fontSize: radius * 0.7,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (user.isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool _hasImage(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('data:image') || url.startsWith('http');
  }

  Widget _buildAvatarImage(String url, double size) {
    if (url.startsWith('data:image')) {
      return Image.memory(
        _decodeBase64(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (c, u) => Container(
        color: const Color(0xFF2196F3).withOpacity(0.1),
      ),
      errorWidget: (c, u, e) => Container(
        color: const Color(0xFF2196F3).withOpacity(0.1),
        child: const Icon(Icons.person, color: Color(0xFF2196F3)),
      ),
    );
  }

  Widget _buildNetworkImage(String url) {
    if (url.startsWith('data:image')) {
      return Image.memory(_decodeBase64(url), fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (c, u) => const Icon(Icons.group,
          color: Colors.white, size: 28),
      errorWidget: (c, u, e) =>
          const Icon(Icons.group, color: Colors.white, size: 28),
    );
  }

  Uint8List _decodeBase64(String dataUrl) {
    return base64Decode(dataUrl.split(',').last);
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (_) {
      return '';
    }
  }
}
