import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../widgets/full_screen_image.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  final _service = ChatService();
  List<UserModel> _searchResults = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _service.searchUsersByUsername(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  Future<void> _openChat(UserModel user) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2196F3)),
        ),
      );

      final chatId = await _service.createOrGetChatRoom(user.uid);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (chatId.isNotEmpty) {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open chat'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSendRequestDialog(UserModel user) {
    final controller = TextEditingController(
        text: 'Hi ${user.name}, I\'d like to connect with you on Chatly.');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add ${user.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user.username}',
                style: const TextStyle(
                    color: Color(0xFF8F92A1), fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add a message...',
                filled: true,
                fillColor: const Color(0xFFF8FAFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.sendContactRequest(
                  user.uid, controller.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request sent!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('New Chat'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF2196F3).withOpacity(0.15),
                    width: 1.5),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search username...',
                  hintStyle: const TextStyle(
                      color: Color(0xFF8F92A1), fontSize: 15),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFF2196F3), size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: Color(0xFF8F92A1)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),

          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildPersonalSpace(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF2196F3)));
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No users found',
            style: TextStyle(color: Color(0xFF8F92A1), fontSize: 14)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) =>
          _userTile(_searchResults[i], showAddButton: true),
    );
  }

  Widget _buildPersonalSpace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            'YOUR SPACE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2196F3),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _service.getMySpaceUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2196F3)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _emptySpace();
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, i) =>
                    _userTile(snapshot.data![i], showAddButton: false),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptySpace() {
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
            child: const Icon(Icons.person_search,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Search users by username and send them a request to connect',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8F92A1), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userTile(UserModel user, {required bool showAddButton}) {
    final hasPhoto = _hasImage(user.photoUrl);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        leading: GestureDetector(
          onTap: () => showProfilePicture(
            context,
            name: user.name,
            photoUrl: user.photoUrl,
            subtitle: '@${user.username}',
          ),
          child: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    const Color(0xFF2196F3).withOpacity(0.15),
                child: ClipOval(
                  child: hasPhoto
                      ? _buildImage(user.photoUrl!, 48)
                      : Center(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF2196F3),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                ),
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
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(user.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF1A1A2E))),
        subtitle: Text('@${user.username}',
            style: const TextStyle(
                color: Color(0xFF8F92A1), fontSize: 13)),
        trailing: showAddButton
            ? IconButton(
                icon: const Icon(Icons.person_add,
                    color: Color(0xFF2196F3)),
                onPressed: () => _showSendRequestDialog(user),
              )
            : IconButton(
                icon: const Icon(Icons.chat_bubble_outline,
                    color: Color(0xFF2196F3)),
                onPressed: () => _openChat(user),
              ),
      ),
    );
  }

  bool _hasImage(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('data:image') || url.startsWith('http');
  }

  Widget _buildImage(String url, double size) {
    if (url.startsWith('data:image')) {
      return Image.memory(
        _decode(url),
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
        child: const Icon(Icons.person, color: Color(0xFF2196F3), size: 20),
      ),
      errorWidget: (c, u, e) => Container(
        color: const Color(0xFF2196F3).withOpacity(0.1),
        child: const Icon(Icons.person, color: Color(0xFF2196F3), size: 20),
      ),
    );
  }

  Uint8List _decode(String dataUrl) {
    return base64Decode(dataUrl.split(',').last);
  }
}
