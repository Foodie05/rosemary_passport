import { useLayoutEffect } from 'react';
import { usePresence } from 'motion/react';
import { useReducedMotion } from '../design/MotionPreferences';
import { motionDuration } from '../design/SelectionMotion';

export function Notice({ role = 'status', className = '', children }) {
  const [present, remove] = usePresence();
  const reduced = useReducedMotion();
  useLayoutEffect(() => {
    if (present) return;
    if (reduced) { remove?.(); return; }
    const timer = setTimeout(() => remove?.(), motionDuration('exit'));
    return () => clearTimeout(timer);
  }, [present, reduced, remove]);
  return <div role={present ? role : undefined} aria-hidden={!present || undefined} inert={!present ? '' : undefined} data-motion-state={present ? 'open' : 'exiting'} className={`epass-notice ${className}`}>{children}</div>;
}
