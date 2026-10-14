import 'dart:convert';
import 'epass_design.dart';

import 'package:dart_frog/dart_frog.dart';

import '../config/app_config.dart';
import 'http.dart';

Response oidcErrorResponse(
  RequestContext context, {
  required String code,
  required String message,
  required int statusCode,
  String title = '您要登录的应用没有正确响应',
  String? description,
}) {
  if (!_wantsHtml(context.request)) {
    return errorResponse(code, message, statusCode: statusCode);
  }

  return _authorizationErrorPage(
    context,
    title: title,
    description: description ?? message,
    statusCode: statusCode,
  );
}

bool _wantsHtml(Request request) {
  final accept = request.headers['accept']?.toLowerCase() ?? '';
  final fetchDest = request.headers['sec-fetch-dest']?.toLowerCase() ?? '';
  final fetchMode = request.headers['sec-fetch-mode']?.toLowerCase() ?? '';
  return accept.contains('text/html') ||
      fetchDest == 'document' ||
      fetchMode == 'navigate';
}

Response _authorizationErrorPage(
  RequestContext context, {
  required String title,
  required String description,
  required int statusCode,
}) {
  final homeUrl = Uri.parse(
    context.read<AppConfig>().webBaseUrl,
  ).resolve('/').toString();
  final brandLogoUrl = const HtmlEscape().convert(
    Uri.parse(
      context.read<AppConfig>().webBaseUrl,
    ).resolve('/brand/rosemary.png').toString(),
  );
  return Response(
    statusCode: statusCode,
    headers: const {
      'content-type': 'text/html; charset=utf-8',
      'content-security-policy':
          "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src 'self' https: data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
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
          var preference = stored === 'light' || stored === 'dark' || stored === 'system'
            ? stored
            : 'system';
          var systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches
            ? 'dark'
            : 'light';
          var resolved = preference === 'system' ? systemTheme : preference;
          document.documentElement.dataset.theme = resolved;
          document.documentElement.dataset.themePreference = preference;
          document.documentElement.style.colorScheme = resolved;
        } catch (_) {}
      })();
    </script>
    <style>$epassDocumentStyles</style>
  </head>
  <body class="epass-error">
    <div class="shell">
      <section class="brand">
        <div class="brand-content">
          ${epassBrandMarkup(brandLogoUrl)}
          <div class="brand-copy">
            <h1>登录暂时无法继续</h1>
            <p>Rosemary Epass 已拦下这次授权请求，避免在应用配置异常时把您带入不安全或不完整的登录流程。</p>
          </div>
          <div class="brand-foot">ROSEMARY EPASS</div>
        </div>
      </section>
      <main class="main">
        <section class="card">
          <p class="eyebrow">OIDC 授权提示</p>
          <div class="badge">
            <span class="badge-dot"></span>
            Rosemary Epass 安全拦截
          </div>
          <h2>$title</h2>
          <p>$description</p>
          <div class="actions">
            <a class="button" href="$homeUrl">返回 Rosemary Epass 主页</a>
          </div>
        </section>
      </main>
    </div>
  </body>
</html>
''',
  );
}
