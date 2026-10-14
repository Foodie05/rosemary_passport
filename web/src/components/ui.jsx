import { AnimatePresence } from 'motion/react';
import { useVisualPresence } from '../design/SelectionMotion';
import { createContext, useCallback, useContext, useEffect, useId, useLayoutEffect, useRef, useState } from 'react';
import { Checkbox, Select } from '@rosemary-ui/react';
import { FormaButton, FieldLabel } from './Forma';
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
      {dialog.kind === 'confirm' && <FormaButton type="button" className="btn-secondary" onClick={() => close(false)}>{dialog.cancelLabel || '取消'}</FormaButton>}
      <FormaButton type="button" className={cn('btn-primary', dialog.tone === 'danger' && 'btn-danger')} onClick={() => close(true)}>{dialog.confirmLabel || (dialog.kind === 'alert' ? '知道了' : '确认')}</FormaButton>
    </>}><p className="whitespace-pre-line text-sm text-muted">{dialog.message}</p></Dialog>}</AnimatePresence>
  </RosemaryDialogContext.Provider>;
}

export function useRosemaryDialog() {
  const value = useContext(RosemaryDialogContext);
  if (!value) throw new Error('useRosemaryDialog must be used within RosemaryDialogProvider');
  return value;
}

export function RosemaryCheckbox({ checked, onCheckedChange, disabled = false, children, className = '', ariaLabel }) {
  return <Checkbox checked={Boolean(checked)} onCheckedChange={onCheckedChange || (() => {})} disabled={disabled} label={children || ''} aria-label={ariaLabel} className={className} />;
}

export function RosemarySelect({ value, onChange, options, label, disabled = false, className = '' }) {
  return <div className={className}><Select value={value} onValueChange={onChange} options={options} label={label} disabled={disabled} /></div>;
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
    <FieldLabel.Provider value={label}><div className="field">
      {children}
    </div></FieldLabel.Provider>
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
