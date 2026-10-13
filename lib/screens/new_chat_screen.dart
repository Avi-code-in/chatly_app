import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../theme.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<UserModel> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final service = ChatService();
    final contacts = await service.getContactsOnly();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ChatService();
    final filtered = _contacts.where((u) {
      return u.name.toLowerCase().contains(_query) ||
          u.phone.contains(_query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('New Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: AppColors.textSecondary
                                  .withOpacity(0.5),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No contacts found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'App users with your contacts will appear here',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            leading: _avatar(user, 26),
                            title: Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              user.isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: user.isOnline
                                    ? Colors.green
                                    : AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            onTap: () async {
                              final chatId = await service
                                  .createOrGetChatRoom(user.uid);
                              if (context.mounted) {
                                Navigator.pushReplacement(
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
                          );
                        },
                      ),
          ),
        ],
      ),
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
}
