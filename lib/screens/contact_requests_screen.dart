import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/contact_request_model.dart';
import '../theme.dart';
import 'chat_screen.dart';

class ContactRequestsScreen extends StatelessWidget {
  const ContactRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ChatService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Contact Requests'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.getIncomingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF2196F3)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _empty();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, i) {
              final req = ContactRequestModel.fromMap(
                snapshot.data![i],
                snapshot.data![i]['id'],
              );
              return _requestCard(context, req, service);
            },
          );
        },
      ),
    );
  }

  Widget _requestCard(BuildContext context, ContactRequestModel req,
      ChatService service) {
    final hasPhoto = req.fromPhoto != null &&
        req.fromPhoto!.isNotEmpty &&
        req.fromPhoto!.startsWith('data:image');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF2196F3).withOpacity(0.15),
                backgroundImage: hasPhoto
                    ? MemoryImage(_decode(req.fromPhoto!))
                    : null,
                child: !hasPhoto
                    ? Text(
                        req.fromName.isNotEmpty
                            ? req.fromName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.fromName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        )),
                    Text('@${req.fromUsername}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8F92A1),
                        )),
                  ],
                ),
              ),
            ],
          ),
          if (req.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('"${req.message}"',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A2E),
                    fontStyle: FontStyle.italic,
                  )),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => service.rejectContactRequest(req.id),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(
                          color: Color(0xFF8F92A1),
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await service.acceptContactRequest(req.id, req.fromUid);
                    if (context.mounted) {
                      final chatId =
                          await service.createOrGetChatRoom(req.fromUid);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatId,
                              otherUserName: req.fromName,
                              otherUserPhoto: req.fromPhoto,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Accept',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
            child: const Icon(Icons.person_add_outlined,
                size: 60, color: Color(0xFF2196F3)),
          ),
          const SizedBox(height: 20),
          const Text('No pending requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              )),
          const SizedBox(height: 8),
          const Text('Contact requests will appear here',
              style: TextStyle(color: Color(0xFF8F92A1), fontSize: 14)),
        ],
      ),
    );
  }

  Uint8List _decode(String dataUrl) {
    return base64Decode(dataUrl.split(',').last);
  }
}
