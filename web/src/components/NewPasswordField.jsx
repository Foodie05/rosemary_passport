import { FormaInput } from './Forma';
import { IconButton, passwordRequirements } from '@rosemary-ui/react';
import { useEffect, useId, useRef, useState } from 'react';
import { evaluatePassword, passwordContainsPersonalInfo } from '../lib/password-policy';

const requirements = [...passwordRequirements('zh'), {
  id: 'uncommon', label: '避开常见弱密码和连续、重复模式',
  check: value => evaluatePassword(value).uncommon,
}];

export function NewPasswordField({ label = '设置密码', value = '', onChange, personalInfo = [], className = '', verification, ...props }) {
  const id = useId();
  const input = useRef(null);
  const [visible, setVisible] = useState(false);
  const result = evaluatePassword(value);
  const personal = passwordContainsPersonalInfo(value, personalInfo);
  useEffect(() => { input.current?.setCustomValidity(value ? result.message : ''); }, [value, result.message]);
  return <div className={`epass-auth-field epass-new-password ${className}`}>
    <FormaInput {...props} ref={input} id={id} name="new-password" type={visible ? 'text' : 'password'} autoComplete="new-password" required value={value} onChange={onChange} label={label} requirements={requirements}
      description={personal ? '建议避开昵称、邮箱或手机号等个人信息。可使用密码管理器生成和保存。' : '建议使用独立密码，不与其他账户共用。可使用密码管理器生成和保存。'}
      verification={verification} />
    <IconButton variant="ghost" type="button" className="epass-password-visibility" icon={visible ? 'eye-off' : 'eye'} label={visible ? '隐藏密码' : '显示密码'} aria-pressed={visible} onClick={() => { setVisible(!visible); input.current?.focus(); }} />
  </div>;
}
