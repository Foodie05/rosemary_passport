import {useEffect, useState} from 'react';
import {Alert} from '@rosemary-ui/react';
import {FormaButton, FormaInput} from './Forma';
import {RosemarySelect} from './ui';
import {getUserErrorMessage} from '../lib/errors';
import {preparePublicKeyRequestOptions, serializeAuthenticationCredential} from '../lib/utils';

const labels = {password:'当前密码',email_code:'当前邮箱验证码',phone_code:'当前手机验证码',authenticator:'Authenticator 动态码',passkey:'系统通行密钥'};
const factors = {password:'password',email_code:'email',phone_code:'phone',authenticator:'authenticator',passkey:'passkey'};
export function StepUpFields({methods,excludedFactor,value,onChange,sendStepUpCode,beginStepUpPasskey,disabled=false,verificationError='',description='当前变更项本身不能用于本次校验。'}) {
  const available=methods.filter(method=>factors[method] && factors[method]!==excludedFactor);
  const selected=available.includes(value.method)?value.method:(available[0]||'');
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),[cooldowns,setCooldowns]=useState({});
  useEffect(()=>{if(selected && selected!==value.method) onChange({method:selected,password:'',code:'',response:null});},[selected,value.method,onChange]);
  const cooldown=cooldowns[selected]||0;
  const cooling=Object.values(cooldowns).some(value=>value>0);
  useEffect(()=>{if(!cooling)return;const timer=setInterval(()=>setCooldowns(values=>Object.fromEntries(Object.entries(values).map(([method,value])=>[method,Math.max(0,value-1)]))),1000);return()=>clearInterval(timer);},[cooling]);
  const feedback=(verificationError||error)?<Alert tone="danger">{verificationError||error}</Alert>:null;
  async function prepare() {
    if(busy||disabled)return;
    setBusy(true);setError('');onChange({method:selected,password:'',code:'',response:null});
    try {
      if(selected==='passkey') {
        const options=await beginStepUpPasskey(excludedFactor);
        const credential=await navigator.credentials.get({publicKey:preparePublicKeyRequestOptions(options)});
        if(!credential)throw new Error('未获取到通行密钥响应。');
        onChange({method:selected,password:'',code:'',response:serializeAuthenticationCredential(credential)});
      } else {
        const result=await sendStepUpCode(selected,excludedFactor);
        setCooldowns(values=>({...values,[selected]:Math.max(0,Number(result?.retry_after)||0)}));
      }
    } catch(e) {setError(getUserErrorMessage(e,'验证方式准备失败，请重试。'));}
    finally {setBusy(false);}
  }
  if(!available.length)return <Alert tone="warning">当前没有可用的 MFA 验证方式，请先在账户安全中绑定邮箱、手机、验证器或通行密钥。</Alert>;
  const send=<FormaButton type="button" variant="secondary" disabled={busy||disabled||cooldown>0} onClick={()=>void prepare()}>{busy?'发送中…':cooldown>0?`${cooldown} 秒后重发`:'发送验证码'}</FormaButton>;
  return <div className="space-y-3 rounded-panel bg-inset p-4">
    <RosemarySelect label="账户二次验证方式" value={selected} options={available.map(method=>({value:method,label:labels[method]}))} disabled={disabled||busy} onChange={method=>{setError('');onChange({method,password:'',code:'',response:null});}} />
    {selected==='password'?<FormaInput label="当前密码" autoComplete="current-password" type="password" value={value.password||''} disabled={disabled||busy} onChange={e=>onChange({...value,method:selected,password:e.target.value})} verification={feedback}/>
    :selected==='passkey'?<div className="space-y-2"><FormaButton type="button" variant="secondary" disabled={busy||disabled} onClick={()=>void prepare()}>{value.response?'通行密钥响应已就绪':busy?'等待系统验证…':'使用通行密钥验证'}</FormaButton>{feedback}</div>
    :<FormaInput label="身份验证码" autoComplete="one-time-code" inputMode="numeric" value={value.code||''} disabled={disabled||busy} onChange={e=>onChange({...value,method:selected,code:e.target.value})} verification={<div className="space-y-2">{selected!=='authenticator'?send:null}{feedback}</div>}/>}
    <p className="text-sm text-muted">{description}</p>
  </div>;
}
