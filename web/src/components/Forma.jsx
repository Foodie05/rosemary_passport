import { createContext, forwardRef, useContext, useRef } from 'react';
import { Button, Input, Textarea, Loading, Upload } from '@rosemary-ui/react';

export const FieldLabel = createContext('');

// Keep the application's event-shaped callbacks and native refs at the boundary.
export const FormaInput = forwardRef(function FormaInput({ label, onChange, value, type, ...props }, forwarded) {
  const inherited = useContext(FieldLabel);
  const input = useRef(null);
  if (type === 'hidden' || type === 'file') return <input {...props} ref={forwarded} type={type} value={value} onChange={onChange} />;
  return <Input {...props} type={type} value={value ?? ''} label={label ?? inherited} error={props['aria-invalid'] ? ' ' : undefined}
    ref={(node) => { input.current = node; if (typeof forwarded === 'function') forwarded(node); else if (forwarded) forwarded.current = node; }}
    onValueChange={() => onChange?.({ target: input.current, currentTarget: input.current })} />;
});
export const FormaTextarea = forwardRef(function FormaTextarea({ onChange, value, label, ...props }, forwarded) {
  const inherited = useContext(FieldLabel);
  const input = useRef(null);
  return <Textarea {...props} value={value ?? ''} label={label ?? inherited}
    ref={(node) => { input.current = node; if (typeof forwarded === 'function') forwarded(node); else if (forwarded) forwarded.current = node; }}
    onValueChange={() => onChange?.({ target: input.current, currentTarget: input.current })} />;
});
export const FormaButton = forwardRef(function FormaButton({ className = '', variant, type = 'submit', ...props }, ref) {
  const resolved = variant ?? (className.includes('btn-danger') ? 'danger' : className.includes('btn-primary') ? 'primary' : className.includes('btn-secondary') ? 'secondary' : 'ghost');
  return <Button {...props} ref={ref} type={type} variant={resolved} className={className} />;
});
export function FormaLoading({ className = '', ...props }) {
  return <Loading label="处理中" size="small" className={className} {...props} />;
}
export function FormaImport({ onImport }) {
  return <Upload label="批量导入提供商" files={[]} onFilesChange={(files) => onImport(files[0] || null)} accept=".txt,text/plain" maxCount={1} />;
}
