class ScheduledMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime scheduledAt;
  final bool isSent;

  ScheduledMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.scheduledAt,
    this.isSent = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'chatId': chatId,
        'senderId': senderId,
        'text': text,
        'scheduledAt': scheduledAt.toIso8601String(),
        'isSent': isSent,
      };

  factory ScheduledMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return ScheduledMessageModel(
      id: id,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      scheduledAt:
          DateTime.tryParse(map['scheduledAt'] ?? '') ?? DateTime.now(),
      isSent: map['isSent'] ?? false,
    );
  }
}
