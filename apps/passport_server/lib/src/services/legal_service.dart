import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import '../repositories/legal_repository.dart';

class LegalSubmission {
  const LegalSubmission({
    required this.terms,
    required this.privacy,
    required this.accepted,
  });

  factory LegalSubmission.fromJson(Map<String, dynamic> json) =>
      LegalSubmission(
        terms: int.tryParse('${json['terms_version'] ?? ''}'),
        privacy: int.tryParse('${json['privacy_version'] ?? ''}'),
        accepted: json['accepted_legal'] == true,
      );

  final int? terms;
  final int? privacy;
  final bool accepted;
}

class LegalValidation {
  const LegalValidation.valid(this.terms, this.privacy) : ok = true;
  const LegalValidation.invalid(this.terms, this.privacy) : ok = false;

  final bool ok;
  final Map<String, dynamic> terms;
  final Map<String, dynamic> privacy;

  Map<String, dynamic> get publicBundle => {
    'terms': _publicDocument(terms),
    'privacy': _publicDocument(privacy),
  };

  static Map<String, dynamic> _publicDocument(Map<String, dynamic> value) => {
    'id': value['id'],
    'type': value['type'],
    'version': value['version'],
    'title': value['title'],
    'published_at': value['published_at'],
  };
}

class LegalService {
  LegalService(this._repository, this._config);

  final LegalRepository _repository;
  final AppConfig _config;
  Future<void>? _initialization;

  static const companyName = 'Rosemary Island LLC';
  static const contactEmail = 'info@rosemaryisland.pro';

  Future<void> ensureInitialDocuments() =>
      _initialization ??= _ensureInitialDocuments();

  Future<void> _ensureInitialDocuments() async {
    await _ensureInitial(
      type: 'terms',
      title: 'ROSM Pass 使用条款',
      configuredPath: _config.legalInitialTermsFile,
      configurationName: 'LEGAL_INITIAL_TERMS_FILE',
    );
    await _ensureInitial(
      type: 'privacy',
      title: 'ROSM Pass 隐私政策',
      configuredPath: _config.legalInitialPrivacyFile,
      configurationName: 'LEGAL_INITIAL_PRIVACY_FILE',
    );
  }

  Future<void> _ensureInitial({
    required String type,
    required String title,
    required String configuredPath,
    required String configurationName,
  }) async {
    if (await _repository.current(type) != null) return;
    final path = configuredPath.trim();
    if (path.isEmpty) {
      throw StateError(
        'No published $type document exists; configure $configurationName.',
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('$configurationName does not exist.');
    }
    final content = (await file.readAsString()).trim();
    if (content.isEmpty) {
      throw StateError('$configurationName is empty.');
    }
    final draft = await _repository.saveDraft(
      type: type,
      title: title,
      content: content,
      actorId: '00000000-0000-0000-0000-000000000000',
    );
    await _repository.publish(
      documentId: draft['id'].toString(),
      actorId: '00000000-0000-0000-0000-000000000000',
    );
  }

  Future<Map<String, dynamic>> currentBundle({
    bool includeContent = true,
  }) async {
    await ensureInitialDocuments();
    final terms = await _repository.current('terms');
    final privacy = await _repository.current('privacy');
    if (terms == null || privacy == null) {
      throw StateError('Published legal documents are unavailable.');
    }
    if (includeContent) return {'terms': terms, 'privacy': privacy};
    return {
      'terms': LegalValidation._publicDocument(terms),
      'privacy': LegalValidation._publicDocument(privacy),
    };
  }

  Future<LegalValidation> validate(LegalSubmission submission) async {
    await ensureInitialDocuments();
    final terms = await _repository.current('terms');
    final privacy = await _repository.current('privacy');
    if (terms == null || privacy == null) {
      throw StateError('Published legal documents are unavailable.');
    }
    final matches =
        submission.accepted &&
        submission.terms == terms['version'] &&
        submission.privacy == privacy['version'];
    return matches
        ? LegalValidation.valid(terms, privacy)
        : LegalValidation.invalid(terms, privacy);
  }

  Future<void> record({
    required String userId,
    required LegalValidation validation,
    required String context,
    required String? ip,
    required String? userAgent,
  }) {
    if (!validation.ok) throw StateError('Legal acceptance is not current.');
    return _repository.recordAcceptance(
      userId: userId,
      termsId: validation.terms['id'].toString(),
      privacyId: validation.privacy['id'].toString(),
      context: context,
      ipHash: _hashOptional(ip),
      userAgentHash: _hashOptional(userAgent),
    );
  }

  Future<bool> hasAcceptedCurrent(String userId) =>
      _repository.hasAcceptedCurrent(userId);

  String? _hashOptional(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    final key = utf8.encode(_config.jwtBindingKey);
    return Hmac(sha256, key).convert(utf8.encode(normalized)).toString();
  }
}
