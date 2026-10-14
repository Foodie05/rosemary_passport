import { useLayoutEffect, useRef, useState } from 'react';
import { useReducedMotion } from './MotionPreferences';

// Resolve the published CSS tokens so presentation has a single source of truth.
export function motionToken(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(`--r-semantic-motion-${name}`).trim();
}
export function motionDuration(name) { return parseFloat(motionToken(name)) || 0; }

export function SelectionGroup({ value, label, className = '', indicator: showIndicator = true, children }) {
  const ref = useRef(null);
  const [indicator, setIndicator] = useState(null);
  useLayoutEffect(() => {
    if (!showIndicator) return;
    const element = ref.current;
    const measure = () => {
      const selected = element.querySelector('[aria-pressed="true"]');
      if (selected) setIndicator({ width: selected.offsetWidth, transform: `translate(${selected.offsetLeft}px, ${selected.offsetTop + selected.offsetHeight - 2}px)` });
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    [...element.children].forEach((child) => { if (child.tagName === 'BUTTON') observer.observe(child); });
    return () => observer.disconnect();
  }, [value, showIndicator]);
  return <div ref={ref} className={`epass-methods ${className}`} role="group" aria-label={label}>
    {children}
    {showIndicator && indicator && <span className="epass-selection-indicator" aria-hidden="true" style={indicator} />}
  </div>;
}

// Replace live content immediately. Only the current panel animates; no duplicate forms.
export function SelectionContent({ value, index = 0, className = '', children }) {
  const ref = useRef(null);
  const previous = useRef({ value, index });
  const animation = useRef(null);
  const reduced = useReducedMotion();
  useLayoutEffect(() => {
    const changed = previous.current.value !== value;
    const direction = index < previous.current.index ? -1 : 1;
    previous.current = { value, index };
    if (reduced) { animation.current?.cancel(); return; }
    if (!changed || !ref.current?.animate) return;
    const element = ref.current;
    const current = getComputedStyle(element);
    const distance = 0;
    const start = animation.current?.playState === 'running'
      ? { opacity: current.opacity, transform: current.transform }
      : { opacity: 0, transform: `translateX(${direction * distance}px)` };
    animation.current?.cancel();
    animation.current = element.animate([start, { opacity: 1, transform: 'none' }], { duration: motionDuration('tabs'), easing: motionToken('standard') });
  }, [value, index, reduced]);
  useLayoutEffect(() => () => animation.current?.cancel(), []);
  return <div ref={ref} className={className}>{children}</div>;
}

export function useVisualPresence(open) {
  const [retained, setRetained] = useState(open);
  const reduced = useReducedMotion();
  useLayoutEffect(() => {
    if (open) { setRetained(true); return; }
    if (reduced) { setRetained(false); return; }
    const timer = setTimeout(() => setRetained(false), motionDuration('exit'));
    return () => clearTimeout(timer);
  }, [open, reduced]);
  return open || retained;
}
