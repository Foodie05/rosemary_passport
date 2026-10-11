import { forwardRef, useCallback, useRef } from 'react';
import { flushSync } from 'react-dom';
import { Link as RouterLink, useLocation, useNavigate as useRouterNavigate, useResolvedPath } from 'react-router-dom';

const groups = [
  ['/login', '/register', '/forgot-password'],
  ['/admin/dashboard', '/admin/users', '/admin/oidc', '/admin/status', '/admin/service', '/admin/security', '/admin/legal', '/admin/account'],
  ['/docs/oidc', '/docs/flutter-sdk'],
  ['/legal/terms', '/legal/privacy'],
];
export function pageMotionFor(from, to) {
  if (from === to) return 'none';
  if (to.startsWith(`${from}/`)) return 'deeper';
  if (from.startsWith(`${to}/`)) return 'parent';
  const peers = groups.find((group) => group.includes(from) && group.includes(to));
  return peers ? (peers.indexOf(to) > peers.indexOf(from) ? 'peer-forward' : 'peer-back') : 'cross';
}
let active;
let generation = 0;
export function cancelPageMotion() {
  active?.skipTransition();
  active = undefined;
  delete document.documentElement.dataset.routeTransition;
}
function contentReady() {
  return new Promise((resolve) => {
    if (!document.querySelector('[data-route-loading]')) return resolve();
    const finish = () => { observer.disconnect(); clearTimeout(timer); resolve(); };
    const observer = new MutationObserver(() => { if (!document.querySelector('[data-route-loading]')) finish(); });
    observer.observe(document.getElementById('root'), { childList: true, subtree: true });
    const timer = setTimeout(finish, 4000);
  });
}
export function changePage(from, to, update) {
  cancelPageMotion();
  const serial = ++generation;
  const root = document.documentElement;
  const motion = pageMotionFor(from, to);
  root.dataset.routeMotion = motion;
  if (motion === 'none' || root.dataset.reduceMotion === 'true' || matchMedia('(prefers-reduced-motion: reduce)').matches || !document.startViewTransition) { update(); return; }
  root.dataset.routeTransition = 'native';
  try {
    const transition = document.startViewTransition(async () => {
      if (serial !== generation) return;
      flushSync(update);
      await contentReady();
    });
    active = transition;
    const finish = () => { if (active === transition) { active = undefined; delete root.dataset.routeTransition; } };
    transition.finished.then(finish, finish);
    transition.ready.catch(() => {});
  } catch { delete root.dataset.routeTransition; update(); }
}
export const Link = forwardRef(function Link({ onClick, to, target, reloadDocument, ...props }, ref) {
  const { pathname } = useLocation();
  const resolved = useResolvedPath(to);
  const navigate = useRouterNavigate();
  return <RouterLink {...props} ref={ref} to={to} target={target} reloadDocument={reloadDocument} onClick={(event) => {
    onClick?.(event);
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.altKey || event.ctrlKey || event.shiftKey || (target && target !== '_self') || reloadDocument || props.download != null) return;
    const url = new URL(event.currentTarget.href);
    if (url.origin !== location.origin || pathname === resolved.pathname) return;
    event.preventDefault();
    changePage(pathname, resolved.pathname, () => navigate(to, { replace: props.replace, state: props.state, relative: props.relative, preventScrollReset: props.preventScrollReset }));
  }} />;
});
export function useNavigate() {
  const navigate = useRouterNavigate();
  const { pathname } = useLocation();
  const current = useRef(pathname);
  current.current = pathname;
  return useCallback((to, options) => {
    if (typeof to !== 'string' || !to.startsWith('/')) return navigate(to, options);
    changePage(current.current, new URL(to, location.origin).pathname, () => navigate(to, options));
  }, [navigate]);
}
