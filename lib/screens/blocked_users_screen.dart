import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../theme.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ChatService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<List<String>>(
        stream: service.getBlockedUids(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2196F3)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                    child: const Icon(Icons.block,
                        size: 60, color: Color(0xFF2196F3)),
                  ),
                  const SizedBox(height: 20),
                  const Text('No blocked users',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      )),
                  const SizedBox(height: 8),
                  const Text('You can block users anytime',
                      style:
                          TextStyle(color: Color(0xFF8F92A1), fontSize: 14)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, i) {
              final uid = snapshot.data![i];
              return FutureBuilder<UserModel?>(
                future: service.getUserById(uid),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || userSnap.data == null) {
                    return const SizedBox.shrink();
                  }
                  final u = userSnap.data!;
                  final hasPhoto = u.photoUrl != null &&
                      u.photoUrl!.startsWith('data:image');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF2196F3).withOpacity(0.15),
                        backgroundImage: hasPhoto
                            ? MemoryImage(_decode(u.photoUrl!))
                            : null,
                        child: !hasPhoto
                            ? Text(
                                u.name.isNotEmpty
                                    ? u.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Color(0xFF2196F3),
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(u.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text('@${u.username}',
                          style: const TextStyle(
                              color: Color(0xFF8F92A1), fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => service.unblockUser(uid),
                        child: const Text('Unblock',
                            style: TextStyle(
                              color: Color(0xFF2196F3),
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Uint8List _decode(String dataUrl) {
    return base64Decode(dataUrl.split(',').last);
  }
}
