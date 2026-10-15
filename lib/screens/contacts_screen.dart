import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../theme.dart';
import 'chat_screen.dart';
import '../widgets/full_screen_image.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ChatService();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'My Space',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: service.getMySpaceUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2196F3)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _empty();
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, i) {
                    final user = snapshot.data![i];
                    final hasPhoto = user.photoUrl != null &&
                        user.photoUrl!.startsWith('data:image');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        leading: GestureDetector(
                          onTap: () => showProfilePicture(
                            context,
                            name: user.name,
                            photoUrl: user.photoUrl,
                            subtitle: user.isOnline ? 'Online' : 'Offline',
                          ),
                          child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  const Color(0xFF2196F3).withOpacity(0.15),
                              backgroundImage: hasPhoto
                                  ? MemoryImage(_decode(user.photoUrl!))
                                  : null,
                              child: !hasPhoto
                                  ? Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Color(0xFF2196F3),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            if (user.isOnline)
                              Positioned(
                                bottom: 1,
                                right: 1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ),
                        title: Text(user.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        subtitle: Text(
                          user.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: user.isOnline
                                ? const Color(0xFF00C853)
                                : const Color(0xFF8F92A1),
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: Color(0xFF8F92A1)),
                        onTap: () async {
                          final chatId =
                              await service.createOrGetChatRoom(user.uid);
                          if (context.mounted) {
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
                          }
                        },
                      ),
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

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline,
                size: 60, color: Color(0xFF2196F3)),
          ),
          const SizedBox(height: 20),
          const Text('Your space is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              )),
          const SizedBox(height: 8),
          const Text('Add contacts to start chatting',
              style: TextStyle(color: Color(0xFF8F92A1), fontSize: 14)),
        ],
      ),
    );
  }

  Uint8List _decode(String dataUrl) {
    return base64Decode(dataUrl.split(',').last);
  }
}
