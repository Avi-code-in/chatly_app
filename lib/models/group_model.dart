class GroupModel {
  final String id;
  final String name;
  final String? photoUrl;
  final List<String> members;
  final String createdBy;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.members,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photoUrl': photoUrl,
      'members': members,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      members: List<String>.from(map['members'] ?? []),
      createdBy: map['createdBy'] ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
