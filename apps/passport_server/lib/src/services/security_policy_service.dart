import '../repositories/settings_repository.dart';

class RegistrationEmailProviderPolicy {
  const RegistrationEmailProviderPolicy({
    required this.mode,
    required this.blacklist,
    required this.whitelist,
  });

  final String mode;
  final List<String> blacklist;
  final List<String> whitelist;

  bool get isWhitelistMode => mode == SecurityPolicyService.whitelistMode;
  bool get isBlacklistMode => mode == SecurityPolicyService.blacklistMode;

  bool allows(String email) {
    final provider = SecurityPolicyService.extractEmailProvider(email);
    if (provider == null) {
      return false;
    }
    if (isWhitelistMode) {
      return whitelist.contains(provider);
    }
    if (isBlacklistMode) {
      return !blacklist.contains(provider);
    }
    return true;
  }
}

class SecurityPolicy {
  const SecurityPolicy({
    required this.emailRateLimitEnabled,
    required this.ipRateLimitEnabled,
    required this.emailCodeMaxAttempts,
    required this.registerCodeCooldownSeconds,
    required this.loginCodeCooldownSeconds,
    required this.adminLoginCodeCooldownSeconds,
    required this.bindEmailCodeCooldownSeconds,
    required this.passwordResetCodeCooldownSeconds,
    required this.registerCodeEmailLimit,
    required this.registerCodeIpLimit,
    required this.registerCodeWindowSeconds,
    required this.registerCodeBlockSeconds,
    required this.adminLoginCodeEmailLimit,
    required this.adminLoginCodeIpLimit,
    required this.adminLoginCodeWindowSeconds,
    required this.adminLoginCodeBlockSeconds,
    required this.loginEmailLimit,
    required this.loginIpLimit,
    required this.loginWindowSeconds,
    required this.loginBlockSeconds,
    required this.refreshIpLimit,
    required this.refreshWindowSeconds,
    required this.refreshBlockSeconds,
    required this.oidcTokenIpLimit,
    required this.oidcTokenWindowSeconds,
    required this.oidcTokenBlockSeconds,
    required this.oidcIntrospectIpLimit,
    required this.oidcIntrospectWindowSeconds,
    required this.oidcIntrospectBlockSeconds,
    required this.registrationEmailProviderMode,
    required this.registrationEmailProviderBlacklist,
    required this.registrationEmailProviderWhitelist,
  });

  final bool emailRateLimitEnabled;
  final bool ipRateLimitEnabled;
  final int emailCodeMaxAttempts;
  final int registerCodeCooldownSeconds;
  final int loginCodeCooldownSeconds;
  final int adminLoginCodeCooldownSeconds;
  final int bindEmailCodeCooldownSeconds;
  final int passwordResetCodeCooldownSeconds;
  final int registerCodeEmailLimit;
  final int registerCodeIpLimit;
  final int registerCodeWindowSeconds;
  final int registerCodeBlockSeconds;
  final int adminLoginCodeEmailLimit;
  final int adminLoginCodeIpLimit;
  final int adminLoginCodeWindowSeconds;
  final int adminLoginCodeBlockSeconds;
  final int loginEmailLimit;
  final int loginIpLimit;
  final int loginWindowSeconds;
  final int loginBlockSeconds;
  final int refreshIpLimit;
  final int refreshWindowSeconds;
  final int refreshBlockSeconds;
  final int oidcTokenIpLimit;
  final int oidcTokenWindowSeconds;
  final int oidcTokenBlockSeconds;
  final int oidcIntrospectIpLimit;
  final int oidcIntrospectWindowSeconds;
  final int oidcIntrospectBlockSeconds;
  final String registrationEmailProviderMode;
  final List<String> registrationEmailProviderBlacklist;
  final List<String> registrationEmailProviderWhitelist;
}

class SecurityPolicyService {
  SecurityPolicyService(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  static const blacklistMode = 'blacklist';
  static const whitelistMode = 'whitelist';

  static const Map<String, int> defaults = {
    'email_code_max_attempts': 8,
    'register_code_cooldown_seconds': 45,
    'login_code_cooldown_seconds': 30,
    'admin_login_code_cooldown_seconds': 45,
    'bind_email_code_cooldown_seconds': 45,
    'password_reset_code_cooldown_seconds': 45,
    'register_code_email_limit': 6,
    'register_code_ip_limit': 24,
    'register_code_window_seconds': 600,
    'register_code_block_seconds': 600,
    'admin_login_code_email_limit': 8,
    'admin_login_code_ip_limit': 30,
    'admin_login_code_window_seconds': 900,
    'admin_login_code_block_seconds': 600,
    'login_email_limit': 12,
    'login_ip_limit': 36,
    'login_window_seconds': 900,
    'login_block_seconds': 600,
    'refresh_ip_limit': 30,
    'refresh_window_seconds': 300,
    'refresh_block_seconds': 600,
    'oidc_token_ip_limit': 30,
    'oidc_token_window_seconds': 300,
    'oidc_token_block_seconds': 600,
    'oidc_introspect_ip_limit': 60,
    'oidc_introspect_window_seconds': 300,
    'oidc_introspect_block_seconds': 600,
  };

  static const Map<String, bool> toggleDefaults = {
    'email_rate_limit_enabled': true,
    'ip_rate_limit_enabled': true,
  };

  static const Map<String, dynamic> registrationDefaults = {
    'registration_email_provider_mode': blacklistMode,
    'registration_email_provider_blacklist': <String>[],
    'registration_email_provider_whitelist': <String>[],
  };

  static const SecurityPolicy defaultPolicy = SecurityPolicy(
    emailRateLimitEnabled: true,
    ipRateLimitEnabled: true,
    emailCodeMaxAttempts: 8,
    registerCodeCooldownSeconds: 45,
    loginCodeCooldownSeconds: 30,
    adminLoginCodeCooldownSeconds: 45,
    bindEmailCodeCooldownSeconds: 45,
    passwordResetCodeCooldownSeconds: 45,
    registerCodeEmailLimit: 6,
    registerCodeIpLimit: 24,
    registerCodeWindowSeconds: 600,
    registerCodeBlockSeconds: 600,
    adminLoginCodeEmailLimit: 8,
    adminLoginCodeIpLimit: 30,
    adminLoginCodeWindowSeconds: 900,
    adminLoginCodeBlockSeconds: 600,
    loginEmailLimit: 12,
    loginIpLimit: 36,
    loginWindowSeconds: 900,
    loginBlockSeconds: 600,
    refreshIpLimit: 30,
    refreshWindowSeconds: 300,
    refreshBlockSeconds: 600,
    oidcTokenIpLimit: 30,
    oidcTokenWindowSeconds: 300,
    oidcTokenBlockSeconds: 600,
    oidcIntrospectIpLimit: 60,
    oidcIntrospectWindowSeconds: 300,
    oidcIntrospectBlockSeconds: 600,
    registrationEmailProviderMode: blacklistMode,
    registrationEmailProviderBlacklist: <String>[],
    registrationEmailProviderWhitelist: <String>[],
  );

  Future<SecurityPolicy> load() async {
    final raw = await _settingsRepository.getJson('security');
    return SecurityPolicy(
      emailRateLimitEnabled: _readBool(raw, 'email_rate_limit_enabled'),
      ipRateLimitEnabled: _readBool(raw, 'ip_rate_limit_enabled'),
      emailCodeMaxAttempts: _readInt(raw, 'email_code_max_attempts'),
      registerCodeCooldownSeconds: _readInt(
        raw,
        'register_code_cooldown_seconds',
      ),
      loginCodeCooldownSeconds: _readInt(raw, 'login_code_cooldown_seconds'),
      adminLoginCodeCooldownSeconds: _readInt(
        raw,
        'admin_login_code_cooldown_seconds',
      ),
      bindEmailCodeCooldownSeconds: _readInt(
        raw,
        'bind_email_code_cooldown_seconds',
      ),
      passwordResetCodeCooldownSeconds: _readInt(
        raw,
        'password_reset_code_cooldown_seconds',
      ),
      registerCodeEmailLimit: _readInt(raw, 'register_code_email_limit'),
      registerCodeIpLimit: _readInt(raw, 'register_code_ip_limit'),
      registerCodeWindowSeconds: _readInt(raw, 'register_code_window_seconds'),
      registerCodeBlockSeconds: _readInt(raw, 'register_code_block_seconds'),
      adminLoginCodeEmailLimit: _readInt(raw, 'admin_login_code_email_limit'),
      adminLoginCodeIpLimit: _readInt(raw, 'admin_login_code_ip_limit'),
      adminLoginCodeWindowSeconds: _readInt(
        raw,
        'admin_login_code_window_seconds',
      ),
      adminLoginCodeBlockSeconds: _readInt(
        raw,
        'admin_login_code_block_seconds',
      ),
      loginEmailLimit: _readInt(raw, 'login_email_limit'),
      loginIpLimit: _readInt(raw, 'login_ip_limit'),
      loginWindowSeconds: _readInt(raw, 'login_window_seconds'),
      loginBlockSeconds: _readInt(raw, 'login_block_seconds'),
      refreshIpLimit: _readInt(raw, 'refresh_ip_limit'),
      refreshWindowSeconds: _readInt(raw, 'refresh_window_seconds'),
      refreshBlockSeconds: _readInt(raw, 'refresh_block_seconds'),
      oidcTokenIpLimit: _readInt(raw, 'oidc_token_ip_limit'),
      oidcTokenWindowSeconds: _readInt(raw, 'oidc_token_window_seconds'),
      oidcTokenBlockSeconds: _readInt(raw, 'oidc_token_block_seconds'),
      oidcIntrospectIpLimit: _readInt(raw, 'oidc_introspect_ip_limit'),
      oidcIntrospectWindowSeconds: _readInt(
        raw,
        'oidc_introspect_window_seconds',
      ),
      oidcIntrospectBlockSeconds: _readInt(
        raw,
        'oidc_introspect_block_seconds',
      ),
      registrationEmailProviderMode: _readProviderMode(raw),
      registrationEmailProviderBlacklist: _readProviderList(
        raw,
        'registration_email_provider_blacklist',
      ),
      registrationEmailProviderWhitelist: _readProviderList(
        raw,
        'registration_email_provider_whitelist',
      ),
    );
  }

  Future<RegistrationEmailProviderPolicy>
  loadRegistrationEmailProviderPolicy() async {
    final raw = await _settingsRepository.getJson('security');
    return RegistrationEmailProviderPolicy(
      mode: _readProviderMode(raw),
      blacklist: _readProviderList(
        raw,
        'registration_email_provider_blacklist',
      ),
      whitelist: _readProviderList(
        raw,
        'registration_email_provider_whitelist',
      ),
    );
  }

  Future<Map<String, dynamic>> mergedSecuritySettings() async {
    final raw = await _settingsRepository.getJson('security');
    final sanitized = sanitizeSecuritySettings(raw);
    return {
      ...toggleDefaults,
      ...defaults,
      ...registrationDefaults,
      ...sanitized,
    };
  }

  Map<String, dynamic> sanitizeSecuritySettings(Map<String, dynamic> raw) {
    return {
      ...raw,
      'registration_email_provider_mode': _readProviderMode(raw),
      'registration_email_provider_blacklist': _readProviderList(
        raw,
        'registration_email_provider_blacklist',
      ),
      'registration_email_provider_whitelist': _readProviderList(
        raw,
        'registration_email_provider_whitelist',
      ),
    };
  }

  static String? normalizeEmailProviderPattern(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return null;
    }

    var candidate = trimmed;
    if (candidate.contains('@') && !candidate.startsWith('@')) {
      final atIndex = candidate.lastIndexOf('@');
      candidate = candidate.substring(atIndex);
    }
    if (!candidate.startsWith('@')) {
      candidate = '@$candidate';
    }
    if (candidate.length <= 1 ||
        candidate.contains(' ') ||
        !candidate.substring(1).contains('.')) {
      return null;
    }
    return candidate;
  }

  static String? extractEmailProvider(String email) {
    final normalized = email.trim().toLowerCase();
    final atIndex = normalized.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == normalized.length - 1) {
      return null;
    }
    return normalizeEmailProviderPattern(normalized.substring(atIndex));
  }

  bool _readBool(Map<String, dynamic> raw, String key) {
    final fallback = toggleDefaults[key] ?? true;
    final value = raw[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return fallback;
  }

  int _readInt(Map<String, dynamic> raw, String key) {
    final fallback = defaults[key]!;
    final value = raw[key];
    if (value is int && value > 0) {
      return value;
    }
    final parsed = int.tryParse('$value');
    if (parsed == null || parsed <= 0) {
      return fallback;
    }
    return parsed;
  }

  String _readProviderMode(Map<String, dynamic> raw) {
    final value = (raw['registration_email_provider_mode'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (value == whitelistMode) {
      return whitelistMode;
    }
    return blacklistMode;
  }

  List<String> _readProviderList(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    final items = <String>[];
    if (value is List) {
      items.addAll(value.map((item) => item.toString()));
    } else if (value is String && value.trim().isNotEmpty) {
      items.addAll(value.split(RegExp(r'[\n,]')));
    }

    final seen = <String>{};
    final normalized = <String>[];
    for (final item in items) {
      final provider = normalizeEmailProviderPattern(item);
      if (provider == null || seen.contains(provider)) {
        continue;
      }
      seen.add(provider);
      normalized.add(provider);
    }
    return normalized;
  }
}
