import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ContactSyncScreen extends StatefulWidget {
  const ContactSyncScreen({super.key});

  @override
  State<ContactSyncScreen> createState() => _ContactSyncScreenState();
}

class _ContactSyncScreenState extends State<ContactSyncScreen> {
  final _service = ChatService();
  bool _loading = false;
  List<Map<String, dynamic>> _matched = [];
  bool _scanned = false;

  Future<void> _scan() async {
    setState(() => _loading = true);
    final results = await _service.findMatchingContacts();
    if (mounted) {
      setState(() {
        _matched = results;
        _loading = false;
        _scanned = true;
      });
    }
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    final chatId = await _service.createOrGetChatRoom(user['uid']);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserName: user['name'],
            otherUserPhoto: user['photoUrl'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      appBar: AppBar(
        title: const Text('Find Friends'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: !_scanned
          ? _intro()
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF5B4DFF)))
              : _results(),
    );
  }

  Widget _intro() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F0FF), Color(0xFFEDE5FF)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.contacts_outlined,
                size: 70, color: Color(0xFF5B4DFF)),
          ),
          const SizedBox(height: 30),
          const Text(
            'Find friends on Chatly',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B1F3A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'We\'ll check your phone contacts (email addresses only) and show you friends who are already on Chatly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8F92A1),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: Color(0xFF5B4DFF), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your contacts stay on your phone. We only match emails locally.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF5A6B8A)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B4DFF), Color(0xFF7C4DFF)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5B4DFF).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _scan,
                borderRadius: BorderRadius.circular(28),
                child: const Center(
                  child: Text(
                    'Scan Contacts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results() {
    if (_matched.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B4DFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search,
                    size: 60, color: Color(0xFF5B4DFF)),
              ),
              const SizedBox(height: 24),
              const Text(
                'No friends found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1F3A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'None of your contacts are on Chatly yet. Invite them to join!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF8F92A1)),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _scan,
                child: const Text('Scan again',
                    style: TextStyle(
                      color: Color(0xFF5B4DFF),
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                '${_matched.length} friend${_matched.length > 1 ? 's' : ''} found',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1F3A),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _scan,
                child: const Text('Rescan'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _matched.length,
            itemBuilder: (ctx, i) {
              final u = _matched[i];
              final hasPhoto = u['photoUrl'] != null &&
                  u['photoUrl'].toString().isNotEmpty &&
                  (u['photoUrl'].toString().startsWith('data:image') ||
                      u['photoUrl'].toString().startsWith('http'));
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        const Color(0xFF5B4DFF).withOpacity(0.15),
                    backgroundImage: hasPhoto
                        ? (u['photoUrl'].toString().startsWith('data:image')
                            ? MemoryImage(_b64(u['photoUrl']))
                            : CachedNetworkImageProvider(u['photoUrl'].toString()) as ImageProvider)
                        : null,
                    child: !hasPhoto
                        ? Text(
                            u['name'].toString().isNotEmpty
                                ? u['name'].toString()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF5B4DFF),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    u['name'].toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                  subtitle: Text(
                    u['username'].toString().isNotEmpty
                        ? '@${u['username']}'
                        : u['email'].toString(),
                    style: const TextStyle(
                      color: Color(0xFF8F92A1),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B4DFF), Color(0xFF7C4DFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  onTap: () => _openChat(u),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Uint8List _b64(String d) => base64Decode(d.split(',').last);
}
