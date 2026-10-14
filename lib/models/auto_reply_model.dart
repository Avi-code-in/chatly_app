class AutoReplyModel {
  final String id;
  final String message;
  final bool enabled;
  final bool onlyOutsideHours;
  final int startHour;
  final int endHour;
  final DateTime updatedAt;

  AutoReplyModel({
    required this.id,
    required this.message,
    this.enabled = false,
    this.onlyOutsideHours = false,
    this.startHour = 22,
    this.endHour = 9,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'message': message,
        'enabled': enabled,
        'onlyOutsideHours': onlyOutsideHours,
        'startHour': startHour,
        'endHour': endHour,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AutoReplyModel.fromMap(Map<String, dynamic> map, String id) {
    return AutoReplyModel(
      id: id,
      message: map['message'] ?? '',
      enabled: map['enabled'] ?? false,
      onlyOutsideHours: map['onlyOutsideHours'] ?? false,
      startHour: map['startHour'] ?? 22,
      endHour: map['endHour'] ?? 9,
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
