import { useEffect } from 'react';
import { usePresence } from 'motion/react';
import { StartDrawer } from './StartDrawer';
import { Dialog as FormaDialog } from '@rosemary-ui/react';

let modalCount = 0;
let savedRootOverflow = '';
let savedViewport = [];
let releaseViewport = () => {};
const viewportVars = ['--epass-visible-height', '--epass-visible-top'];
function lockRoot() {
  if (modalCount++ === 0) {
    savedRootOverflow = document.documentElement.style.overflow;
    document.documentElement.style.overflow = 'hidden';
    savedViewport = viewportVars.map(name => document.documentElement.style.getPropertyValue(name));
    const viewport = window.visualViewport;
    const measure = () => {
      document.documentElement.style.setProperty(viewportVars[0], `${viewport?.height ?? window.innerHeight}px`);
      document.documentElement.style.setProperty(viewportVars[1], `${viewport?.offsetTop ?? 0}px`);
    };
    measure();
    window.addEventListener('resize', measure);
    viewport?.addEventListener('resize', measure);
    viewport?.addEventListener('scroll', measure);
    releaseViewport = () => {
      window.removeEventListener('resize', measure);
      viewport?.removeEventListener('resize', measure);
      viewport?.removeEventListener('scroll', measure);
      viewportVars.forEach((name, index) => savedViewport[index] ? document.documentElement.style.setProperty(name, savedViewport[index]) : document.documentElement.style.removeProperty(name));
    };
  }
  return () => { if (--modalCount === 0) { document.documentElement.style.overflow = savedRootOverflow; releaseViewport(); } };
}

// Keep the official overlay in its provider through the actual exit animation.
export function Dialog({ title, children, onClose, actions, className = '' }) {
  const [present, safeToRemove] = usePresence();
  useEffect(lockRoot, []);
  const Component = className.includes('epass-dialog-navigation') ? StartDrawer : FormaDialog;
  return <Component open={present} title={title} onOpenChange={(open) => { if (!open) onClose?.(); }}
    closeLabel="关闭弹窗" footer={actions} className={`forma-dialog ${className}`}
    onAnimationComplete={(open) => { if (!open) safeToRemove?.(); }}>{children}</Component>;
}
