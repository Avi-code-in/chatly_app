class StatusModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String type; // text, image, video
  final String text;
  final String? imageUrl;
  final String? videoUrl;
  final DateTime timestamp;
  final DateTime expiresAt;
  final List<String> viewers;

  StatusModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.type,
    this.text = '',
    this.imageUrl,
    this.videoUrl,
    required this.timestamp,
    required this.expiresAt,
    this.viewers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'type': type,
      'text': text,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'timestamp': timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'viewers': viewers,
    };
  }

  factory StatusModel.fromMap(Map<String, dynamic> map, String id) {
    return StatusModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'],
      type: map['type'] ?? 'text',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'],
      videoUrl: map['videoUrl'],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(map['expiresAt'] ?? '') ?? DateTime.now(),
      viewers: List<String>.from(map['viewers'] ?? []),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
