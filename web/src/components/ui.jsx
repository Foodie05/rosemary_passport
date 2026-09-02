import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { AlertTriangle, Check, CheckCircle2, ChevronDown, Info, X } from 'lucide-react';
import { cn } from '../lib/utils';

const RosemaryDialogContext = createContext(null);

export function RosemaryDialogProvider({ children }) {
  const [dialog, setDialog] = useState(null);
  const dialogRef = useRef(null);
  const primaryActionRef = useRef(null);
  const previousFocusRef = useRef(null);

  const requestDialog = useCallback((kind, options) => new Promise((resolve) => {
    dialogRef.current?.resolve(false);
    previousFocusRef.current = document.activeElement;
    const next = { kind, resolve, ...options };
    dialogRef.current = next;
    setDialog(next);
  }), []);

  const confirm = useCallback(
    (options) => requestDialog('confirm', options),
    [requestDialog],
  );
  const alert = useCallback(
    (options) => requestDialog('alert', options),
    [requestDialog],
  );

  const closeDialog = useCallback((result) => {
    const current = dialogRef.current;
    dialogRef.current = null;
    setDialog(null);
    current?.resolve(result);
    queueMicrotask(() => previousFocusRef.current?.focus?.());
  }, []);

  useEffect(() => {
    if (!dialog) return undefined;
    primaryActionRef.current?.focus();
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const onKeyDown = (event) => {
      if (event.key === 'Escape') closeDialog(false);
    };
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [dialog, closeDialog]);

  const tone = dialog?.tone || 'default';
  const ToneIcon = tone === 'danger' || tone === 'warning'
    ? AlertTriangle
    : dialog?.kind === 'alert'
      ? Info
      : CheckCircle2;

  return (
    <RosemaryDialogContext.Provider value={{ confirm, alert }}>
      {children}
      {dialog ? createPortal(
        <div className="fixed inset-0 z-[120] flex items-center justify-center overflow-y-auto bg-sage-950/45 p-4 backdrop-blur-sm" role="presentation">
          <section className="glass-card w-full max-w-md overflow-hidden rounded-[2rem] border border-white/70 shadow-2xl shadow-sage-950/20" role="alertdialog" aria-modal="true" aria-labelledby="rosemary-dialog-title" aria-describedby="rosemary-dialog-description">
            <div className="flex items-start gap-4 px-6 pb-4 pt-6 sm:px-7 sm:pt-7">
              <span className={cn(
                'flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl',
                tone === 'danger' ? 'bg-red-100 text-red-700' : tone === 'warning' ? 'bg-amber-100 text-amber-700' : 'bg-sage-100 text-sage-700',
              )}>
                <ToneIcon size={22} />
              </span>
              <div className="min-w-0 flex-1">
                <h2 id="rosemary-dialog-title" className="text-xl font-bold text-sage-950">{dialog.title || '请确认'}</h2>
                <p id="rosemary-dialog-description" className="mt-2 whitespace-pre-line text-sm leading-6 text-sage-600">{dialog.message}</p>
              </div>
              <button type="button" onClick={() => closeDialog(false)} className="rounded-xl p-2 text-sage-400 transition-colors hover:bg-sage-100 hover:text-sage-700" aria-label="关闭弹窗">
                <X size={18} />
              </button>
            </div>
            <div className="flex flex-col-reverse gap-3 border-t border-sage-100 bg-sage-50/60 px-6 py-4 sm:flex-row sm:justify-end sm:px-7">
              {dialog.kind === 'confirm' ? (
                <button type="button" className="btn-secondary" onClick={() => closeDialog(false)}>{dialog.cancelLabel || '取消'}</button>
              ) : null}
              <button
                ref={primaryActionRef}
                type="button"
                className={cn('btn-primary', tone === 'danger' && 'bg-red-600 hover:bg-red-700')}
                onClick={() => closeDialog(true)}
              >
                {dialog.confirmLabel || (dialog.kind === 'alert' ? '知道了' : '确认')}
              </button>
            </div>
          </section>
        </div>,
        document.body,
      ) : null}
    </RosemaryDialogContext.Provider>
  );
}

export function useRosemaryDialog() {
  const value = useContext(RosemaryDialogContext);
  if (!value) throw new Error('useRosemaryDialog must be used within RosemaryDialogProvider');
  return value;
}

export function RosemaryCheckbox({ checked, onCheckedChange, disabled = false, children, className = '', ariaLabel }) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={Boolean(checked)}
      aria-label={ariaLabel}
      disabled={disabled}
      onClick={() => onCheckedChange?.(!checked)}
      className={cn(
        'inline-flex items-start gap-2.5 text-left text-sm text-sage-600 transition-colors disabled:cursor-not-allowed disabled:opacity-50',
        className,
      )}
    >
      <span className={cn(
        'mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-md border-2 transition-all',
        checked ? 'border-sage-600 bg-sage-600 text-white shadow-sm' : 'border-sage-300 bg-white text-transparent hover:border-sage-500',
      )} aria-hidden="true">
        <Check size={13} strokeWidth={3} />
      </span>
      {children ? <span className="min-w-0 leading-6">{children}</span> : null}
    </button>
  );
}

export function RosemarySelect({ value, onChange, options, label, disabled = false, className = '' }) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef(null);
  const selected = options.find((option) => option.value === value) || options[0];

  useEffect(() => {
    if (!open) return undefined;
    const onPointerDown = (event) => {
      if (!containerRef.current?.contains(event.target)) setOpen(false);
    };
    const onKeyDown = (event) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('pointerdown', onPointerDown);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('pointerdown', onPointerDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [open]);

  return (
    <div ref={containerRef} className={cn('relative', className)}>
      <button
        type="button"
        disabled={disabled}
        className="input-field flex w-full items-center justify-between gap-3 text-left disabled:cursor-not-allowed disabled:opacity-50"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={label}
        onClick={() => setOpen((current) => !current)}
      >
        <span className="min-w-0 truncate font-medium text-sage-800">{selected?.label || '请选择'}</span>
        <ChevronDown size={18} className={cn('shrink-0 text-sage-500 transition-transform', open && 'rotate-180')} />
      </button>
      {open ? (
        <div className="absolute left-0 right-0 top-[calc(100%+0.5rem)] z-50 overflow-hidden rounded-2xl border border-sage-200 bg-white p-1.5 shadow-xl shadow-sage-900/10" role="listbox" aria-label={label}>
          {options.map((option) => (
            <button
              key={option.value}
              type="button"
              role="option"
              aria-selected={option.value === value}
              className={cn(
                'flex w-full items-center justify-between gap-3 rounded-xl px-3 py-2.5 text-left text-sm transition-colors',
                option.value === value ? 'bg-sage-100 font-bold text-sage-900' : 'text-sage-600 hover:bg-sage-50 hover:text-sage-900',
              )}
              onClick={() => {
                onChange(option.value);
                setOpen(false);
              }}
            >
              <span>{option.label}</span>
              {option.value === value ? <Check size={16} className="text-sage-600" /> : null}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
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
