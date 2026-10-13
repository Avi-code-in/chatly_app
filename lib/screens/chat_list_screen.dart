import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../theme.dart';
import 'new_chat_screen.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

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
      const ContactsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NewChatScreen()),
                );
              },
              child:
                  const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chats',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search,
                          color: AppColors.textPrimary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NewChatScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert,
                          color: AppColors.textPrimary),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatService.getChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyState();
                }

                // Filter: only chats with lastMessage
                final chats = snapshot.data!
                    .where((chat) =>
                        (chat['lastMessage'] ?? '').toString().isNotEmpty)
                    .toList();

                if (chats.isEmpty) return _emptyState();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chatData = chats[index];
                    final chatId = chatData['chatId'] as String;

                    return FutureBuilder<UserModel?>(
                      future: chatService.getOtherUser(chatId),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData ||
                            userSnapshot.data == null) {
                          return const SizedBox.shrink();
                        }
                        final user = userSnapshot.data!;
                        return _chatTile(
                            context, chatId, chatData, user, chatService);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Abhi koi chat nahi hai',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Neeche + dabao aur naya chat shuru karo',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatTile(BuildContext context, String chatId,
      Map<String, dynamic> chatData, UserModel user, ChatService service) {
    final lastMessage = chatData['lastMessage'] ?? '';
    final lastSender = chatData['lastMessageSender'] ?? '';
    final isMe = lastSender == service.currentUserId;
    final timeStr = _formatTime(chatData['lastMessageTime']);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: _avatar(user, 28),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (isMe)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.done_all,
                    size: 16, color: AppColors.primary),
              ),
            Expanded(
              child: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
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
    );
  }

  Widget _avatar(UserModel user, double radius) {
    final hasImage = user.photoUrl != null &&
        user.photoUrl!.startsWith('data:image');
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary.withOpacity(0.15),
          backgroundImage: hasImage
              ? MemoryImage(_decodeBase64(user.photoUrl!))
              : null,
          child: !hasImage
              ? Text(
                  user.name.isNotEmpty
                      ? user.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.7,
                  ),
                )
              : null,
        ),
        if (user.isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Uint8List _decodeBase64(String dataUrl) {
    final base64String = dataUrl.split(',').last;
    return base64Decode(base64String);
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays > 0) {
        return '${diff.inDays}d';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m';
      } else {
        return 'abhi';
      }
    } catch (_) {
      return '';
    }
  }
}
