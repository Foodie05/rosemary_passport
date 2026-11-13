import { useEffect } from 'react';
import { usePresence } from 'motion/react';
import { Dialog as FormaDialog, Drawer } from '@rosemary-ui/react';

let modalCount = 0;
let savedRootOverflow = '';
function lockRoot() {
  if (modalCount++ === 0) {
    savedRootOverflow = document.documentElement.style.overflow;
    document.documentElement.style.overflow = 'hidden';
  }
  return () => { if (--modalCount === 0) document.documentElement.style.overflow = savedRootOverflow; };
}

// Keep the official overlay in its provider through the actual exit animation.
export function Dialog({ title, children, onClose, actions, className = '' }) {
  const [present, safeToRemove] = usePresence();
  useEffect(lockRoot, []);
  const Component = className.includes('epass-dialog-navigation') ? Drawer : FormaDialog;
  return <Component open={present} title={title} onOpenChange={(open) => { if (!open) onClose?.(); }}
    closeLabel="关闭弹窗" footer={actions} className={`forma-dialog ${className}`}
    onAnimationComplete={(open) => { if (!open) safeToRemove?.(); }}>{children}</Component>;
}
