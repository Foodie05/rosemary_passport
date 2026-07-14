class AuthenticatedUser {
  static const allowedRoles = {'user', 'admin'};

  const AuthenticatedUser({
    required this.id,
    required this.email,
    this.phoneNumber,
    this.isPhoneVerified = false,
    required this.nickname,
    required this.roles,
    this.accessTokenId,
    this.postRegistrationPasskeyBootstrapUntil,
  });

  final String id;
  final String email;
  final String? phoneNumber;
  final bool isPhoneVerified;
  final String nickname;
  final List<String> roles;
  final String? accessTokenId;
  final DateTime? postRegistrationPasskeyBootstrapUntil;

  bool get isAdmin => roles.contains('admin');
  bool get canBootstrapPasskeyAfterRegistration =>
      postRegistrationPasskeyBootstrapUntil != null &&
      DateTime.now().toUtc().isBefore(postRegistrationPasskeyBootstrapUntil!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone_number': phoneNumber,
        'is_phone_verified': isPhoneVerified,
        'nickname': nickname,
        'roles': roles,
      };
}
