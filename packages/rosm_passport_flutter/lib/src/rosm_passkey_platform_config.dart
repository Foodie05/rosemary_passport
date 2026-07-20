class RosmPasskeyPlatformConfig {
  const RosmPasskeyPlatformConfig({
    required this.rpDomain,
    this.appleTeamId,
    this.appleBundleId,
    this.androidPackageName,
    this.androidSha256CertFingerprints = const [],
  });

  final String rpDomain;
  final String? appleTeamId;
  final String? appleBundleId;
  final String? androidPackageName;
  final List<String> androidSha256CertFingerprints;

  String get appleAssociatedDomain => 'webcredentials:$rpDomain';

  String? get appleAppId {
    final teamId = appleTeamId?.trim();
    final bundleId = appleBundleId?.trim();
    if (teamId == null ||
        teamId.isEmpty ||
        bundleId == null ||
        bundleId.isEmpty) {
      return null;
    }
    return '$teamId.$bundleId';
  }

  Uri get appleAppSiteAssociationUri =>
      Uri.https(rpDomain, '/.well-known/apple-app-site-association');

  Uri get androidAssetLinksUri =>
      Uri.https(rpDomain, '/.well-known/assetlinks.json');

  Map<String, Object?> appleAppSiteAssociation({
    bool includeUniversalLinks = false,
  }) {
    final appId = appleAppId;
    if (appId == null) {
      throw ArgumentError(
        'appleTeamId and appleBundleId are required for Apple passkeys.',
      );
    }
    return {
      'webcredentials': {
        'apps': [appId],
      },
      if (includeUniversalLinks)
        'applinks': {
          'apps': <String>[],
          'details': [
            {
              'appID': appId,
              'paths': ['*'],
            },
          ],
        },
    };
  }

  List<Map<String, Object?>> androidAssetLinks({
    bool includeHandleAllUrls = false,
  }) {
    final packageName = androidPackageName?.trim();
    if (packageName == null || packageName.isEmpty) {
      throw ArgumentError(
        'androidPackageName is required for Android passkeys.',
      );
    }
    if (androidSha256CertFingerprints.isEmpty) {
      throw ArgumentError(
        'androidSha256CertFingerprints must include debug, release, and Play signing certificates used by the app.',
      );
    }
    return [
      {
        'relation': [
          'delegate_permission/common.get_login_creds',
          if (includeHandleAllUrls)
            'delegate_permission/common.handle_all_urls',
        ],
        'target': {
          'namespace': 'android_app',
          'package_name': packageName,
          'sha256_cert_fingerprints': androidSha256CertFingerprints,
        },
      },
    ];
  }

  Map<String, Object?> androidAssetStatementsInclude() {
    return {'include': androidAssetLinksUri.toString()};
  }
}
