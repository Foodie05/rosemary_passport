Map<String, dynamic> stepUpProofFromBody(
  Map<String, dynamic> body, {
  String? legacyPassword,
  String? legacyEmailCode,
}) {
  final verification = body['verification'];
  if (verification is Map) {
    return Map<String, dynamic>.from(verification);
  }
  if ((legacyPassword ?? '').isNotEmpty) {
    return {'method': 'password', 'password': legacyPassword};
  }
  if ((legacyEmailCode ?? '').isNotEmpty) {
    return {'method': 'email_code', 'code': legacyEmailCode};
  }
  return const <String, dynamic>{};
}
