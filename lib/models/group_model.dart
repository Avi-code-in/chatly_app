class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? photoUrl;
  final List<String> members;
  final List<String> admins;
  final String createdBy;
  final bool membersCanAdd;
  final bool membersCanSend;
  final bool membersCanEditInfo;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.photoUrl,
    required this.members,
    this.admins = const [],
    required this.createdBy,
    this.membersCanAdd = true,
    this.membersCanSend = true,
    this.membersCanEditInfo = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'photoUrl': photoUrl,
      'members': members,
      'admins': admins,
      'createdBy': createdBy,
      'membersCanAdd': membersCanAdd,
      'membersCanSend': membersCanSend,
      'membersCanEditInfo': membersCanEditInfo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      photoUrl: map['photoUrl'],
      members: List<String>.from(map['members'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      createdBy: map['createdBy'] ?? '',
      membersCanAdd: map['membersCanAdd'] ?? true,
      membersCanSend: map['membersCanSend'] ?? true,
      membersCanEditInfo: map['membersCanEditInfo'] ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool isAdmin(String uid) => admins.contains(uid);
  bool isMember(String uid) => members.contains(uid);
  bool isSuperAdmin(String uid) => createdBy == uid;
}
