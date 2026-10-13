class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.uid,
    required this.name,
    this.email = '',
    this.phone = '',
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.tryParse(map['lastSeen'])
          : null,
    );
  }
}
