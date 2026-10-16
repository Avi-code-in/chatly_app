class UserModel {
  final String uid;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  // Privacy settings
  final String whoCanMessage; // 'everyone', 'contacts', 'nobody'
  final String whoCanSeeProfile; // 'everyone', 'contacts'
  final bool readReceipts;
  final bool lastSeenVisible;
  final String preferredLanguage;
  final bool liveTypingEnabled;

  UserModel({
    required this.uid,
    required this.name,
    this.username = '',
    this.email = '',
    this.phone = '',
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
    this.whoCanMessage = 'contacts',
    this.whoCanSeeProfile = 'everyone',
    this.readReceipts = true,
    this.lastSeenVisible = true,
    this.preferredLanguage = 'en',
    this.liveTypingEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'whoCanMessage': whoCanMessage,
      'whoCanSeeProfile': whoCanSeeProfile,
      'readReceipts': readReceipts,
      'lastSeenVisible': lastSeenVisible,
      'preferredLanguage': preferredLanguage,
      'liveTypingEnabled': liveTypingEnabled,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.tryParse(map['lastSeen'])
          : null,
      whoCanMessage: map['whoCanMessage'] ?? 'contacts',
      whoCanSeeProfile: map['whoCanSeeProfile'] ?? 'everyone',
      readReceipts: map['readReceipts'] ?? true,
      lastSeenVisible: map['lastSeenVisible'] ?? true,
      preferredLanguage: map['preferredLanguage'] ?? 'en',
      liveTypingEnabled: map['liveTypingEnabled'] ?? true,
    );
  }
}
