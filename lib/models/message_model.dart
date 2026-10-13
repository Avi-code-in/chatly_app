class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String type; // text, image, file
  final String? imageData;
  final String? fileName;
  final String? fileData;
  final DateTime timestamp;
  final bool seen;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = 'text',
    this.imageData,
    this.fileName,
    this.fileData,
    required this.timestamp,
    this.seen = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'imageData': imageData,
      'fileName': fileName,
      'fileData': fileData,
      'timestamp': timestamp.toIso8601String(),
      'seen': seen,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      imageData: map['imageData'],
      fileName: map['fileName'],
      fileData: map['fileData'],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      seen: map['seen'] ?? false,
    );
  }
}
