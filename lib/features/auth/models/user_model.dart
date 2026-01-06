// File: lib/features/auth/models/user_model.dart

class UserModel {
  final String uid;
  final String phone;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime lastSeen;
  final String? about;
  final String privacyLastSeen;
  final String privacyProfilePhoto;
  final String privacyAbout;
  final String privacyReadReceipts;

  const UserModel({
    required this.uid,
    required this.phone,
    this.name,
    this.email,
    this.avatarUrl,
    required this.createdAt,
    required this.lastSeen,
    this.about,
    this.privacyLastSeen = 'everyone',
    this.privacyProfilePhoto = 'everyone',
    this.privacyAbout = 'everyone',
    this.privacyReadReceipts = 'everyone',
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      phone: map['phone'] as String,
      name: map['name'] as String?,
      email: map['email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastSeen: DateTime.parse(map['last_seen'] as String),
      about: map['about'] as String?,
      privacyLastSeen: map['privacy_last_seen'] as String? ?? 'everyone',
      privacyProfilePhoto:
          map['privacy_profile_photo'] as String? ?? 'everyone',
      privacyAbout: map['privacy_about'] as String? ?? 'everyone',
      privacyReadReceipts:
          map['privacy_read_receipts'] as String? ?? 'everyone',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'last_seen': lastSeen.toIso8601String(),
      'about': about,
      'privacy_last_seen': privacyLastSeen,
      'privacy_profile_photo': privacyProfilePhoto,
      'privacy_about': privacyAbout,
      'privacy_read_receipts': privacyReadReceipts,
    };
  }
}
