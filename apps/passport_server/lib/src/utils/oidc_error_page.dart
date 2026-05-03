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
  return Response(
    statusCode: statusCode,
    headers: const {
      'content-type': 'text/html; charset=utf-8',
      'content-security-policy':
          "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src https: data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
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
    <style>
      :root {
        --sage-50: #f4f7f4;
        --sage-100: #e2e9e2;
        --sage-200: #c5d3c5;
        --sage-400: #8ba88b;
        --sage-500: #6e926e;
        --sage-600: #577557;
        --sage-900: #161d16;
        --page-bg:
          radial-gradient(circle at top right, rgba(87, 117, 87, 0.16), transparent 26rem),
          radial-gradient(circle at bottom left, rgba(139, 168, 139, 0.18), transparent 24rem),
          var(--sage-50);
        --card-bg: rgba(255, 255, 255, 0.82);
        --card-border: rgba(197, 211, 197, 0.8);
        --card-shadow: 0 24px 60px rgba(22, 29, 22, 0.08);
        --text-main: var(--sage-900);
        --text-subtle: rgba(22, 29, 22, 0.64);
        --brand-bg: linear-gradient(180deg, #1f2a1f 0%, #161d16 100%);
        --brand-copy: rgba(255, 255, 255, 0.72);
        --brand-foot: rgba(255, 255, 255, 0.36);
        --badge-bg: var(--sage-50);
        --badge-text: var(--sage-600);
        --button-bg: var(--sage-600);
        --button-hover: #415841;
      }
      html[data-theme='dark'] {
        --page-bg:
          radial-gradient(circle at top right, rgba(110, 146, 110, 0.15), transparent 24rem),
          radial-gradient(circle at bottom left, rgba(65, 88, 65, 0.26), transparent 24rem),
          #0f140f;
        --card-bg: rgba(22, 29, 22, 0.82);
        --card-border: rgba(65, 88, 65, 0.8);
        --card-shadow: 0 24px 60px rgba(0, 0, 0, 0.28);
        --text-main: #f4f7f4;
        --text-subtle: rgba(226, 233, 226, 0.72);
        --brand-bg: linear-gradient(180deg, #263326 0%, #171f17 100%);
        --brand-copy: rgba(255, 255, 255, 0.78);
        --brand-foot: rgba(255, 255, 255, 0.42);
        --badge-bg: rgba(87, 117, 87, 0.18);
        --badge-text: #c5d3c5;
        --button-bg: #6e926e;
        --button-hover: #8ba88b;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        font-family: "SF Pro Display", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
        background: var(--page-bg);
        color: var(--text-main);
      }
      .shell {
        min-height: 100vh;
        display: grid;
        grid-template-columns: minmax(22rem, 34rem) minmax(22rem, 1fr);
      }
      .brand {
        position: relative;
        overflow: hidden;
        padding: 3rem;
        background: var(--brand-bg);
        color: white;
      }
      .brand::before,
      .brand::after {
        content: "";
        position: absolute;
        border-radius: 999px;
        filter: blur(90px);
      }
      .brand::before {
        width: 22rem;
        height: 22rem;
        right: -8rem;
        top: -8rem;
        background: rgba(87, 117, 87, 0.28);
      }
      .brand::after {
        width: 18rem;
        height: 18rem;
        left: -6rem;
        bottom: -6rem;
        background: rgba(139, 168, 139, 0.18);
      }
      .brand-content {
        position: relative;
        z-index: 1;
        display: flex;
        min-height: calc(100vh - 6rem);
        flex-direction: column;
        justify-content: space-between;
      }
      .brand-head {
        display: flex;
        align-items: center;
        gap: 0.9rem;
      }
      .brand-logo {
        display: grid;
        height: 3.1rem;
        width: 3.1rem;
        place-items: center;
        border-radius: 1rem;
        background: white;
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.22);
      }
      .brand-logo img {
        width: 2rem;
        height: 2rem;
        object-fit: contain;
      }
      .brand-name {
        font-size: 1.6rem;
        font-weight: 700;
        letter-spacing: -0.02em;
      }
      .brand-copy h1 {
        margin: 0 0 1rem;
        max-width: none;
        font-size: clamp(2rem, 3.3vw, 3.9rem);
        line-height: 1.08;
        white-space: nowrap;
        letter-spacing: -0.03em;
      }
      .brand-copy p {
        margin: 0;
        max-width: 24rem;
        color: var(--brand-copy);
        font-size: 1.02rem;
        line-height: 1.8;
      }
      .brand-foot {
        font-size: 0.78rem;
        letter-spacing: 0.24em;
        text-transform: uppercase;
        color: var(--brand-foot);
      }
      .main {
        display: grid;
        place-items: center;
        padding: 2rem;
      }
      .card {
        width: min(100%, 34rem);
        border: 1px solid var(--card-border);
        border-radius: 2rem;
        background: var(--card-bg);
        backdrop-filter: blur(16px);
        box-shadow: var(--card-shadow);
        padding: 2rem;
      }
      .eyebrow {
        margin: 0 0 0.85rem;
        color: var(--sage-500);
        font-size: 0.76rem;
        font-weight: 700;
        letter-spacing: 0.18em;
        text-transform: uppercase;
      }
      html[data-theme='dark'] .eyebrow {
        color: #8ba88b;
      }
      .badge {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        border-radius: 999px;
        background: var(--badge-bg);
        color: var(--badge-text);
        padding: 0.45rem 0.8rem;
        font-size: 0.82rem;
        font-weight: 700;
      }
      .badge-dot {
        width: 0.55rem;
        height: 0.55rem;
        border-radius: 999px;
        background: var(--sage-400);
      }
      .card h2 {
        margin: 1.1rem 0 0.8rem;
        font-size: 2rem;
        line-height: 1.18;
      }
      .card p {
        margin: 0;
        color: var(--text-subtle);
        line-height: 1.8;
        font-size: 1rem;
      }
      .actions {
        margin-top: 1.7rem;
        display: flex;
      }
      .button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 3.2rem;
        padding: 0 1.3rem;
        border-radius: 1rem;
        background: var(--button-bg);
        color: white;
        text-decoration: none;
        font-weight: 700;
        box-shadow: 0 16px 30px rgba(87, 117, 87, 0.22);
        transition: background 160ms ease, transform 160ms ease, box-shadow 160ms ease;
      }
      .button:hover {
        background: var(--button-hover);
        transform: translateY(-1px);
        box-shadow: 0 18px 34px rgba(65, 88, 65, 0.24);
      }
      @media (max-width: 920px) {
        .shell {
          grid-template-columns: 1fr;
        }
        .brand {
          padding: 2rem 1.5rem;
        }
        .brand-content {
          min-height: auto;
          gap: 3rem;
        }
        .brand-copy h1 {
          white-space: normal;
          max-width: 8em;
        }
        .main {
          padding: 1.5rem;
          margin-top: -1rem;
        }
      }
    </style>
  </head>
  <body>
    <div class="shell">
      <section class="brand">
        <div class="brand-content">
          <div class="brand-head">
            <div class="brand-logo">
              <img src="https://tianyue.s3.bitiful.net/logo/rosemary_pure.png" alt="ROSM" />
            </div>
            <div class="brand-name">ROSM Pass</div>
          </div>
          <div class="brand-copy">
            <h1>登录暂时无法继续</h1>
            <p>ROSM 已拦下这次授权请求，避免在应用配置异常时把您带入不安全或不完整的登录流程。</p>
          </div>
          <div class="brand-foot">ROSEMARY STUDIO</div>
        </div>
      </section>
      <main class="main">
        <section class="card">
          <p class="eyebrow">OIDC 授权提示</p>
          <div class="badge">
            <span class="badge-dot"></span>
            ROSM 安全拦截
          </div>
          <h2>$title</h2>
          <p>$description</p>
          <div class="actions">
            <a class="button" href="$homeUrl">返回 ROSM 主页</a>
          </div>
        </section>
      </main>
    </div>
  </body>
</html>
''',
  );
}
