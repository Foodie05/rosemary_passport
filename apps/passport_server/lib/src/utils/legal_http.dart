import 'package:dart_frog/dart_frog.dart';

import '../config/app_config.dart';
import '../services/legal_service.dart';
import 'http.dart';

Future<(LegalValidation?, Response?)> validateLegalSubmission(
  RequestContext context,
  Map<String, dynamic> body,
) async {
  final validation = await context.read<LegalService>().validate(
    LegalSubmission.fromJson(body),
  );
  if (validation.ok) return (validation, null);
  return (
    null,
    jsonResponse({
      'error': 'legal_acceptance_required',
      'message': '请阅读并同意当前版本的使用条款和隐私政策。',
      'legal': validation.publicBundle,
    }, statusCode: 428),
  );
}

Future<void> recordLegalAcceptance(
  RequestContext context, {
  required String userId,
  required LegalValidation validation,
  required String acceptanceContext,
}) {
  return context.read<LegalService>().record(
    userId: userId,
    validation: validation,
    context: acceptanceContext,
    ip: clientIpFromRequest(context.request, config: context.read<AppConfig>()),
    userAgent: context.request.headers['user-agent'],
  );
}
