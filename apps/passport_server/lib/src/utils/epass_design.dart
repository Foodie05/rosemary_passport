import 'epass_tokens.dart';

/// Shared by consent and error documents; no dependency on the React bundle.
const epassDocumentStyles =
    '''
$epassTokens
* { box-sizing: border-box; }
html { color-scheme: light; }
html[data-theme='dark'] { color-scheme: dark; }
body { margin: 0; min-width: 0; background: var(--r-semantic-color-canvas); color: var(--r-semantic-color-text); font: 16px/1.7 var(--r-semantic-font-body); }
a { color: inherit; }
:focus-visible { outline: 2px solid var(--r-semantic-color-focus); outline-offset: 4px; }
.shell { display: grid; grid-template-columns: minmax(0, 1.05fr) minmax(0, 1fr); min-height: 100dvh; }
.brand-side, .epass-error .brand { padding: clamp(32px, 5vw, 80px); border-right: 1px solid var(--r-semantic-color-border); display: flex; flex-direction: column; justify-content: center; }
.brand-wrap, .brand-content { display: flex; flex-direction: column; gap: 64px; }
.brand-copy :is(h1, h2) { font: 400 clamp(36px, 4vw, 60px)/1.3 var(--r-semantic-font-editorial); letter-spacing: -.04em; margin: 24px 0; text-wrap: balance; }
.brand-copy p { color: var(--r-semantic-color-text-secondary); max-width: 30em; }
.brand-foot, .eyebrow { font: 12px/1.6 var(--r-semantic-font-code); letter-spacing: .08em; color: var(--r-semantic-color-text-secondary); }
.brand-head, .panel-top, .brand { display: flex; align-items: center; gap: 16px; }
.panel-top { justify-content: space-between; flex-wrap: wrap; padding-bottom: 24px; border-bottom: 1px solid var(--r-semantic-color-border); margin-bottom: 32px; }
.logo, .brand-logo { padding: 8px; display: flex; }
.logo img, .brand-logo img { width: 32px; height: 32px; object-fit: contain; }
.brand-name, .brand strong { font: 400 24px/1.3 var(--r-semantic-font-editorial); }
.main { display: flex; align-items: center; justify-content: center; padding: 48px; background: var(--r-semantic-color-surface); min-width: 0; }
.panel-stack { width: 100%; max-width: 480px; }
.panel, .card { width: 100%; max-width: 480px; }
.panel h1, .card h2 { font: 400 32px/1.4 var(--r-semantic-font-editorial); text-wrap: balance; margin: 24px 0 16px; overflow-wrap: anywhere; }
.subtitle, .card > p { color: var(--r-semantic-color-text-secondary); }
.switch-account { font-size: 14px; text-underline-offset: 4px; padding: 8px; }
.trust-badge, .badge { display: inline-flex; gap: 8px; align-items: center; padding: 4px 8px; border-radius: 4px; background: var(--r-semantic-color-accent-subtle); color: var(--r-semantic-color-accent); font-size: 12px; }
.epass-error .badge { background: var(--r-semantic-color-warning-subtle); color: var(--r-semantic-color-warning); }
.trust-icon { display: flex; width: 16px; }
.trust-icon path { stroke: currentColor; }
.hidden { display: none; }
.permission-head { font-size: 14px; color: var(--r-semantic-color-text-secondary); }
.permission-list { list-style: none; padding: 0; margin: 16px 0 32px; border-top: 1px solid var(--r-semantic-color-border); }
.permission-list li { padding: 16px 0; border-bottom: 1px solid var(--r-semantic-color-border); display: flex; align-items: center; gap: 12px; }
.permission-list svg { width: 20px; height: 20px; flex-shrink: 0; }
.actions { display: flex; justify-content: flex-end; gap: 12px; margin-top: 32px; }
.button { display: inline-flex; align-items: center; justify-content: center; gap: 8px; min-height: 48px; border: 1px solid transparent; border-radius: 8px; padding: 12px 24px; font-size: 14px; font-weight: 500; text-decoration: none; background: var(--r-semantic-color-accent); color: var(--r-semantic-color-on-accent); transition: background-color var(--r-semantic-motion-hover) var(--r-semantic-motion-standard), transform var(--r-semantic-motion-press) var(--r-semantic-motion-standard); }
.button:active:not([aria-disabled='true']) { transform: scale(.98); }
.button:hover { background: var(--r-semantic-color-accent-hover); }
.button.secondary { background: var(--r-semantic-color-surface); color: var(--r-semantic-color-text); border-color: var(--r-semantic-color-border-control); }
.button.secondary:hover { background: var(--r-semantic-color-surface-subtle); }
.button[aria-disabled='true'] { opacity: .6; cursor: wait; }
.account-center { display: block; text-align: center; margin-top: 32px; font-size: 14px; color: var(--r-semantic-color-text-secondary); text-underline-offset: 4px; }
@media (max-width: 800px) { .shell { grid-template-columns: 1fr; } .brand-side, .epass-error .brand { padding: 24px; border-right: 0; border-bottom: 1px solid var(--r-semantic-color-border); } .brand-copy :is(h1, h2) { font-size: 28px; } .brand-wrap, .brand-content { gap: 24px; } .brand-foot { display: none; } .main { padding: 32px 20px; } }
html[data-reduce-motion='true'] * { animation: none !important; transition: none !important; }
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; } }
''';
