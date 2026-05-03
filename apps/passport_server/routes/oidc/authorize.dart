import 'package:dart_frog/dart_frog.dart';
import 'dart:convert';
import 'dart:math';

import '../../lib/src/config/app_config.dart';
import '../../lib/src/middleware/guards.dart';
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
      description: '这个应用发起了不受支持的授权请求方式，ROSM 无法继续处理。',
    );
  }

  final user = await currentUser(context);
  if (user == null) {
    final config = context.read<AppConfig>();
    final authorizeUrl = Uri.parse(
      config.serverBaseUrl,
    ).resolveUri(context.request.uri).toString();
    final loginUrl = Uri.parse(
      config.webBaseUrl,
    ).resolve('/login').replace(queryParameters: {'next': authorizeUrl});
    return Response(
      statusCode: 302,
      headers: {'location': loginUrl.toString()},
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
      description: '当前登录请求缺少必要参数，ROSM 无法继续完成授权。',
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
      description: '这个应用尚未在 ROSM 中正确配置，登录流程无法继续。',
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
      description: '这个应用发起的登录请求不完整或配置不正确，ROSM 无法安全地继续登录流程。',
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
    return _authorizationConsentPage(
      context,
      clientDisplayName: displayName == null || displayName.isEmpty
          ? clientId
          : displayName,
      isOfficial: client['is_official'] == true,
      subtitle: _scopeSubtitle(requestedScopes),
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
      description: '这个应用发起的登录请求不完整或配置不正确，ROSM 无法安全地继续登录流程。',
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

String _scopeSubtitle(Set<String> scopes) {
  final permissions = <String>[];
  if (scopes.contains('profile')) {
    permissions.add('昵称');
  }
  if (scopes.contains('email')) {
    permissions.add('邮箱');
  }
  if (permissions.isEmpty) {
    return '该应用将使用 ROSM 验证您的登录状态。';
  }
  if (permissions.length == 1) {
    return '该应用将获得你的${permissions.first}。';
  }
  return '该应用将获得你的${permissions.join('和')}。';
}

Response _authorizationConsentPage(
  RequestContext context, {
  required String clientDisplayName,
  required bool isOfficial,
  required String subtitle,
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
  final escapedTitle = _escapeHtml('是否授权登录 $clientDisplayName?');
  final escapedSubtitle = _escapeHtml(subtitle);
  final badgeLabel = isOfficial ? '官方应用' : '第三方应用';
  final escapedBadgeLabel = _escapeHtml(badgeLabel);
  return Response(
    statusCode: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'content-security-policy':
          "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src https: data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
      ...headers,
    },
    body:
        '''
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>ROSM Pass</title>
    <script>
      (function() {
        try {
          var stored = window.localStorage.getItem('rosm_theme_preference');
          var preference = stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system';
          var systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
          var resolved = preference === 'system' ? systemTheme : preference;
          document.documentElement.dataset.theme = resolved;
          document.documentElement.style.colorScheme = resolved;
        } catch (_) {}
      })();
    </script>
    <style>
      :root {
        --sage-50: #f4f7f4;
        --sage-100: #e2e9e2;
        --sage-200: #c5d3c5;
        --sage-400: #8ba88b;
        --sage-500: #6e926e;
        --sage-600: #577557;
        --sage-700: #415841;
        --sage-900: #161d16;
        --page-bg:
          radial-gradient(circle at top right, rgba(87, 117, 87, 0.16), transparent 26rem),
          radial-gradient(circle at bottom left, rgba(139, 168, 139, 0.18), transparent 24rem),
          var(--sage-50);
        --card-bg: rgba(255,255,255,0.84);
        --card-border: rgba(197,211,197,0.8);
        --text-main: var(--sage-900);
        --text-subtle: rgba(22,29,22,0.68);
        --muted: var(--sage-500);
      }
      html[data-theme='dark'] {
        --page-bg:
          radial-gradient(circle at top right, rgba(110, 146, 110, 0.15), transparent 24rem),
          radial-gradient(circle at bottom left, rgba(65, 88, 65, 0.26), transparent 24rem),
          #0f140f;
        --card-bg: rgba(22,29,22,0.84);
        --card-border: rgba(65,88,65,0.8);
        --text-main: #f4f7f4;
        --text-subtle: rgba(226,233,226,0.72);
        --muted: #8ba88b;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        font-family: "SF Pro Display","PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif;
        background: var(--page-bg);
        color: var(--text-main);
      }
      .shell {
        min-height: 100vh;
        display: grid;
        grid-template-columns: minmax(22rem, 34rem) minmax(24rem, 1fr);
      }
      .brand-side {
        position: relative;
        overflow: hidden;
        padding: 3rem;
        background: linear-gradient(180deg, #1a241a 0%, #101710 100%);
        color: white;
      }
      html[data-theme='dark'] .brand-side {
        background: linear-gradient(180deg, #182218 0%, #0d130d 100%);
      }
      .brand-side::before,
      .brand-side::after {
        content: "";
        position: absolute;
        border-radius: 999px;
        filter: blur(90px);
      }
      .brand-side::before {
        width: 20rem;
        height: 20rem;
        right: -7rem;
        top: -7rem;
        background: rgba(110, 146, 110, 0.22);
      }
      .brand-side::after {
        width: 16rem;
        height: 16rem;
        left: -5rem;
        bottom: -5rem;
        background: rgba(87, 117, 87, 0.2);
      }
      .brand-wrap {
        position: relative;
        z-index: 1;
        display: flex;
        min-height: calc(100vh - 6rem);
        flex-direction: column;
        justify-content: space-between;
      }
      .brand-copy h1 {
        margin: 0 0 1rem;
        font-size: clamp(2.2rem, 4vw, 4rem);
        line-height: 1.06;
        letter-spacing: -0.04em;
      }
      .brand-copy p {
        margin: 0;
        max-width: 26rem;
        color: rgba(255,255,255,0.74);
        line-height: 1.9;
        font-size: 1.04rem;
      }
      .brand-foot {
        font-size: 0.78rem;
        letter-spacing: 0.24em;
        text-transform: uppercase;
        color: rgba(255,255,255,0.36);
      }
      .main {
        display: grid;
        place-items: center;
        padding: 2rem;
      }
      .panel {
        width: min(100%, 40rem);
        border: 1px solid var(--card-border);
        border-radius: 2rem;
        background: var(--card-bg);
        backdrop-filter: blur(16px);
        box-shadow: 0 24px 60px rgba(22,29,22,0.12);
        padding: 2rem;
      }
      .brand {
        display: flex;
        align-items: center;
        gap: 0.9rem;
        margin-bottom: 1.5rem;
      }
      .logo {
        display: grid;
        place-items: center;
        width: 3rem;
        height: 3rem;
        border-radius: 1rem;
        background: white;
        box-shadow: 0 16px 32px rgba(22,29,22,0.12);
      }
      .logo img { width: 1.9rem; height: 1.9rem; object-fit: contain; }
      .eyebrow {
        margin: 0 0 0.4rem;
        font-size: 0.78rem;
        letter-spacing: 0.18em;
        text-transform: uppercase;
        color: var(--muted);
        font-weight: 700;
      }
      .trust-badge {
        display: inline-flex;
        align-items: center;
        gap: 0.55rem;
        margin-bottom: 1rem;
        border-radius: 999px;
        padding: 0.5rem 0.85rem;
        font-size: 0.82rem;
        font-weight: 700;
        letter-spacing: 0.01em;
        background: rgba(139,168,139,0.12);
        color: var(--text-main);
      }
      .trust-icon {
        display: inline-flex;
        width: 1rem;
        height: 1rem;
      }
      .trust-icon svg {
        width: 1rem;
        height: 1rem;
        display: block;
      }
      .trust-icon.hidden {
        display: none;
      }
      h1 {
        margin: 0;
        font-size: clamp(2rem, 4vw, 2.8rem);
        line-height: 1.16;
        letter-spacing: -0.03em;
      }
      .subtitle {
        margin: 1rem 0 0;
        color: var(--text-subtle);
        font-size: 1.02rem;
        line-height: 1.8;
      }
      .actions {
        display: flex;
        gap: 0.9rem;
        margin-top: 1.8rem;
      }
      .button {
        flex: 1;
        min-height: 3.2rem;
        border-radius: 1rem;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        text-decoration: none;
        font-weight: 700;
        transition: transform 160ms ease, background 160ms ease, border-color 160ms ease;
      }
      .button:hover { transform: translateY(-1px); }
      .primary {
        background: var(--sage-600);
        color: white;
        box-shadow: 0 16px 30px rgba(87,117,87,0.22);
      }
      .primary:hover { background: var(--sage-700); }
      .secondary {
        border: 1px solid var(--card-border);
        background: transparent;
        color: var(--text-main);
      }
      @media (max-width: 720px) {
        .shell {
          grid-template-columns: 1fr;
        }
        .brand-side {
          padding: 2rem 1.5rem;
        }
        .brand-wrap {
          min-height: auto;
          gap: 3rem;
        }
        .main {
          padding: 1rem;
          margin-top: -1rem;
        }
        .panel { padding: 1.4rem; }
        .actions { flex-direction: column; }
      }
    </style>
  </head>
  <body>
    <div class="shell">
      <section class="brand-side">
        <div class="brand-wrap">
          <div class="brand-copy">
            <p class="eyebrow">ROSM 授权确认</p>
            <h1>确认应用访问范围后，再继续登录</h1>
            <p>ROSM 会在这里明确展示应用身份与它将获得的信息，帮助你在继续前做出清楚判断。</p>
          </div>
          <div class="brand-foot">ROSEMARY STUDIO</div>
        </div>
      </section>
      <main class="main">
        <section class="panel">
          <div class="brand">
            <div class="logo">
              <img src="https://tianyue.s3.bitiful.net/logo/rosemary_pure.png" alt="ROSM" />
            </div>
            <div>
              <p class="eyebrow">ROSM 授权确认</p>
              <strong>ROSM Pass</strong>
            </div>
          </div>
          <div class="trust-badge">
            <span class="trust-icon${isOfficial ? '' : ' hidden'}">
              <svg viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path d="M13.2 4.4L6.6 11L2.8 7.2" stroke="#6e926e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </span>
            $escapedBadgeLabel
          </div>
          <h1>$escapedTitle</h1>
          <p class="subtitle">$escapedSubtitle</p>
          <div class="actions">
            <a class="button secondary" href="$cancelUrl">取消</a>
            <a class="button primary" href="$approveUrl">确认</a>
          </div>
        </section>
      </main>
    </div>
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
