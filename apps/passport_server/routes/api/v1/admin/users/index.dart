import 'package:dart_frog/dart_frog.dart';
import 'package:uuid/uuid.dart';

import '../../../../../lib/src/config/app_config.dart';
import '../../../../../lib/src/models/authenticated_user.dart';
import '../../../../../lib/src/repositories/user_repository.dart';
import '../../../../../lib/src/security/password_hasher.dart';
import '../../../../../lib/src/services/audit_service.dart';
import '../../../../../lib/src/utils/http.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    final uri = context.request.uri;
    final page = int.tryParse(uri.queryParameters['page'] ?? '') ?? 1;
    final pageSize = int.tryParse(uri.queryParameters['page_size'] ?? '') ?? 10;
    final search = uri.queryParameters['search']?.trim();

    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? 10 : (pageSize > 100 ? 100 : pageSize);
    final offset = (safePage - 1) * safePageSize;

    final repository = context.read<UserRepository>();
    final users = await repository.listUsers(
      limit: safePageSize,
      offset: offset,
      search: search,
    );
    final total = await repository.countUsers(search: search);

    return jsonResponse({
      'users': users,
      'pagination': {
        'page': safePage,
        'page_size': safePageSize,
        'total': total,
        'total_pages': total == 0 ? 0 : ((total + safePageSize - 1) ~/ safePageSize),
      },
    });
  }

  if (context.request.method == HttpMethod.post) {
    final body = await tryParseJsonObject(context.request);
    if (body == null) {
      return errorResponse('invalid_request', 'Request body must be a JSON object.');
    }

    final email = (body['email'] ?? '').toString().trim();
    final nickname = (body['nickname'] ?? '').toString().trim();
    final password = (body['password'] ?? '').toString();
    final rawRoles = body['roles'];
    if (email.isEmpty || nickname.isEmpty || password.isEmpty || rawRoles is! List) {
      return errorResponse('invalid_request', 'email, nickname, password and roles are required.');
    }

    final roles = rawRoles
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (roles.isEmpty) {
      return errorResponse('invalid_request', 'roles must contain at least one non-empty role.');
    }
    if (!roles.every(AuthenticatedUser.allowedRoles.contains)) {
      return errorResponse(
        'invalid_request',
        'roles contains unsupported values.',
      );
    }
    if (roles.contains('admin') && email.toLowerCase().endsWith('@rosm.local')) {
      return errorResponse(
        'invalid_request',
        'reserved bootstrap admin email cannot be created from the admin panel.',
      );
    }

    final repository = context.read<UserRepository>();
    final existing = await repository.findByEmail(email);
    if (existing != null) {
      return errorResponse('conflict', 'email already exists.', statusCode: 409);
    }

    final config = AppConfig.fromEnv();
    final passwordHasher = PasswordHasher(config);
    final userId = const Uuid().v4();
    final passwordHash = await passwordHasher.hash(password);
    await repository.createUser(
      userId: userId,
      email: email,
      nickname: nickname,
      passwordHash: passwordHash,
      roles: roles,
      isEmailVerified: true,
    );

    final actor = context.read<AuthenticatedUser>();
    await context.read<AuditService>().log(
          action: 'admin.user.create',
          actorId: actor.id,
          actorType: 'admin',
          resourceType: 'user',
          resourceId: userId,
          metadata: {
            'email': email,
            'nickname': nickname,
            'roles': roles,
          },
          ip: context.request.headers['x-forwarded-for'],
        );

    return jsonResponse({
      'created': true,
      'user_id': userId,
    }, statusCode: 201);
  }

  return errorResponse('method_not_allowed', 'Use GET or POST.', statusCode: 405);
}
