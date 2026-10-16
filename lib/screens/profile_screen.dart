import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../models/user_model.dart';
import 'auth_screen.dart';
import 'contact_sync_screen.dart';
import 'backup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = ChatService();
  final _cloudinary = CloudinaryService();
  bool _uploading = false;

  
  void _showLiveTypingDialog() {
    final service = ChatService();
    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<bool>(
        stream: service.getLiveTypingSetting(),
        builder: (ctx, snap) {
          final enabled = snap.data ?? true;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.visibility_outlined, color: Color(0xFF5B4DFF)),
                SizedBox(width: 10),
                Text('Live Typing Preview'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'When ON, others can see what you\'re typing in real-time.',
                  style: TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable for everyone',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  value: enabled,
                  activeColor: const Color(0xFF5B4DFF),
                  onChanged: (v) async {
                    await service.updateLiveTypingSetting(v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 75,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    _showLoader();
    final url = await _cloudinary.uploadImage(File(picked.path));
    if (mounted) Navigator.pop(context);
    if (url != null) {
      await _service.updateProfilePicture(url);
      if (mounted) _snack('Profile photo updated!', Colors.green);
    } else {
      if (mounted) _snack('Upload failed', Colors.red);
    }
    if (mounted) setState(() => _uploading = false);
  }

  void _showLoader() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF5B4DFF)),
                  SizedBox(height: 16),
                  Text('Uploading...'),
                ],
              ),
            ),
          ),
        ),
      );

  void _snack(String m, Color c) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  void _showAboutDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About'),
        content: const Text('Hey there! I am using Chatly 💬'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAccountDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Name', user.name),
            _row('Email', user.email.isEmpty ? '—' : user.email),
            _row('Phone', user.phone.isEmpty ? '—' : user.phone),
            _row('Username', user.username.isEmpty ? '—' : '@${user.username}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(k,
                  style: const TextStyle(
                      color: Color(0xFF8F92A1), fontSize: 12.5)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E))),
            ),
          ],
        ),
      );

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Notifications'),
        content: StatefulBuilder(
          builder: (ctx, setSt) {
            bool messages = true, groups = true, calls = true;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Messages'),
                  value: messages,
                  activeColor: const Color(0xFF5B4DFF),
                  onChanged: (v) => setSt(() => messages = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Groups'),
                  value: groups,
                  activeColor: const Color(0xFF5B4DFF),
                  onChanged: (v) => setSt(() => groups = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Calls'),
                  value: calls,
                  activeColor: const Color(0xFF5B4DFF),
                  onChanged: (v) => setSt(() => calls = v),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFF7C4DFF)),
            SizedBox(width: 10),
            Text('Chatly Premium'),
          ],
        ),
        content: const Text(
            'More features. Better experience.\n\nComing soon with exclusive themes, unlimited media sharing, and more!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Support'),
        content: const Text('Need help?\n\nEmail: support@chatly.app'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final c = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (c == true) {
      await _service.signOut();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (r) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<UserModel?>(
        stream: _service.getCurrentUser(),
        builder: (ctx, snap) {
          if (!snap.hasData || snap.data == null) {
            return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF5B4DFF)));
          }
          return _body(snap.data!);
        },
      ),
    );
  }

  Widget _body(UserModel user) {
    final hasImg = user.photoUrl != null &&
        user.photoUrl!.isNotEmpty &&
        (user.photoUrl!.startsWith('data:image') ||
            user.photoUrl!.startsWith('http'));

    return Stack(
      children: [
        // Background orbs
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFFD5DDFF).withOpacity(0.6),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================== HEADER ====================
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Profile',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B1F3A),
                              letterSpacing: -0.5,
                            )),
                        const SizedBox(height: 2),
                        Text('Your personal space',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black.withOpacity(0.5),
                            )),
                        const SizedBox(height: 6),
                        Container(
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFF5B4DFF),
                              Color(0xFF7C4DFF)
                            ]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Color(0xFF0B1F3A), size: 22),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================== AVATAR + INFO ====================
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B4DFF), Color(0xFF7C4DFF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5B4DFF).withOpacity(0.35),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: hasImg
                              ? (user.photoUrl!.startsWith('data:image')
                                  ? Image.memory(
                                      _b64(user.photoUrl!),
                                      fit: BoxFit.cover)
                                  : CachedNetworkImage(
                                      imageUrl: user.photoUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (c, u, e) =>
                                          _fallback(user.name)))
                              : _fallback(user.name),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _pickProfilePhoto,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5B4DFF), Color(0xFF7C4DFF)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: _uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Name + verified icon
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B1F3A),
                        )),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit,
                        size: 16, color: Color(0xFF5B4DFF)),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              Center(
                child: Text(user.email.isEmpty ? '@${user.username}' : user.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withOpacity(0.55),
                    )),
              ),

              const SizedBox(height: 14),

              // Online pill
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Online',
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ==================== MENU CARDS ====================
              _menuCard(
                icon: Icons.info_outline,
                iconColor: const Color(0xFF4A90E2),
                iconBg: const Color(0xFFE8F0FF),
                title: 'About',
                subtitle: 'Hey there! I am using Chatly',
                onTap: () => _showAboutDialog(user),
              ),
              _menuCard(
                icon: Icons.person_outline,
                iconColor: const Color(0xFF7C4DFF),
                iconBg: const Color(0xFFEDE5FF),
                title: 'Account',
                subtitle: 'Name, email, phone, user ID',
                onTap: () => _showAccountDialog(user),
              ),
              _menuCard(
                icon: Icons.notifications_none_rounded,
                iconColor: const Color(0xFF7C4DFF),
                iconBg: const Color(0xFFEDE5FF),
                title: 'Notifications',
                subtitle: 'Messages, groups, calls',
                onTap: _showNotificationsDialog,
              ),
              _menuCard(
                icon: Icons.visibility_outlined,
                iconColor: const Color(0xFF7C4DFF),
                iconBg: const Color(0xFFEDE5FF),
                title: 'Live Typing Preview',
                subtitle: 'Show what you\'re typing to others',
                onTap: () => _showLiveTypingDialog(),
              ),
              _menuCard(
                icon: Icons.person_add_alt_1,
                iconColor: const Color(0xFF22C55E),
                iconBg: const Color(0xFFDCFCE7),
                title: 'Find Friends',
                subtitle: 'Sync contacts to find friends on Chatly',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ContactSyncScreen())),
              ),
              _menuCard(
                icon: Icons.cloud_sync_outlined,
                iconColor: const Color(0xFF7C4DFF),
                iconBg: const Color(0xFFEDE5FF),
                title: 'Backup & Restore',
                subtitle: 'Backup your chats to cloud',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BackupScreen())),
              ),
              _menuCard(
                icon: Icons.help_outline,
                iconColor: const Color(0xFF4A90E2),
                iconBg: const Color(0xFFE8F0FF),
                title: 'Help & Support',
                subtitle: 'FAQ, contact us',
                onTap: _showHelpDialog,
              ),

              const SizedBox(height: 16),

              // ==================== PREMIUM CARD ====================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _showPremiumDialog,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEDE5FF), Color(0xFFD5DDFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5B4DFF).withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5B4DFF), Color(0xFF7C4DFF)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.workspace_premium,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chatly Premium',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0B1F3A),
                                  )),
                              SizedBox(height: 2),
                              Text('More features. Better experience.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF5A6B8A),
                                  )),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 14, color: Color(0xFF5B4DFF)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Logout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _logout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.15), width: 1),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.red, size: 20),
                        SizedBox(width: 10),
                        Text('Log Out',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B1F3A),
                            )),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF8F92A1),
                            )),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 13, color: Color(0xFF8F92A1)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _fallback(String name) => Container(
        color: const Color(0xFF5B4DFF),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w700),
          ),
        ),
      );

  Uint8List _b64(String d) => base64Decode(d.split(',').last);
}
