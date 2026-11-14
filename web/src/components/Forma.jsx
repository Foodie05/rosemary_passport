import { FieldFeedback } from './FieldFeedback';
import { rememberField, rememberActionField } from '../lib/field-feedback';
import { createContext, forwardRef, useContext, useRef } from 'react';
import { Button, Input, Textarea, Loading, Upload, useFieldValidation } from '@rosemary-ui/react';

export const FieldLabel = createContext('');

// Keep the application's event-shaped callbacks and native refs at the boundary.
export const FormaInput = forwardRef(function FormaInput({ label, onChange, value, type, error, verification, requirements, onFocus, onBlur, onCompositionStart, onCompositionEnd, validateEmail = type === 'email', ...props }, forwarded) {
  const inherited = useContext(FieldLabel);
  const input = useRef(null);
  const fieldLabel = label ?? (inherited || props['aria-label'] || props.placeholder || '');
  const emailValidation = useFieldValidation(value ?? '', validateEmail ? [{id:'email',label:'邮箱地址格式不正确。',check:value => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)}] : []);
  const rules = requirements ?? (/验证码|动态码/.test(fieldLabel) ? [{id:'code',label:'输入 6 位数字验证码',check:value => /^\d{6}$/.test(value)}] : undefined);
  if (type === 'hidden' || type === 'file') return <input {...props} ref={forwarded} type={type} value={value} onChange={onChange} />;
  return <Input {...props} type={type} value={value ?? ''} label={fieldLabel} requirements={rules} error={error || (emailValidation.invalid ? '邮箱地址格式不正确。' : undefined)} onFocus={event => { emailValidation.focus(); rememberField(event.currentTarget); onFocus?.(event); }}
    onBlur={event => {emailValidation.blur();onBlur?.(event);}}
    onCompositionStart={event => {emailValidation.compositionStart();onCompositionStart?.(event);}}
    onCompositionEnd={event => {emailValidation.compositionEnd();onCompositionEnd?.(event);}} verification={<>{verification}<FieldFeedback input={input} value={value} /></>}
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
export const FormaButton = forwardRef(function FormaButton({ className = '', variant, type = 'submit', onClick, ...props }, ref) {
  const resolved = variant ?? (className.includes('btn-danger') ? 'danger' : className.includes('btn-primary') ? 'primary' : className.includes('btn-secondary') ? 'secondary' : 'ghost');
  // Button metrics and type come from the SDK, independently of task layout.
  const layout = className.split(/\s+/).filter(name => !/^(?:text-(?:xs|sm|base|lg|xl|[2-9]xl)|font-(?:normal|medium|semibold|bold)|(?:p[xytrbl]?|h|min-h)-)/.test(name)).join(' ');
  return <Button {...props} ref={ref} type={type} onClick={event => { rememberActionField(event.currentTarget); onClick?.(event); }} variant={resolved} className={layout} />;
});
export function FormaLoading({ className = '', ...props }) {
  return <Loading label="处理中" size="small" className={className} {...props} />;
}
export function FormaImport({ onImport }) {
  return <Upload label="批量导入提供商" files={[]} onFilesChange={(files) => onImport(files[0] || null)} accept=".txt,text/plain" maxCount={1} />;
}
