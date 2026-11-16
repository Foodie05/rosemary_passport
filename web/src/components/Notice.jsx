import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { usePresence } from 'motion/react';
import { useReducedMotion } from '../design/MotionPreferences';
import { motionDuration } from '../design/SelectionMotion';

function noticeHost() {
  if (typeof document === 'undefined') return null;
  const focusedDialog = document.activeElement?.closest('dialog[open]');
  const dialogs = document.querySelectorAll('dialog[open]');
  return focusedDialog || dialogs[dialogs.length - 1] || document.body;
}

export function Notice({ role = 'status', className = '', children }) {
  const [present, remove] = usePresence();
  const reduced = useReducedMotion();
  const element = useRef(null);
  const [host, setHost] = useState(noticeHost);
  useLayoutEffect(() => {
    const update = () => setHost(noticeHost());
    // Rehost when a modal opens or closes while feedback is already visible.
    const observer = new MutationObserver(update);
    observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['open'] });
    document.addEventListener('focusin', update);
    update();
    return () => { observer.disconnect(); document.removeEventListener('focusin', update); };
  }, []);
  useLayoutEffect(() => {
    const node = element.current;
    if (!node?.showPopover) return;
    // A manual popover paints above native showModal() dialogs. Keeping it
    // inside the active dialog also avoids modal inertness for screen readers.
    node.showPopover();
    return () => { if (node.matches(':popover-open')) node.hidePopover(); };
  }, [host]);
  useEffect(() => {
    if (present) return;
    if (reduced) { remove?.(); return; }
    const timer = setTimeout(() => remove?.(), motionDuration('exit'));
    return () => clearTimeout(timer);
  }, [present, reduced, remove]);
  const content = <div ref={element} popover="manual" role={present ? role : undefined} aria-atomic="true" aria-hidden={!present || undefined} inert={!present ? '' : undefined} data-motion-state={present ? 'open' : 'exiting'} className={`epass-notice ${className}`}>{children}</div>;
  return host ? createPortal(content, host) : content;
}
