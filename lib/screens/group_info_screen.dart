import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_service.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../theme.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _service = ChatService();
  final _cloudinary = CloudinaryService();

  Future<void> _pickGroupPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 70,
    );
    if (picked == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    final url = await _cloudinary.uploadImage(File(picked.path));
    if (mounted) Navigator.pop(context);

    if (url != null) {
      await _service.updateGroupPhoto(widget.groupId, url);
    }
  }

  void _showAddMembersDialog(GroupModel group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Add Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 350,
              child: StreamBuilder<List<UserModel>>(
                stream: _service.getUsers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  final users = snapshot.data!
                      .where((u) => !group.members.contains(u.uid))
                      .toList();
                  if (users.isEmpty) {
                    return const Center(child: Text('No new users to add'));
                  }
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.name[0].toUpperCase()),
                        ),
                        title: Text(user.name),
                        trailing: const Icon(
                          Icons.add_circle,
                          color: AppColors.primary,
                        ),
                        onTap: () async {
                          await _service.addMemberToGroup(widget.groupId, user.uid);
                          if (context.mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${user.name} added')),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberOptions(GroupModel group, UserModel user) {
    final isMe = user.uid == _service.currentUserId;
    final isUserAdmin = group.admins.contains(user.uid);
    final iAmAdmin = group.admins.contains(_service.currentUserId);
    final isSuperAdmin = group.createdBy == user.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                child: Text(user.name[0].toUpperCase()),
              ),
              title: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isSuperAdmin
                    ? 'Super Admin'
                    : isUserAdmin
                        ? 'Admin'
                        : 'Member',
              ),
            ),
            const Divider(),
            // Promote/Demote (Admin only, not super admin)
            if (iAmAdmin && !isMe && !isSuperAdmin)
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.green,
                ),
                title: Text(isUserAdmin ? 'Dismiss as Admin' : 'Make Group Admin'),
                onTap: () async {
                  Navigator.pop(context);
                  if (isUserAdmin) {
                    await _service.demoteFromAdmin(widget.groupId, user.uid);
                  } else {
                    await _service.promoteToAdmin(widget.groupId, user.uid);
                  }
                },
              ),
            // Remove member (Admin only, not self, not super admin)
            if (iAmAdmin && !isMe && !isSuperAdmin)
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text(
                  'Remove from Group',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remove member?'),
                      content: Text('Remove ${user.name} from group?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Remove',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _service.removeMemberFromGroup(widget.groupId, user.uid);
                  }
                },
              ),
            // Message (for any user)
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.message, color: AppColors.primary),
                title: const Text('Message'),
                onTap: () async {
                  Navigator.pop(context);
                  await _service.createOrGetChatRoom(user.uid);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Group Info'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<GroupModel?>(
        stream: _service.getGroups().map(
              (groups) => groups.firstWhere(
                (g) => g.id == widget.groupId,
                orElse: () => throw Exception('Group not found'),
              ),
            ),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final group = snapshot.data!;
          final iAmAdmin = group.admins.contains(_service.currentUserId);
          final isSuperAdmin = group.createdBy == _service.currentUserId;
          final hasPhoto =
              group.photoUrl != null && group.photoUrl!.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Group Photo
              Center(
                child: GestureDetector(
                  onTap: iAmAdmin ? _pickGroupPhoto : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        backgroundImage:
                            hasPhoto ? NetworkImage(group.photoUrl!) : null,
                        child: !hasPhoto
                            ? const Icon(
                                Icons.group,
                                size: 60,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      if (iAmAdmin)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Group Name
              Center(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '${group.members.length} members',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.description.isEmpty
                          ? 'No description'
                          : group.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Members Header
              Row(
                children: [
                  Text(
                    '${group.members.length} Members',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (iAmAdmin)
                    IconButton(
                      icon: const Icon(
                        Icons.person_add,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _showAddMembersDialog(group),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Members List
              ...group.members.map((uid) {
                return FutureBuilder<UserModel?>(
                  future: _service.getUserById(uid),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData || userSnap.data == null) {
                      return const SizedBox.shrink();
                    }
                    final user = userSnap.data!;
                    final isUserAdmin = group.admins.contains(uid);
                    final isUserSuperAdmin = group.createdBy == uid;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(user.name[0].toUpperCase()),
                      ),
                      title: Row(
                        children: [
                          Text(user.name),
                          if (uid == _service.currentUserId)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text(
                                '(You)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        isUserSuperAdmin
                            ? 'Super Admin'
                            : isUserAdmin
                                ? 'Admin'
                                : 'Member',
                        style: TextStyle(
                          color: isUserAdmin
                              ? Colors.green
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _showMemberOptions(group, user),
                    );
                  },
                );
              }),

              const SizedBox(height: 20),

              // Exit Group Button
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                title: const Text(
                  'Exit Group',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Exit Group?'),
                      content: const Text('Are you sure you want to leave?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Exit',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _service.leaveGroup(widget.groupId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    }
                  }
                },
              ),

              // Delete Group (Admin only)
              if (iAmAdmin)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Group',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Group?'),
                        content: const Text(
                          'This will permanently delete the group for all members.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _service.deleteGroup(widget.groupId);
                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
