import { usePresence } from 'motion/react';
import { Dialog as FormaDialog, Drawer } from '@rosemary-ui/react';

// Keep the official overlay in its provider through the actual exit animation.
export function Dialog({ title, children, onClose, actions, className = '' }) {
  const [present, safeToRemove] = usePresence();
  const Component = className.includes('epass-dialog-navigation') ? Drawer : FormaDialog;
  return <Component open={present} title={title} onOpenChange={(open) => { if (!open) onClose?.(); }}
    closeLabel="关闭弹窗" footer={actions} className={`forma-dialog ${className}`}
    onAnimationComplete={(open) => { if (!open) safeToRemove?.(); }}>{children}</Component>;
}
