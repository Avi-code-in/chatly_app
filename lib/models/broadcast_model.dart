class BroadcastModel {
  final String id;
  final String name;
  final List<String> receiverIds;
  final String lastMessage;
  final DateTime createdAt;
  final DateTime? lastMessageTime;

  BroadcastModel({
    required this.id,
    required this.name,
    this.receiverIds = const [],
    this.lastMessage = '',
    required this.createdAt,
    this.lastMessageTime,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'receiverIds': receiverIds,
        'lastMessage': lastMessage,
        'createdAt': createdAt.toIso8601String(),
        'lastMessageTime': lastMessageTime?.toIso8601String(),
      };

  factory BroadcastModel.fromMap(Map<String, dynamic> map, String id) {
    return BroadcastModel(
      id: id,
      name: map['name'] ?? '',
      receiverIds: List<String>.from(map['receiverIds'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.tryParse(map['lastMessageTime'])
          : null,
    );
  }
}
