import { Component, createRef, useLayoutEffect, useRef, useState } from 'react';
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


// Snapshot before React replaces the current form. The outgoing visual is inert;
// only the current panel owns events, focus, validation and submission.
class SlidingPanel extends Component {
  host = createRef();
  live = createRef();
  animations = [];
  serial = 0;
  height = 0;
  ghost = null;

  componentDidMount() {
    this.height = this.live.current.offsetHeight;
    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(this.live.current);
  }

  getSnapshotBeforeUpdate(previous) {
    if (previous.value === this.props.value || this.props.reduced) return null;
    const live = this.live.current;
    const clone = live.cloneNode(true);
    clone.setAttribute('inert', '');
    clone.setAttribute('aria-hidden', 'true');
    clone.removeAttribute('data-slide-current');
    clone.querySelectorAll('[id]').forEach(node => node.removeAttribute('id'));
    clone.querySelectorAll('input').forEach((input, index) => {
      const original = live.querySelectorAll('input')[index];
      input.removeAttribute('name');
      if (input.type === 'password') {
        input.removeAttribute('value');
        input.value = '';
        input.placeholder = original.value ? '••••••••' : original.placeholder;
      } else {
        input.value = original.value;
        input.checked = original.checked;
      }
    });
    return { clone, height:this.host.current.getBoundingClientRect().height, transform:getComputedStyle(live).transform, hadFocus:live.contains(document.activeElement), direction:this.props.index < previous.index ? -1 : 1 };
  }

  componentDidUpdate(previous, state, snapshot) {
    this.observer.disconnect();
    this.observer.observe(this.live.current);
    if (this.props.reduced) {this.stop();return;}
    if (!snapshot) return;
    this.stop();
    const host = this.host.current, live = this.live.current;
    if (snapshot.hadFocus) live.querySelector('input,button')?.focus({preventScroll:true});
    if (!live.animate) return;
    const duration = motionDuration('tabs'), easing = motionToken('standard');
    const width = host.clientWidth, nextHeight = live.offsetHeight;
    const ghost = snapshot.clone;
    ghost.classList.add('epass-slide-ghost');
    host.append(ghost);
    this.ghost = ghost;
    const serial = ++this.serial;
    this.height = nextHeight;
    this.animations = [
      ghost.animate([{transform:snapshot.transform}, {transform:`translateX(${-snapshot.direction * width}px)`}], {duration,easing,fill:'both'}),
      live.animate([{transform:`translateX(${snapshot.direction * width}px)`},{transform:'translateX(0px)'}], {duration,easing}),
      host.animate([{height:`${snapshot.height}px`},{height:`${nextHeight}px`}], {duration,easing:'linear'}),
    ];
    Promise.allSettled(this.animations.map(animation => animation.finished)).then(() => {
      if (serial === this.serial) this.stop();
    });
  }

  resize() {
    const height = this.live.current.offsetHeight;
    if (height === this.height || this.ghost) return;
    const before = this.height;
    this.height = height;
    if (this.props.reduced || !this.host.current.animate) return;
    const current = this.host.current.getBoundingClientRect().height;
    this.stop();
    this.height = height;
    this.animations = [this.host.current.animate([{height:`${current === height ? before : current}px`},{height:`${height}px`}], {duration:motionDuration('tabs'),easing:'linear'})];
  }

  stop() {
    this.serial++;
    this.animations.forEach(animation => animation.cancel());
    this.animations = [];
    this.ghost?.remove();
    this.ghost = null;
  }

  componentWillUnmount() {this.stop();this.observer.disconnect();}

  render() {
    return <div ref={this.host} className={`epass-sliding-content ${this.props.className || ''}`}>
      <div key={this.props.value} ref={this.live} data-slide-current>{this.props.children}</div>
    </div>;
  }
}

export function SlidingSelectionContent(props) {
  const reduced = useReducedMotion();
  return <SlidingPanel {...props} reduced={reduced} />;
}
