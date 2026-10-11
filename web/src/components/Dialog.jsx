import { useId, useLayoutEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { usePresence } from 'motion/react';
import { X } from 'lucide-react';
import { useReducedMotion } from '../design/MotionPreferences';
import { motionDuration } from '../design/SelectionMotion';

// Native close releases modality immediately; CSS retains only the visual exit.
export function Dialog({ title, children, onClose, actions, role = 'dialog', className = '' }) {
  const ref = useRef(null);
  const id = useId();
  const closeRef = useRef(onClose);
  const release = useRef(null);
  const [present, safeToRemove] = usePresence();
  const reduced = useReducedMotion();
  closeRef.current = onClose;
  useLayoutEffect(() => {
    const element = ref.current;
    if (present) {
      if (!element.open) {
        const previous = document.activeElement;
        const overflow = document.body.style.overflow;
        element.showModal();
        document.body.style.overflow = 'hidden';
        const first = element.querySelector('[data-autofocus], input:not([disabled]), textarea:not([disabled])');
        (first || element.querySelector('[data-dialog-content]')).focus();
        release.current = () => {
          element.close();
          document.body.style.overflow = overflow;
          if (previous?.isConnected) previous.focus?.({ preventScroll: true });
          release.current = null;
        };
      }
      return;
    }
    release.current?.();
    if (reduced) { safeToRemove?.(); return; }
    const timer = setTimeout(() => safeToRemove?.(), motionDuration('exit'));
    return () => clearTimeout(timer);
  }, [present, reduced, safeToRemove]);
  useLayoutEffect(() => () => release.current?.(), []);
  return createPortal(
    <dialog ref={ref} className={`epass-dialog ${className}`} role={role} aria-modal={present ? 'true' : undefined} aria-hidden={!present || undefined} inert={!present ? '' : undefined} aria-labelledby={id} onCancel={(event) => { event.preventDefault(); closeRef.current?.(); }}>
      <header className="epass-dialog-head"><h2 id={id}>{title}</h2><button type="button" className="inline-flex h-11 w-11 items-center justify-center rounded-control" aria-label="关闭弹窗" onClick={onClose}><X size={20} /></button></header>
      <div className="epass-dialog-body" tabIndex={-1} data-dialog-content>{children}</div>
      {actions && <footer className="epass-dialog-actions">{actions}</footer>}
    </dialog>, document.body,
  );
}
