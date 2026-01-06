// Freezed AuthState for Firestore OTP auth
// File: lib/features/auth/view_model/state/auth_state.dart

class AuthState {
  final bool isLoading;
  final bool codeSent;
  final String? phone;
  final String? otpError;
  final String? lastOtp;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? avatarUrl;
  final bool isProfileComplete;
  final bool isSignedIn;
  final String privacyLastSeen;
  final String privacyProfilePhoto;
  final String privacyAbout;
  final String privacyReadReceipts;
  final String? logoutReason;

  const AuthState({
    this.isLoading = false,
    this.codeSent = false,
    this.phone,
    this.otpError,
    this.lastOtp,
    this.userId,
    this.userName,
    this.userEmail,
    this.avatarUrl,
    this.isProfileComplete = false,
    this.isSignedIn = false,
    this.privacyLastSeen = 'everyone',
    this.privacyProfilePhoto = 'everyone',
    this.privacyAbout = 'everyone',
    this.privacyReadReceipts = 'everyone',
    this.logoutReason,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? codeSent,
    String? phone,
    String? otpError,
    String? lastOtp,
    String? userId,
    String? userName,
    String? userEmail,
    String? avatarUrl,
    bool? isProfileComplete,
    bool? isSignedIn,
    String? privacyLastSeen,
    String? privacyProfilePhoto,
    String? privacyAbout,
    String? privacyReadReceipts,
    String? logoutReason,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      codeSent: codeSent ?? this.codeSent,
      phone: phone ?? this.phone,
      otpError: otpError ?? this.otpError,
      lastOtp: lastOtp ?? this.lastOtp,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      privacyLastSeen: privacyLastSeen ?? this.privacyLastSeen,
      privacyProfilePhoto: privacyProfilePhoto ?? this.privacyProfilePhoto,
      privacyAbout: privacyAbout ?? this.privacyAbout,
      privacyReadReceipts: privacyReadReceipts ?? this.privacyReadReceipts,
      logoutReason: logoutReason ?? this.logoutReason,
    );
  }
}
