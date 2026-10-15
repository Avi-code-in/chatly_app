import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../theme.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _service = ChatService();
  final Set<String> _selected = {};
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter group name')),
      );
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member')),
      );
      return;
    }
    setState(() => _loading = true);
    final chatId = await _service.createGroup(
      _nameController.text.trim(),
      _selected.toList(),
    );
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserName: _nameController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('New Group'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _createGroup,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Color(0xFF2196F3), strokeWidth: 2.5),
                  )
                : const Text('Create',
                    style: TextStyle(
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    )),
          ),
        ],
      ),
      body: Column(
        children: [
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
                controller: _nameController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(
                      color: Color(0xFF8F92A1), fontSize: 15),
                  prefixIcon: Icon(Icons.group,
                      color: Color(0xFF2196F3), size: 22),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selected.length} members selected',
                style: const TextStyle(
                    color: Color(0xFF8F92A1), fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No contacts in your space yet.\nAdd contacts first to create groups.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF8F92A1), fontSize: 14),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, i) {
                    final user = snapshot.data![i];
                    final selected = _selected.contains(user.uid);
                    final hasPhoto = user.photoUrl != null &&
                        user.photoUrl!.startsWith('data:image');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CheckboxListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        activeColor: const Color(0xFF2196F3),
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(user.uid);
                          } else {
                            _selected.remove(user.uid);
                          }
                        }),
                        title: Text(user.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text('@${user.username}',
                            style: const TextStyle(
                                color: Color(0xFF8F92A1), fontSize: 12)),
                        secondary: CircleAvatar(
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
                                  ),
                                )
                              : null,
                        ),
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

  Uint8List _decode(String dataUrl) {
    return base64Decode(dataUrl.split(',').last);
  }
}
