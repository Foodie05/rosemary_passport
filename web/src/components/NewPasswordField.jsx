import { useEffect, useId, useRef, useState } from 'react';
import { Check, Circle, Eye, EyeOff, Lock } from 'lucide-react';
import { evaluatePassword, passwordContainsPersonalInfo } from '../lib/password-policy';

export function NewPasswordField({ label = '设置密码', value = '', onChange, personalInfo = [], className = '', ...props }) {
  const id = useId();
  const input = useRef(null);
  const [visible, setVisible] = useState(false);
  const result = evaluatePassword(value);
  const personal = passwordContainsPersonalInfo(value, personalInfo);
  useEffect(() => { input.current?.setCustomValidity(value ? result.message : ''); }, [value, result.message]);
  const checks = [
    ['不少于 8 个字符', result.lengthValid],
    ['字母、数字、符号中至少包含两种', result.compositionValid],
    ['英文字母、数字或符号，首尾无空格', result.formatValid],
    ['避开常见弱密码和连续、重复模式', result.uncommon],
  ];
  return <div className={`epass-auth-field ${className}`}>
    <label htmlFor={id}>{label}</label>
    <div className="relative">
      <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" size={20} aria-hidden="true" />
      <input {...props} ref={input} id={id} name="new-password" type={visible ? 'text' : 'password'} autoComplete="new-password" required value={value} onChange={onChange} aria-invalid={value && !result.ok ? true : undefined} aria-describedby={`${id}-requirements ${id}-status ${id}-advice`} className="input-field pl-12 pr-12" />
      <button type="button" className="epass-password-toggle" aria-label={visible ? '隐藏密码' : '显示密码'} aria-pressed={visible} onClick={() => setVisible(!visible)}>{visible ? <EyeOff size={20} /> : <Eye size={20} />}</button>
    </div>
    <ul id={`${id}-requirements`} className="epass-password-checks">
      {checks.map(([text, passed]) => <li key={text} data-passed={Boolean(value && passed)}>{value && passed ? <Check size={16} aria-hidden="true" /> : <Circle size={16} aria-hidden="true" />}<span>{text}{value && passed && <span className="sr-only">，已满足</span>}</span></li>)}
    </ul>
    <p id={`${id}-status`} role="status" aria-live="polite" aria-atomic="true" className={`epass-password-status ${value && !result.ok ? 'text-danger' : 'text-muted'}`}>{!value ? '输入时会即时检查密码要求。' : result.ok ? '已满足密码要求。' : result.message}</p>
    <p id={`${id}-advice`} className="text-sm leading-6 text-muted">{personal ? '建议避开昵称、邮箱或手机号等个人信息。' : '建议使用较长的独立密码或易记的词组，不与其他账户共用。'} 可使用密码管理器生成和保存。</p>
  </div>;
}
