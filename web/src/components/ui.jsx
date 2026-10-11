import { AnimatePresence } from 'motion/react';
import { useVisualPresence } from '../design/SelectionMotion';
import { createContext, useCallback, useContext, useEffect, useId, useLayoutEffect, useRef, useState } from 'react';
import { Check, ChevronDown } from 'lucide-react';
import { cn } from '../lib/utils';
import { Dialog } from './Dialog';

const RosemaryDialogContext = createContext(null);

export function RosemaryDialogProvider({ children }) {
  const [dialog, setDialog] = useState(null);
  const pending = useRef(null);
  const requestDialog = useCallback((kind, options) => new Promise((resolve) => {
    pending.current?.resolve(false);
    pending.current = { kind, ...options, resolve };
    setDialog(pending.current);
  }), []);
  const confirm = useCallback((options) => requestDialog('confirm', options), [requestDialog]);
  const alert = useCallback((options) => requestDialog('alert', options), [requestDialog]);
  const close = (result) => { pending.current?.resolve(result); pending.current = null; setDialog(null); };
  useEffect(() => () => pending.current?.resolve(false), []);
  return <RosemaryDialogContext.Provider value={{ confirm, alert }}>
    {children}
    <AnimatePresence>{dialog && <Dialog key="shared-dialog" role="alertdialog" title={dialog.title || '请确认'} onClose={() => close(false)} actions={<>
      {dialog.kind === 'confirm' && <button type="button" className="btn-secondary" onClick={() => close(false)}>{dialog.cancelLabel || '取消'}</button>}
      <button type="button" className={cn('btn-primary', dialog.tone === 'danger' && 'btn-danger')} onClick={() => close(true)}>{dialog.confirmLabel || (dialog.kind === 'alert' ? '知道了' : '确认')}</button>
    </>}><p className="whitespace-pre-line text-sm text-muted">{dialog.message}</p></Dialog>}</AnimatePresence>
  </RosemaryDialogContext.Provider>;
}

export function useRosemaryDialog() {
  const value = useContext(RosemaryDialogContext);
  if (!value) throw new Error('useRosemaryDialog must be used within RosemaryDialogProvider');
  return value;
}

export function RosemaryCheckbox({ checked, onCheckedChange, disabled = false, children, className = '', ariaLabel }) {
  return <label className={cn('epass-checkbox', className)}>
    <span className="epass-checkbox-control">
      <input type="checkbox" checked={Boolean(checked)} disabled={disabled} aria-label={ariaLabel} onChange={(event) => onCheckedChange?.(event.target.checked)} />
      <Check size={16} aria-hidden="true" />
    </span>
    {children && <span>{children}</span>}
  </label>;
}

export function RosemarySelect({ value, onChange, options, label, disabled = false, className = '' }) {
  const id = useId();
  const trigger = useRef(null);
  const popup = useRef(null);
  const prefix = useRef({ text: '', time: 0 });
  const [open, setOpen] = useState(false);
  const present = useVisualPresence(open);
  const [active, setActive] = useState(-1);
  const selected = options.findIndex((option) => option.value === value);
  const enabled = options.map((option, i) => option.disabled ? -1 : i).filter((i) => i >= 0);
  const unavailable = disabled || !enabled.length;
  function show(index) { if (!unavailable) { setActive(index ?? (enabled.includes(selected) ? selected : enabled[0])); setOpen(true); } }
  function commit(index) { if (!open || !options[index] || options[index].disabled) return; onChange(options[index].value); setOpen(false); trigger.current?.focus(); }
  useLayoutEffect(() => {
    if (!open) return;
    const panel = popup.current;
    const rect = trigger.current.getBoundingClientRect();
    if (panel.showPopover) panel.showPopover();
    panel.style.width = `${Math.min(Math.max(rect.width, 160), innerWidth - 32)}px`;
    const height = panel.getBoundingClientRect().height;
    panel.style.left = `${Math.max(16, Math.min(rect.left, innerWidth - panel.offsetWidth - 16))}px`;
    panel.style.top = `${Math.max(16, Math.min(rect.bottom + height + 8 > innerHeight - 16 ? rect.top - height - 8 : rect.bottom + 8, innerHeight - height - 16))}px`;
    panel.dataset.side = rect.bottom + height + 8 > innerHeight - 16 ? 'above' : 'below';
  }, [open]);
  useEffect(() => {
    if (!open) return;
    const outside = (event) => { if (!trigger.current?.contains(event.target) && !popup.current?.contains(event.target)) setOpen(false); };
    const scroll = (event) => { if (!popup.current?.contains(event.target)) setOpen(false); };
    const resize = () => setOpen(false);
    document.addEventListener('pointerdown', outside);
    document.addEventListener('focusin', outside);
    window.addEventListener('scroll', scroll, true);
    window.addEventListener('resize', resize);
    return () => { document.removeEventListener('pointerdown', outside); document.removeEventListener('focusin', outside); window.removeEventListener('scroll', scroll, true); window.removeEventListener('resize', resize); };
  }, [open]);
  useEffect(() => { setOpen(false); }, [value, unavailable]);
  useEffect(() => { if (open) document.getElementById(`${id}-${active}`)?.scrollIntoView({ block: 'nearest' }); }, [active, open, id]);
  return <div className={cn('relative', className)}>
    <button ref={trigger} type="button" role="combobox" disabled={unavailable} aria-label={label} aria-expanded={open} aria-haspopup="listbox" aria-controls={open ? id : undefined} aria-activedescendant={open && active >= 0 ? `${id}-${active}` : undefined} className="input-field flex items-center justify-between gap-3 text-left" onClick={() => open ? setOpen(false) : show()} onKeyDown={(event) => {
      const key = event.key;
      if (key === 'Tab') { setOpen(false); return; }
      if (key === 'Escape' && open) { event.preventDefault(); event.stopPropagation(); setOpen(false); return; }
      if (key === 'Enter' || key === ' ') { event.preventDefault(); open ? commit(active) : show(); }
      else if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(key)) {
        event.preventDefault();
        if (!open) show(key === 'End' ? enabled.at(-1) : key === 'Home' ? enabled[0] : undefined);
        else setActive(key === 'Home' ? enabled[0] : key === 'End' ? enabled.at(-1) : enabled[Math.max(0, Math.min(enabled.length - 1, enabled.indexOf(active) + (key === 'ArrowDown' ? 1 : -1)))]);
      } else if (key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
        const now = Date.now(); const text = (now - prefix.current.time < 700 ? prefix.current.text : '') + key.toLocaleLowerCase(); prefix.current = { text, time: now };
        const match = enabled.find((i) => options[i].label.toLocaleLowerCase().startsWith(text));
        if (match !== undefined) { event.preventDefault(); open ? setActive(match) : show(match); }
      }
    }}><span className="min-w-0 truncate">{options[selected]?.label || '请选择'}</span><ChevronDown size={20} aria-hidden="true" /></button>
    {present && <div data-motion-state={open ? 'open' : 'exiting'} inert={!open ? '' : undefined} aria-hidden={!open || undefined} ref={popup} popover="manual" role="listbox" id={id} aria-label={label} className="epass-select-list">
      {options.map((option, i) => <div key={option.value} id={`${id}-${i}`} role="option" aria-selected={i === selected} aria-disabled={option.disabled || undefined} data-active={i === active} className="epass-select-option" onPointerMove={() => open && !option.disabled && setActive(i)} onPointerDown={(event) => event.preventDefault()} onClick={() => commit(i)}><span>{option.label}</span>{i === selected && <Check size={16} aria-hidden="true" />}</div>)}
    </div>}
  </div>;
}

export function Panel({ title, description, actions, children }) {
  return (
    <section className="panel">
      <div className="panel-head">
        <div className="section-heading">
          <h2>{title}</h2>
          {description && <p>{description}</p>}
        </div>
        {actions}
      </div>
      {children}
    </section>
  );
}

export function Field({ label, children }) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  );
}

export function InfoPill({ label, value }) {
  return (
    <div className="info-pill">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export function InfoTile({ title, value, tone = 'neutral' }) {
  return (
    <article className={`info-tile ${tone}`}>
      <span>{title}</span>
      <strong>{value}</strong>
    </article>
  );
}

export function KeyValueList({ items }) {
  return (
    <div className="keyvalue-list">
      {items.map(([label, value]) => (
        <div key={label} className="keyvalue-row">
          <span>{label}</span>
          <strong title={`${value}`}>{value}</strong>
        </div>
      ))}
    </div>
  );
}

export function JsonBlock({ data, compact = false }) {
  return <pre className={compact ? 'json-block compact' : 'json-block'}>{JSON.stringify(data, null, 2)}</pre>;
}

export function EmptyState({ title, body }) {
  return (
    <div className="empty-state">
      <strong>{title}</strong>
      <p>{body}</p>
    </div>
  );
}

export function DecorBackdrop() {
  return (
    <div className="decor-backdrop" aria-hidden="true">
      <span className="blur blur-a" />
      <span className="blur blur-b" />
      <span className="grid-glow" />
    </div>
  );
}
