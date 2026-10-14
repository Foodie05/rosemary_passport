import '../../lib/src/utils/epass_loading.dart';
import '../../lib/src/utils/epass_design.dart';

import 'dart:convert';
import 'dart:math';

import 'package:dart_frog/dart_frog.dart';
import 'package:meta/meta.dart';

import '../../lib/src/config/app_config.dart';
import '../../lib/src/middleware/guards.dart';
import '../../lib/src/services/auth_service.dart';
import '../../lib/src/services/oidc_service.dart';
import '../../lib/src/utils/auth_cookie.dart';
import '../../lib/src/utils/oidc_error_page.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return oidcErrorResponse(
      context,
      code: 'method_not_allowed',
      message: 'Use GET.',
      statusCode: 405,
      title: '您要登录的应用没有正确响应',
      description: '这个应用发起了不受支持的授权请求方式，Rosemary Epass 无法继续处理。',
    );
  }

  final user = await currentUser(context, requireFirstParty: true);
  final config = context.read<AppConfig>();
  if (context.request.uri.queryParameters['switch_account'] == '1') {
    final accessToken = readCookieValue(
      context.request.headers['cookie'],
      kAccessTokenCookieName,
    );
    await context.read<AuthService>().logoutFirstPartySession(
      accessToken: accessToken,
    );
    final resumeParameters = {...context.request.uri.queryParametersAll}
      ..remove('switch_account');
    final nextAuthorizeUrl = _webOidcContinuePath(resumeParameters);
    final loginUrl = Uri.parse(
      config.webBaseUrl,
    ).resolve('/login').replace(queryParameters: {'next': nextAuthorizeUrl});
    return Response(
      statusCode: 302,
      headers: {
        'location': loginUrl.toString(),
        'set-cookie': buildExpiredAccessTokenCookie(config: config),
      },
    );
  }
  if (user == null) {
    final authorizeUrl = _webOidcContinuePath(
      context.request.uri.queryParametersAll,
    );
    final loginUrl = Uri.parse(
      config.webBaseUrl,
    ).resolve('/login').replace(queryParameters: {'next': authorizeUrl});
    return Response(
      statusCode: 302,
      headers: {'location': loginUrl.toString()},
    );
  }
  if (user.isBanned) {
    final bannedUrl = Uri.parse(config.webBaseUrl).resolve('/banned');
    return Response(
      statusCode: 302,
      headers: {'location': bannedUrl.toString()},
    );
  }

  final uri = context.request.uri;
  final clientId = uri.queryParameters['client_id'];
  final redirectUri = uri.queryParameters['redirect_uri'];
  final responseType = uri.queryParameters['response_type'] ?? '';
  final scope = uri.queryParameters['scope'] ?? 'openid profile email';
  final state = uri.queryParameters['state'];
  final nonce = uri.queryParameters['nonce'];
  final codeChallenge = uri.queryParameters['code_challenge'];
  final codeChallengeMethod = uri.queryParameters['code_challenge_method'];
  final decision = uri.queryParameters['decision'];

  if (clientId == null || redirectUri == null || responseType.isEmpty) {
    return oidcErrorResponse(
      context,
      code: 'invalid_request',
      message: 'client_id, redirect_uri and response_type are required.',
      statusCode: 400,
      title: '您要登录的应用没有正确响应',
      description: '当前登录请求缺少必要参数，Rosemary Epass 无法继续完成授权。',
    );
  }

  final oidc = context.read<OidcService>();
  final client = await oidc.findClient(clientId);
  if (client == null) {
    return oidcErrorResponse(
      context,
      code: 'access_denied',
      message: 'Authorization request rejected.',
      statusCode: 400,
      title: '您要登录的应用没有正确响应',
      description: '这个应用尚未在 Rosemary Epass 中正确配置，登录流程无法继续。',
    );
  }

  final requestedScopes = scope
      .split(' ')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet();
  final allowedScopes = (client['scopes'] as List<String>).toSet();
  final redirectUris = (client['redirect_uris'] as List<String>).toSet();
  final grantTypes = (client['grant_types'] as List<String>).toSet();
  final pkceRequired = context.read<AppConfig>().oidcRequirePkce;

  final requestValid =
      responseType == 'code' &&
      redirectUris.contains(redirectUri) &&
      grantTypes.contains('authorization_code') &&
      requestedScopes.every(allowedScopes.contains) &&
      (!requestedScopes.contains('openid') ||
          (nonce != null && nonce.trim().isNotEmpty)) &&
      (!pkceRequired ||
          (codeChallenge != null && codeChallengeMethod == 'S256'));

  if (!requestValid) {
    return oidcErrorResponse(
      context,
      code: 'access_denied',
      message: 'Authorization request rejected.',
      statusCode: 400,
      title: '您要登录的应用没有正确响应',
      description: '这个应用发起的登录请求不完整或配置不正确，Rosemary Epass 无法安全地继续登录流程。',
    );
  }

  if (decision == 'cancel') {
    if (!_isConsentRequestValid(context)) {
      return oidcErrorResponse(
        context,
        code: 'invalid_request',
        message: 'Consent confirmation required.',
        statusCode: 400,
        title: '您要登录的应用没有正确响应',
        description: '这次授权确认未通过安全校验，请返回授权页后重试。',
      );
    }
    final callback = Uri.parse(redirectUri).replace(
      queryParameters: {
        ...Uri.parse(redirectUri).queryParameters,
        'error': 'access_denied',
        'error_description': 'The user denied the authorization request.',
        if (state != null) 'state': state,
      },
    );
    return Response(
      statusCode: 302,
      headers: {
        'location': callback.toString(),
        'set-cookie': buildExpiredOidcConsentCookie(
          config: context.read<AppConfig>(),
        ),
      },
    );
  }

  if (decision != 'approve') {
    final displayName = (client['display_name'] as String?)?.trim();
    final consentToken = _generateConsentToken();
    return authorizationConsentPage(
      context,
      clientDisplayName: displayName == null || displayName.isEmpty
          ? clientId
          : displayName,
      isOfficial: client['is_official'] == true,
      scopeLines: _scopeLines(requestedScopes),
      consentToken: consentToken,
      headers: {
        'set-cookie': buildOidcConsentCookie(
          consentToken,
          config: context.read<AppConfig>(),
        ),
      },
    );
  }

  if (!_isConsentRequestValid(context)) {
    return oidcErrorResponse(
      context,
      code: 'invalid_request',
      message: 'Consent confirmation required.',
      statusCode: 400,
      title: '您要登录的应用没有正确响应',
      description: '这次授权确认未通过安全校验，请返回授权页后重试。',
    );
  }

  final code = await oidc.authorize(
    clientId: clientId,
    redirectUri: redirectUri,
    responseType: responseType,
    scope: scope,
    user: user,
    nonce: nonce,
    codeChallenge: codeChallenge,
    codeChallengeMethod: codeChallengeMethod,
  );

  if (code == null) {
    return oidcErrorResponse(
      context,
      code: 'access_denied',
      message: 'Authorization request rejected.',
      statusCode: 400,
      title: '您要登录的应用没有正确响应',
      description: '这个应用发起的登录请求不完整或配置不正确，Rosemary Epass 无法安全地继续登录流程。',
    );
  }

  final callback = Uri.parse(redirectUri).replace(
    queryParameters: {
      ...Uri.parse(redirectUri).queryParameters,
      'code': code,
      if (state != null) 'state': state,
    },
  );

  return Response(
    statusCode: 302,
    headers: {
      'location': callback.toString(),
      'set-cookie': buildExpiredOidcConsentCookie(
        config: context.read<AppConfig>(),
      ),
    },
  );
}

String _webOidcContinuePath(Map<String, List<String>> queryParameters) {
  return Uri(
    path: '/oidc/continue',
    queryParameters: queryParameters,
  ).toString();
}

List<String> _scopeLines(Set<String> scopes) {
  final permissions = <String>[];
  if (scopes.contains('profile')) {
    permissions.add('基础资料（昵称）');
  }
  if (scopes.contains('email')) {
    permissions.add('电子邮箱');
  }
  if (scopes.contains('phone')) {
    permissions.add('电话号码');
  }
  if (scopes.contains('accountRule')) {
    permissions.add('账户角色');
  }
  return permissions;
}

@visibleForTesting
Response authorizationConsentPage(
  RequestContext context, {
  required String clientDisplayName,
  required bool isOfficial,
  required List<String> scopeLines,
  required String consentToken,
  Map<String, String> headers = const {},
}) {
  final requestUri = context.request.uri;
  final approveUrl = requestUri
      .replace(
        queryParameters: {
          ...requestUri.queryParameters,
          'decision': 'approve',
          'consent_token': consentToken,
        },
      )
      .toString();
  final cancelUrl = requestUri
      .replace(
        queryParameters: {
          ...requestUri.queryParameters,
          'decision': 'cancel',
          'consent_token': consentToken,
        },
      )
      .toString();
  final switchAccountUrl = requestUri
      .replace(
        queryParameters: {...requestUri.queryParameters, 'switch_account': '1'},
      )
      .toString();
  final accountCenterUrl = Uri.parse(
    context.read<AppConfig>().webBaseUrl,
  ).resolve('/account').toString();
  final brandLogoUrl = Uri.parse(
    context.read<AppConfig>().webBaseUrl,
  ).resolve('/brand/rosemary.png').toString();
  final escapedTitle = _escapeHtml('是否授权登录 $clientDisplayName？');
  final badgeLabel = isOfficial ? '官方应用' : '第三方应用';
  final escapedBadgeLabel = _escapeHtml(badgeLabel);
  final scopeListHtml = scopeLines
      .map((line) => '<li>${_escapeHtml(line)}</li>')
      .join();
  return Response(
    statusCode: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'content-security-policy':
          "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src 'self' https: data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
      ...headers,
    },
    body:
        '''
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Rosemary Epass</title>
    <script>
      (function() {
        try {
          document.documentElement.dataset.reduceMotion = String(window.localStorage.getItem('rosemary_motion') === 'reduce');
          var stored = window.localStorage.getItem('rosm_theme_preference');
          var preference = stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system';
          var systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
          var resolved = preference === 'system' ? systemTheme : preference;
          document.documentElement.dataset.theme = resolved;
          document.documentElement.style.colorScheme = resolved;
        } catch (_) {}
      })();
    </script>
    <style>$epassDocumentStyles</style>
  </head>
  <body>
    <div class="shell">
      <section class="brand-side">
        <div class="brand-wrap">
          <div class="brand-copy">
            <p class="eyebrow">Rosemary Epass 授权确认</p>
            <h2>你的账户，<br />由你决定如何连接。</h2>
            <p>查看应用申请的信息，确认后继续登录。</p>
          </div>
          <div class="brand-foot">ROSEMARY EPASS</div>
        </div>
      </section>
      <main class="main">
        <div class="panel-stack">
          <section class="panel">
            <div class="panel-top">
              ${epassBrandMarkup(brandLogoUrl, compact: true)}
              <a class="switch-account" href="${_escapeHtml(switchAccountUrl)}">切换账号</a>
            </div>
          <div class="trust-badge">
            <span class="trust-icon${isOfficial ? '' : ' hidden'}">
              <svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path d="M13.2 4.4L6.6 11L2.8 7.2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </span>
            $escapedBadgeLabel
          </div>
          <h1>$escapedTitle</h1>
          ${scopeLines.isEmpty ? '<p class="subtitle">该应用将使用 Rosemary Epass 验证你的登录状态。</p>' : '<p class="permission-head">此应用将获得以下信息：</p><ul class="permission-list">$scopeListHtml</ul>'}
          <div class="actions">
            <a class="button secondary" href="${_escapeHtml(cancelUrl)}">取消</a>
            <a id="approve-button" class="button primary" href="${_escapeHtml(approveUrl)}">$epassLoadingMarkup<span id="approve-label">确认</span></a>
          </div>
          </section>
          <a class="account-center" href="${_escapeHtml(accountCenterUrl)}">Rosemary Epass 账号中心 <span aria-hidden="true">→</span></a>
        </div>
      </main>
    </div>
    <script>
      (function() {
        var approveButton = document.getElementById('approve-button');
        if (!approveButton) return;

        var loader = document.getElementById('approve-loader');
        var label = document.getElementById('approve-label');
        var loadingTimer;
        function pauseApprovalLoading() {
          clearTimeout(loadingTimer);
          loader.dataset.active = 'false';
          loader.dataset.visible = 'false';
        }
        function resetApprovalState() {
          pauseApprovalLoading();
          approveButton.removeAttribute('aria-busy');
          approveButton.removeAttribute('aria-disabled');
          approveButton.removeAttribute('data-submitting');
          label.textContent = '确认';
        }

        approveButton.addEventListener('click', function(event) {
          if (approveButton.dataset.submitting === 'true') {
            event.preventDefault();
            return;
          }
          approveButton.dataset.submitting = 'true';
          approveButton.setAttribute('aria-disabled', 'true');
          approveButton.setAttribute('aria-busy', 'true');
          label.textContent = '授权处理中…';
          loadingTimer = setTimeout(function() {
            loader.dataset.visible = 'true';
            loader.dataset.active = String(!document.hidden);
          }, 300);
        });
        window.addEventListener('pageshow', resetApprovalState);
        window.addEventListener('pagehide', pauseApprovalLoading);
        document.addEventListener('visibilitychange', function() {
          loader.dataset.active = String(!document.hidden && loader.dataset.visible === 'true');
        });
      })();
    </script>
  </body>
</html>
''',
  );
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

bool _isConsentRequestValid(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return false;
  }
  final queryToken = context.request.uri.queryParameters['consent_token'] ?? '';
  if (queryToken.isEmpty) {
    return false;
  }
  final cookieToken = readCookieValue(
    context.request.headers['cookie'],
    'rosm_oidc_consent',
  );
  return cookieToken != null &&
      cookieToken.isNotEmpty &&
      _timingSafeEquals(cookieToken, queryToken);
}

String _generateConsentToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

bool _timingSafeEquals(String left, String right) {
  if (left.length != right.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < left.length; i++) {
    diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
  }
  return diff == 0;
}
