import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../theme.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _service = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Privacy & Safety'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<UserModel?>(
        stream: _service.getCurrentUser(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2196F3)));
          }
          final user = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('Who can message me?'),
              _radioTile(
                'Everyone',
                'Anyone can send you a message',
                'everyone',
                user.whoCanMessage,
              ),
              _radioTile(
                'Contacts only',
                'Only your contacts can message you',
                'contacts',
                user.whoCanMessage,
              ),
              _radioTile(
                'Nobody',
                'Only you can start conversations',
                'nobody',
                user.whoCanMessage,
              ),
              const SizedBox(height: 20),
              _sectionTitle('Who can see my profile?'),
              _radioTile(
                'Everyone',
                'Anyone on Chatly',
                'everyone',
                user.whoCanSeeProfile,
                isProfile: true,
              ),
              _radioTile(
                'Contacts only',
                'Only your contacts',
                'contacts',
                user.whoCanSeeProfile,
                isProfile: true,
              ),
              const SizedBox(height: 20),
              _sectionTitle('Other'),
              _switchTile(
                'Read receipts',
                'Let others know when you\'ve read their messages',
                user.readReceipts,
                (v) => _service.updatePrivacySettings(readReceipts: v),
              ),
              _switchTile(
                'Show last seen',
                'Let contacts see when you were last online',
                user.lastSeenVisible,
                (v) => _service.updatePrivacySettings(lastSeenVisible: v),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2196F3),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _radioTile(String title, String subtitle, String value,
      String current, {bool isProfile = false}) {
    final selected = value == current;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? const Color(0xFF2196F3)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: () {
          if (isProfile) {
            _service.updatePrivacySettings(whoCanSeeProfile: value);
          } else {
            _service.updatePrivacySettings(whoCanMessage: value);
          }
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        leading: Icon(
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selected
              ? const Color(0xFF2196F3)
              : const Color(0xFF8F92A1),
        ),
        title: Text(title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            )),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: Color(0xFF8F92A1), fontSize: 12)),
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value,
      Function(bool) onChange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        value: value,
        activeColor: const Color(0xFF2196F3),
        onChanged: onChange,
        title: Text(title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            )),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: Color(0xFF8F92A1), fontSize: 12)),
      ),
    );
  }
}
