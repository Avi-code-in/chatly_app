class ContactTagModel {
  final String id;
  final String name;
  final String color;
  final List<String> userIds;
  final DateTime createdAt;

  ContactTagModel({
    required this.id,
    required this.name,
    required this.color,
    this.userIds = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'userIds': userIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ContactTagModel.fromMap(Map<String, dynamic> map, String id) {
    return ContactTagModel(
      id: id,
      name: map['name'] ?? '',
      color: map['color'] ?? '#4A6CF7',
      userIds: List<String>.from(map['userIds'] ?? []),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
