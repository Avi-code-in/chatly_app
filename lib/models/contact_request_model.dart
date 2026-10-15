class ContactRequestModel {
  final String id;
  final String fromUid;
  final String fromName;
  final String fromUsername;
  final String? fromPhoto;
  final String toUid;
  final String message;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;

  ContactRequestModel({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromUsername,
    this.fromPhoto,
    required this.toUid,
    this.message = '',
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromUid': fromUid,
        'fromName': fromName,
        'fromUsername': fromUsername,
        'fromPhoto': fromPhoto,
        'toUid': toUid,
        'message': message,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ContactRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return ContactRequestModel(
      id: id,
      fromUid: map['fromUid'] ?? '',
      fromName: map['fromName'] ?? '',
      fromUsername: map['fromUsername'] ?? '',
      fromPhoto: map['fromPhoto'],
      toUid: map['toUid'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
