class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type; // text, image, video, file, voice, location
  final String? imageUrl;
  final String? videoUrl;
  final String? fileName;
  final String? fileData;

  // Voice
  final String? voiceUrl;
  final int? voiceDuration; // in seconds
  final String? transcribedText;

  // Location
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final bool isLiveLocation;
  final DateTime? liveLocationExpiresAt;

  final DateTime timestamp;
  final bool seen;

  // Reply
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;

  // Reactions
  final Map<String, List<String>> reactions;

  // Star
  final List<String> starredBy;

  // Disappearing
  final DateTime? expiresAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    this.imageUrl,
    this.videoUrl,
    this.fileName,
    this.fileData,
    this.voiceUrl,
    this.voiceDuration,
    this.transcribedText,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.isLiveLocation = false,
    this.liveLocationExpiresAt,
    required this.timestamp,
    this.seen = false,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.reactions = const {},
    this.starredBy = const [],
    this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'fileName': fileName,
      'fileData': fileData,
      'voiceUrl': voiceUrl,
      'voiceDuration': voiceDuration,
      'transcribedText': transcribedText,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
      'isLiveLocation': isLiveLocation,
      'liveLocationExpiresAt': liveLocationExpiresAt?.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
      'seen': seen,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
      'reactions': reactions,
      'starredBy': starredBy,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    final Map<String, List<String>> parsedReactions = {};
    if (map['reactions'] != null) {
      final raw = map['reactions'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        parsedReactions[key] = List<String>.from(value);
      });
    }

    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      imageUrl: map['imageUrl'],
      videoUrl: map['videoUrl'],
      fileName: map['fileName'],
      fileData: map['fileData'],
      voiceUrl: map['voiceUrl'],
      voiceDuration: map['voiceDuration'],
      transcribedText: map['transcribedText'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationAddress: map['locationAddress'],
      isLiveLocation: map['isLiveLocation'] ?? false,
      liveLocationExpiresAt: map['liveLocationExpiresAt'] != null
          ? DateTime.tryParse(map['liveLocationExpiresAt'])
          : null,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      seen: map['seen'] ?? false,
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      replyToSender: map['replyToSender'],
      reactions: parsedReactions,
      starredBy: List<String>.from(map['starredBy'] ?? []),
      expiresAt:
          map['expiresAt'] != null ? DateTime.tryParse(map['expiresAt']) : null,
    );
  }

  bool isStarredBy(String uid) => starredBy.contains(uid);
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
