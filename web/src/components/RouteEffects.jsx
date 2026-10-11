import { useLayoutEffect, useRef } from 'react';
import { useReducedMotion } from '../design/MotionPreferences';
import { cancelPageMotion, pageMotionFor } from '../design/NavigationMotion';
import { motionDuration, motionToken } from '../design/SelectionMotion';
import { useLocation } from 'react-router-dom';
const titles = { '/login': '登录', '/register': '创建账户', '/forgot-password': '找回密码', '/account': '账户与安全', '/admin/account': '账户与安全', '/admin/dashboard': '运营看板', '/admin/users': '用户管理', '/admin/oidc': '应用接入', '/admin/service': '服务配置', '/admin/security': '安全策略', '/admin/status': '状态管理', '/admin/legal': '协议管理', '/legal/terms': '使用条款', '/legal/privacy': '隐私政策', '/banned': '账户状态', '/docs/oidc': 'OIDC 接入文档', '/docs/flutter-sdk': 'Flutter SDK' };
export function RouteEffects() {
  const { pathname } = useLocation();
  const previous = useRef(pathname);
  const animation = useRef(null);
  const reduced = useReducedMotion();
  useLayoutEffect(() => {
    if (reduced) { cancelPageMotion(); animation.current?.cancel(); }
  }, [reduced]);
  useLayoutEffect(() => {
    document.title = titles[pathname] ? `${titles[pathname]} · Rosemary Epass` : 'Rosemary Epass';
    const motion = pageMotionFor(previous.current, pathname);
    previous.current = pathname;
    if (motion === 'none') return;
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
    document.documentElement.dataset.routeMotion = motion;
    animation.current?.cancel();
    let observer;
    const ready = () => {
      const main = document.querySelector('main');
      if (!main || document.querySelector('[data-route-loading]')) return false;
      main.setAttribute('tabindex', '-1');
      main.focus({ preventScroll: true });
      if (document.documentElement.dataset.reduceMotion !== 'true' && !matchMedia('(prefers-reduced-motion: reduce)').matches && document.documentElement.dataset.routeTransition !== 'native') {
        const root = getComputedStyle(document.documentElement);
        const distance = parseFloat(root.getPropertyValue(motion === 'cross' ? '--r-semantic-motion-distance-dialog' : motion === 'deeper' || motion === 'parent' ? '--r-semantic-motion-distance-panel' : '--r-semantic-space-16'));
        const sign = motion === 'parent' || motion === 'peer-back' ? -1 : 1;
        animation.current = main.animate([{ opacity: 0, transform: `translate${motion === 'cross' ? 'Y' : 'X'}(${sign * distance}px)` }, { opacity: 1, transform: 'none' }], { duration: motionDuration('settle'), easing: motionToken('standard') });
      }
      return true;
    };
    if (!ready()) {
      observer = new MutationObserver(() => { if (ready()) observer.disconnect(); });
      observer.observe(document.getElementById('root'), { childList: true, subtree: true });
    }
    return () => { observer?.disconnect(); animation.current?.cancel(); };
  }, [pathname]);
  return null;
}
