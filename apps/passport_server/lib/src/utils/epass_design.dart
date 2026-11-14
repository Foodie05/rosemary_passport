import 'epass_tokens.dart';
import 'epass_brand.dart';
import 'epass_loading.dart';

/// Shared by consent and error documents; no dependency on the React bundle.
const epassDocumentStyles =
    '''
$epassTokens
$epassLoadingStyles
* { box-sizing: border-box; }
html { color-scheme: light; }
html[data-theme='dark'] { color-scheme: dark; }
body { --document-gutter:clamp(16px,4vw,48px); --document-inset:clamp(24px,4vw,56px); margin:0; min-width:0; min-height:100dvh; display:flex; flex-direction:column; background:var(--r-semantic-color-canvas); color:var(--r-semantic-color-text); font:16px/1.75 var(--r-semantic-font-body); }
a { color:inherit; }
:focus-visible { outline:2px solid var(--r-semantic-color-focus); outline-offset:4px; }
.document-tools,.shell,.document-footer { width:calc(100% - var(--document-gutter) * 2); max-width:1480px; margin-inline:auto; }
.document-tools { display:flex; align-items:center; justify-content:space-between; gap:16px; padding:24px 0 0 var(--document-inset); }
.document-home { display:inline-flex; text-decoration:none; }
.document-tools .epass-lockup { gap:11px; }
.document-tools .epass-lockup > img { width:44px; height:44px; }
.document-tools .epass-lockup > span > span { font-size:13.2px; }
.document-tools .epass-lockup strong { font-size:24.64px; }
.theme-toggle { display:inline-flex; align-items:center; justify-content:center; flex:none; width:44px; height:44px; border:0; border-radius:8px; color:var(--r-semantic-color-ink); background:var(--r-semantic-color-field-fill); cursor:pointer; }
.theme-toggle:hover { background:var(--r-semantic-color-surface-subtle); }
.theme-toggle svg { width:24px; height:24px; }
.theme-sun,html[data-theme='dark'] .theme-moon { display:none; }
html[data-theme='dark'] .theme-sun { display:block; }
.document-skip { position:fixed; top:8px; left:16px; z-index:10; transform:translateY(-150%); padding:12px; background:var(--r-semantic-color-surface-group); }
.document-skip:focus { transform:none; }
.shell { display:grid; flex:1; grid-template-columns:minmax(0,1.05fr) minmax(0,1fr); margin-block:24px; }
.brand-side,.epass-error .brand { padding:var(--document-inset); display:flex; flex-direction:column; justify-content:center; min-width:0; }
.brand-wrap,.brand-content { display:flex; flex-direction:column; align-items:flex-start; gap:48px; }
.brand-copy :is(h1,h2) { font:400 clamp(32px,3.4vw,56px)/1.25 var(--r-semantic-font-editorial); letter-spacing:-.045em; margin:0; text-wrap:balance; }
.brand-emblem svg { display:block; width:160px; height:160px; }
.main { display:flex; align-items:center; justify-content:center; min-width:0; }
.panel,.card { width:100%; padding:var(--document-inset); border-radius:20px; background:var(--r-semantic-color-surface-group); }
.panel-top { display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:12px; margin-bottom:24px; }
.panel h1,.card h2 { font:500 40px/1.3 var(--r-semantic-font-body); text-wrap:balance; margin:0 0 24px; overflow-wrap:anywhere; }
.subtitle,.card > p { color:var(--r-semantic-color-text-secondary); }
.switch-account { color:var(--r-semantic-color-primary); font-size:14px; text-decoration:none; padding:8px 0; }
.switch-account:hover,.account-center:hover { text-decoration:underline; text-underline-offset:4px; }
.trust-badge,.badge { display:inline-flex; gap:8px; align-items:center; padding:4px 8px; border-radius:4px; background:var(--r-semantic-color-accent-subtle); color:var(--r-semantic-color-accent); font-size:12px; }
.epass-error .badge { background:var(--r-semantic-color-warning-subtle); color:var(--r-semantic-color-warning); margin-bottom:24px; }
.trust-icon { display:inline-flex; align-items:center; justify-content:center; width:16px; height:16px; flex:0 0 16px; }
.trust-icon svg { display:block; width:16px; height:16px; flex:none; }
.hidden { display:none; }
.permission-head { font-size:14px; color:var(--r-semantic-color-text-secondary); margin:0 0 12px; }
.permission-list { list-style:none; padding:8px; margin:0 0 24px; border-radius:12px; background:var(--r-semantic-color-surface-inset); }
.permission-list li { padding:12px; display:flex; align-items:center; gap:12px; overflow-wrap:anywhere; }
.permission-list svg { width:20px; height:20px; flex-shrink:0; }
.actions { display:flex; justify-content:flex-end; flex-wrap:wrap; gap:12px; margin-top:24px; }
.button { display:inline-flex; align-items:center; justify-content:center; gap:8px; min-height:40px; border:0; border-radius:8px; padding:10px 15px; font-size:13px; line-height:1.4; font-weight:500; text-decoration:none; background:var(--r-semantic-color-accent); color:var(--r-semantic-color-on-accent); transition:background-color var(--r-semantic-motion-hover) var(--r-semantic-motion-standard); }
.button:hover { background:var(--r-semantic-color-accent-hover); }
.button.secondary { background:var(--r-semantic-color-field-fill); color:var(--r-semantic-color-ink); }
.button.secondary:hover { background:var(--r-semantic-color-surface-subtle); }
.button[aria-disabled='true'] { opacity:.6; cursor:wait; }
.account-center { display:block; width:fit-content; margin:24px 0 0 auto; font-size:14px; color:var(--r-semantic-color-text-secondary); text-decoration:none; }
.document-footer { display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:16px; padding:0 var(--document-inset) 24px; color:var(--r-semantic-color-text-secondary); font-size:12px; }
.document-footer nav { display:flex; justify-content:flex-end; flex-wrap:wrap; gap:16px; margin-inline-start:auto; }
.document-footer a { text-decoration:none; }
.document-footer a:hover { text-decoration:underline; text-underline-offset:4px; }
@media(max-width:1023px) { .shell { grid-template-columns:minmax(0,1fr); } .brand-side,.epass-error .brand { display:none; } }
@media(max-width:640px) { .panel h1,.card h2 { font-size:32px; } }
.epass-lockup { display: inline-flex; gap: 16px; align-items: center; direction: ltr; }
.epass-lockup > img { width: 64px; height: 64px; object-fit: contain; }
.epass-lockup > span { display: flex; flex-direction: column; gap: 2.56px; font-family: var(--r-semantic-font-editorial); }
.epass-lockup > span > span { font-size: 19.2px; font-weight: 400; line-height: 1.15; }
.epass-lockup strong { font-size: 35.84px; font-weight: 500; line-height: 1.05; }
.epass-compact-brand { display: inline-flex; align-items: center; gap: 9px; color: var(--r-semantic-color-primary); font: 500 20px/1.05 var(--r-semantic-font-editorial); }
@media (max-width: 600px), (pointer: coarse) { .button { min-height:44px; } }
html[data-theme='dark'] .button:not(.secondary) { background-clip:padding-box; }
@media (forced-colors: active) { .epass-lockup img { forced-color-adjust: none; } }
html[data-reduce-motion='true'] * { animation: none !important; transition: none !important; }
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; } }
''';

const epassConsentEmblem = epassBadgeMarkup;

/// Product-approved mark, independent of the JS bundle.
String epassBrandMarkup(String logoUrl, {bool compact = false}) => compact
    ? '''<span class="epass-compact-brand" role="img" aria-label="Epass">$epassBadgeMarkup<span aria-hidden="true">Epass</span></span>'''
    : '''<span class="epass-lockup" role="img" aria-label="Rosemary Epass"><img src="$logoUrl" alt="" width="64" height="64"/><span aria-hidden="true"><span>Rosemary</span><strong>Epass</strong></span></span>''';

/// Aligned unframed utilities, shared with standalone consent/error pages.
String epassDocumentTools(String logoUrl, String homeUrl) =>
    '''
<a class="document-skip" href="#auth-main">跳到主要内容</a>
<div class="document-tools">
  <a class="document-home" href="$homeUrl" aria-label="Rosemary Epass 首页">${epassBrandMarkup(logoUrl)}</a>
  <button type="button" id="theme-toggle" class="theme-toggle" aria-label="切换明暗主题">
    <svg class="theme-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20.9 13A9 9 0 0 1 11 3.1 9 9 0 1 0 20.9 13Z"/></svg>
    <svg class="theme-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.4 1.4m11.2 11.2L19 19M5 19l1.4-1.4M17.6 6.4 19 5"/></svg>
  </button>
</div>''';

String epassDocumentFooter(String webBaseUrl) => '''
<footer class="document-footer"><span>© ${DateTime.now().year} Rosemary Epass</span><nav aria-label="法律与文档"><a href="$webBaseUrl/legal/terms">使用条款</a><a href="$webBaseUrl/legal/privacy">隐私政策</a><a href="$webBaseUrl/docs">接入文档</a></nav></footer>''';

const epassDocumentThemeScript = r'''
(function() {
  var button = document.getElementById('theme-toggle');
  var root = document.documentElement;
  var media = window.matchMedia('(prefers-color-scheme: dark)');
  var preference = 'system';
  try { preference = window.localStorage.getItem('rosm_theme_preference') || 'system'; } catch (_) {}
  function apply() {
    var dark = preference === 'dark' || (preference !== 'light' && preference !== 'dark' && media.matches);
    root.dataset.theme = dark ? 'dark' : 'light';
    root.style.colorScheme = dark ? 'dark' : 'light';
    button.setAttribute('aria-label', dark ? '切换到浅色主题' : '切换到深色主题');
  }
  button.addEventListener('click', function() {
    preference = root.dataset.theme === 'dark' ? 'light' : 'dark';
    try { window.localStorage.setItem('rosm_theme_preference', preference); } catch (_) {}
    apply();
  });
  media.addEventListener('change', apply);
  apply();
})();
''';
