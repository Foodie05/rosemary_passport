import { FormaButton, FormaInput, FormaLoading } from '../components/Forma';
import { AnimatePresence } from 'motion/react';
import { useEffect, useRef, useState } from 'react';
import QRCode from 'qrcode';
import { KeyRound, Mail, Shield } from '../design/Icons';
import { cleanDisplayName } from '../utils';
import { getUserErrorMessage } from '../lib/errors';
import { cn } from '../lib/utils';
import { NewPasswordField } from '../components/NewPasswordField';
import { evaluatePassword } from '../lib/password-policy';
import { Dialog } from '../components/Dialog';
import { RosemarySelect } from '../components/ui';
import {
  preparePublicKeyCreationOptions,
  preparePublicKeyRequestOptions,
  serializeAuthenticationCredential,
  serializeRegistrationCredential,
} from '../lib/utils';

function StatusBadge({ ready, readyLabel = '已设置', pendingLabel = '待完成' }) {
  return <span className="epass-status" data-ready={ready}><span aria-hidden="true">{ready ? '✓' : '△'}</span>{ready ? readyLabel : pendingLabel}</span>;
}

function Modal({ title, children, onClose, actions }) {
  return <Dialog title={title} onClose={onClose} actions={actions}><div className="space-y-5">{children}</div></Dialog>;
}

function SettingRow({ title, description, ready, readyLabel, pendingLabel, action, onClick }) {
  return <div className="epass-setting-row"><div><div className="epass-setting-title"><h3>{title}</h3>{ready !== undefined && <StatusBadge ready={ready} readyLabel={readyLabel} pendingLabel={pendingLabel} />}</div><p>{description}</p></div><FormaButton type="button" className="btn-secondary" onClick={onClick}>{action}</FormaButton></div>;
}

function LoadingButtonText({ loading, loadingText, idleText }) {
  return loading ? (
    <span className="inline-flex items-center gap-2">
      <FormaLoading />
      <span>{loadingText}</span>
    </span>
  ) : (
    idleText
  );
}

function getPasskeyErrorMessage(error) {
  if (error?.name === 'NotAllowedError' || error?.name === 'AbortError') {
    return '你已取消本次通行密钥操作，或操作已超时。';
  }
  if (
    error?.name === 'InvalidStateError' ||
    error?.message === 'The object is in an invalid state.'
  ) {
    return '这把通行密钥已存在于当前浏览器或钥匙串中，不能重复添加。若需重建，请先移除原有通行密钥后再添加。';
  }
  if (error?.name === 'NotSupportedError') {
    return '当前浏览器或设备不支持通行密钥。';
  }
  if (error?.name === 'SecurityError') {
    return '当前环境不允许使用通行密钥，请检查域名与安全上下文。';
  }
  return getUserErrorMessage(error, '通行密钥连接失败，请重试。');
}

const STEP_UP_LABELS = {
  password: '当前密码',
  email_code: '当前邮箱验证码',
  phone_code: '当前手机验证码',
  authenticator: 'Authenticator 动态码',
  passkey: '系统通行密钥',
};

function StepUpFields({ methods, excludedFactor, value, onChange, sendStepUpCode, beginStepUpPasskey }) {
  const factorByMethod = { password: 'password', email_code: 'email', phone_code: 'phone', authenticator: 'authenticator', passkey: 'passkey' };
  const available = methods.filter((method) => factorByMethod[method] !== excludedFactor);
  const selected = available.includes(value.method) ? value.method : (available[0] || '');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (selected && selected !== value.method) onChange({ method: selected, password: '', code: '', response: null });
  }, [selected, value.method]);

  async function handleAction() {
    setBusy(true);
    setError('');
    try {
      if (selected === 'passkey') {
        const options = await beginStepUpPasskey(excludedFactor);
        const credential = await navigator.credentials.get({ publicKey: preparePublicKeyRequestOptions(options) });
        if (!credential) throw new Error('未获取到通行密钥响应');
        onChange({ method: selected, password: '', code: '', response: serializeAuthenticationCredential(credential) });
      } else {
        await sendStepUpCode(selected, excludedFactor);
      }
    } catch (actionError) {
      setError(getUserErrorMessage(actionError, '验证方式准备失败，请重试。'));
    } finally {
      setBusy(false);
    }
  }

  if (!available.length) return <p className="text-sm text-danger">当前没有可用的其他验证方式，请先绑定一种恢复因素。</p>;
  return (
    <div className="space-y-3 rounded-panel border border-line bg-canvas p-4">
      <label className="text-sm font-bold text-ink">账户二次验证</label>
      <RosemarySelect
        label="账户二次验证方式"
        value={selected}
        options={available.map((method) => ({ value: method, label: STEP_UP_LABELS[method] || method }))}
        onChange={(method) => onChange({ method, password: '', code: '', response: null })}
      />
      {selected === 'password' ? (
        <FormaInput aria-label="当前密码" autoComplete="current-password" className="input-field" type="password" placeholder="输入当前密码" value={value.password || ''} onChange={(event) => onChange({ ...value, method: selected, password: event.target.value })} />
      ) : selected === 'passkey' ? (
        <FormaButton className="btn-secondary w-full" type="button" disabled={busy} onClick={() => void handleAction()}>{value.response ? '通行密钥已验证' : busy ? '等待系统验证...' : '使用通行密钥验证'}</FormaButton>
      ) : (
        <div className="grid grid-cols-[minmax(0,1fr)_auto] gap-2">
          <FormaInput aria-label="身份验证码" autoComplete="one-time-code" className="input-field" inputMode="numeric" placeholder="输入验证码" value={value.code || ''} onChange={(event) => onChange({ ...value, method: selected, code: event.target.value.replace(/\D/g, '') })} />
          {selected !== 'authenticator' ? <FormaButton className="btn-secondary" type="button" disabled={busy} onClick={() => void handleAction()}>{busy ? '发送中...' : '发送'}</FormaButton> : null}
        </div>
      )}
      <p className="text-xs text-muted">当前变更项本身不能用于本次校验。</p>
      {error ? <p className="text-sm text-danger">{error}</p> : null}
    </div>
  );
}

export function UserAccountPage({
  session,
  mustBindEmail,
  updateNicknameSilently,
  sendBindEmailCode,
  bindEmail,
  sendBindPhoneCode,
  bindPhone,
  resetPasswordWithCode,
  beginAuthenticatorSetup,
  verifyAuthenticatorSetup,
  beginWebAuthnRegistration,
  verifyWebAuthnRegistration,
  listWebAuthnCredentials,
  deleteWebAuthnCredential,
  sendStepUpCode,
  beginStepUpPasskey,
}) {
  const displayName = cleanDisplayName(session.user?.nickname, session.user?.email || '-');
  const [nickname, setNickname] = useState(displayName);
  const [editingNickname, setEditingNickname] = useState(false);
  const [bindModalOpen, setBindModalOpen] = useState(false);
  const [bindPhoneModalOpen, setBindPhoneModalOpen] = useState(false);
  const [resetModalOpen, setResetModalOpen] = useState(false);
  const [authenticatorModalOpen, setAuthenticatorModalOpen] = useState(false);
  const [passkeyModalOpen, setPasskeyModalOpen] = useState(false);
  const [stepUp, setStepUp] = useState({ method: 'password', password: '', code: '', response: null });
  const [bindForm, setBindForm] = useState({ email: '', current_password: '', email_code: '' });
  const [bindPhoneForm, setBindPhoneForm] = useState({ phone_number: '', current_password: '', verify_code: '' });
  const [resetForm, setResetForm] = useState({ new_password: '', email_code: '' });
  const [authenticatorForm, setAuthenticatorForm] = useState({ current_password: '', code: '' });
  const [bindError, setBindError] = useState('');
  const [bindPhoneError, setBindPhoneError] = useState('');
  const [resetError, setResetError] = useState('');
  const [authenticatorError, setAuthenticatorError] = useState('');
  const [passkeyError, setPasskeyError] = useState('');
  const [bindCodeSent, setBindCodeSent] = useState(false);
  const [bindPhoneCodeSent, setBindPhoneCodeSent] = useState(false);
  const [bindSending, setBindSending] = useState(false);
  const [bindPhoneSending, setBindPhoneSending] = useState(false);
  const [bindSaving, setBindSaving] = useState(false);
  const [bindPhoneSaving, setBindPhoneSaving] = useState(false);
  const [resetSaving, setResetSaving] = useState(false);
  const [authenticatorSettingUp, setAuthenticatorSettingUp] = useState(false);
  const [authenticatorSaving, setAuthenticatorSaving] = useState(false);
  const [passkeySaving, setPasskeySaving] = useState(false);
  const [passkeyLoading, setPasskeyLoading] = useState(false);
  const [passkeyRemovingId, setPasskeyRemovingId] = useState('');
  const [bindCooldownRemaining, setBindCooldownRemaining] = useState(0);
  const [bindPhoneCooldownRemaining, setBindPhoneCooldownRemaining] = useState(0);
  const [authenticatorSecret, setAuthenticatorSecret] = useState('');
  const [authenticatorOtpAuthUri, setAuthenticatorOtpAuthUri] = useState('');
  const [authenticatorQrDataUrl, setAuthenticatorQrDataUrl] = useState('');
  const [passkeyCredentials, setPasskeyCredentials] = useState([]);
  const [passkeyMaxCount, setPasskeyMaxCount] = useState(5);
  const nicknameRef = useRef(null);

  function openSecurityModal(setOpen) {
    setStepUp({ method: 'password', password: '', code: '', response: null });
    setOpen(true);
  }

  const hasAuthenticator = Boolean(session.security?.has_authenticator);
  const hasPasskey = Boolean(session.security?.has_passkey);
  const passkeyCount = passkeyCredentials.length;
  const passkeyLimitReached = passkeyCount >= passkeyMaxCount;
  const stepUpMethods = session.security?.step_up_methods || ['password'];
  const stepUpReady = Boolean(stepUp.method === 'password' ? stepUp.password : stepUp.method === 'passkey' ? stepUp.response : stepUp.code);
  const bindSendDisabled =
    bindSending ||
    bindCooldownRemaining > 0 ||
    !bindForm.email.trim() ||
    !stepUpReady;
  const bindPhoneSendDisabled =
    bindPhoneSending ||
    bindPhoneCooldownRemaining > 0 ||
    !bindPhoneForm.phone_number.trim() ||
    !stepUpReady;

  useEffect(() => {
    if (bindCooldownRemaining <= 0) {
      return undefined;
    }
    const timer = window.setInterval(() => {
      setBindCooldownRemaining((current) => (current > 1 ? current - 1 : 0));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [bindCooldownRemaining]);

  useEffect(() => {
    if (bindPhoneCooldownRemaining <= 0) {
      return undefined;
    }
    const timer = window.setInterval(() => {
      setBindPhoneCooldownRemaining((current) => (current > 1 ? current - 1 : 0));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [bindPhoneCooldownRemaining]);

  useEffect(() => {
    setNickname(displayName);
  }, [displayName]);

  useEffect(() => {
    if (editingNickname && nicknameRef.current) {
      nicknameRef.current.focus();
      nicknameRef.current.select();
    }
  }, [editingNickname]);

  useEffect(() => {
    if (!authenticatorOtpAuthUri) {
      setAuthenticatorQrDataUrl('');
      return undefined;
    }
    let cancelled = false;
    void QRCode.toDataURL(authenticatorOtpAuthUri, { width: 192, margin: 1 }).then((dataUrl) => {
      if (!cancelled) {
        setAuthenticatorQrDataUrl(dataUrl);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [authenticatorOtpAuthUri]);

  useEffect(() => {
    if (!passkeyModalOpen) {
      return;
    }
    void loadPasskeys();
  }, [passkeyModalOpen]);

  async function handleNicknameBlur() {
    setEditingNickname(false);
    const next = nickname.trim();
    if (!next || next === displayName) {
      setNickname(displayName);
      return;
    }
    try {
      await updateNicknameSilently(next);
    } catch (_) {
      setNickname(displayName);
    }
  }

  async function handleSendBindCode() {
    setBindError('');
    setBindSending(true);
    try {
      const result = await sendBindEmailCode(bindForm);
      setBindCodeSent(true);
      setBindCooldownRemaining(Math.max(0, Number(result?.retry_after || 0)));
    } catch (error) {
      setBindError(getUserErrorMessage(error, '发送失败，请稍后重试。'));
    } finally {
      setBindSending(false);
    }
  }

  async function handleConfirmBindEmail() {
    setBindError('');
    setBindSaving(true);
    try {
      await bindEmail({ ...bindForm, verification: stepUp });
      setBindModalOpen(false);
      setBindCodeSent(false);
      setBindForm({ email: '', current_password: '', email_code: '' });
    } catch (error) {
      setBindError(getUserErrorMessage(error, '绑定失败，请稍后重试。'));
    } finally {
      setBindSaving(false);
    }
  }

  async function handleSendBindPhoneCode() {
    setBindPhoneError('');
    setBindPhoneSending(true);
    try {
      await sendBindPhoneCode(bindPhoneForm);
      setBindPhoneCodeSent(true);
      setBindPhoneCooldownRemaining(60);
    } catch (error) {
      setBindPhoneError(getUserErrorMessage(error, '验证码发送失败，请稍后重试。'));
    } finally {
      setBindPhoneSending(false);
    }
  }

  async function handleConfirmBindPhone() {
    setBindPhoneError('');
    setBindPhoneSaving(true);
    try {
      await bindPhone({ ...bindPhoneForm, verification: stepUp });
      setBindPhoneModalOpen(false);
      setBindPhoneCodeSent(false);
      setBindPhoneForm({ phone_number: '', current_password: '', verify_code: '' });
    } catch (error) {
      setBindPhoneError(getUserErrorMessage(error, '绑定失败，请稍后重试。'));
    } finally {
      setBindPhoneSaving(false);
    }
  }

  async function handleResetPassword() {
    setResetError('');
    setResetSaving(true);
    try {
      await resetPasswordWithCode({ ...resetForm, verification: stepUp });
      setResetModalOpen(false);
      setResetForm({ new_password: '', email_code: '' });
    } catch (error) {
      setResetError(getUserErrorMessage(error, '重置失败，请稍后重试。'));
    } finally {
      setResetSaving(false);
    }
  }

  async function handleBeginAuthenticatorSetup() {
    setAuthenticatorError('');
    setAuthenticatorSettingUp(true);
    try {
      const payload = await beginAuthenticatorSetup({});
      setAuthenticatorSecret(payload.secret || '');
      setAuthenticatorOtpAuthUri(payload.otpauth_uri || '');
    } catch (error) {
      setAuthenticatorError(getUserErrorMessage(error, '初始化失败，请稍后重试。'));
    } finally {
      setAuthenticatorSettingUp(false);
    }
  }

  async function loadPasskeys() {
    setPasskeyLoading(true);
    setPasskeyError('');
    try {
      const payload = await listWebAuthnCredentials();
      setPasskeyCredentials(payload.credentials || []);
      setPasskeyMaxCount(Number(payload.max_count || 5));
    } catch (error) {
      setPasskeyError(getUserErrorMessage(error, '读取失败，请稍后重试。'));
    } finally {
      setPasskeyLoading(false);
    }
  }

  async function handleVerifyAuthenticator() {
    setAuthenticatorError('');
    setAuthenticatorSaving(true);
    try {
      await verifyAuthenticatorSetup({
        secret: authenticatorSecret,
        code: authenticatorForm.code,
        verification: stepUp,
      });
      setAuthenticatorModalOpen(false);
      setAuthenticatorForm({ current_password: '', code: '' });
      setAuthenticatorSecret('');
      setAuthenticatorOtpAuthUri('');
    } catch (error) {
      setAuthenticatorError(getUserErrorMessage(error, '启用失败，请稍后重试。'));
    } finally {
      setAuthenticatorSaving(false);
    }
  }

  async function handleRegisterPasskey() {
    setPasskeyError('');
    setPasskeySaving(true);
    try {
      if (passkeyLimitReached) {
        throw new Error(`最多只能创建 ${passkeyMaxCount} 个系统通行密钥`);
      }
      const options = await beginWebAuthnRegistration({
        verification: stepUp,
      });
      const credential = await navigator.credentials.create({
        publicKey: preparePublicKeyCreationOptions(options),
      });
      if (!credential) {
        throw new Error('未获取到系统通行密钥响应');
      }
      await verifyWebAuthnRegistration({
        response: serializeRegistrationCredential(credential),
      });
      await loadPasskeys();
    } catch (error) {
      setPasskeyError(getPasskeyErrorMessage(error));
    } finally {
      setPasskeySaving(false);
    }
  }

  async function handleDeletePasskey(credentialId) {
    setPasskeyError('');
    setPasskeyRemovingId(credentialId);
    try {
      await deleteWebAuthnCredential(credentialId, stepUp);
      await loadPasskeys();
    } catch (error) {
      setPasskeyError(getUserErrorMessage(error, '移除失败，请稍后重试。'));
    } finally {
      setPasskeyRemovingId('');
    }
  }

  return (
    <div>
      <header className="epass-page-heading"><p className="epass-eyebrow">YOUR ACCOUNT</p><h1>账户与安全</h1><p>管理个人资料、登录方式与账户恢复设置。</p></header>
      <section className="epass-account-profile" aria-label="个人资料">
        <div className="epass-avatar" aria-hidden="true">{(session.user?.email || 'R').charAt(0).toUpperCase()}</div>
        <div className="min-w-0 flex-1">
          {editingNickname ? <FormaInput ref={nicknameRef} aria-label="昵称" className="input-field max-w-sm" value={nickname} onChange={(event) => setNickname(event.target.value)} onBlur={() => void handleNicknameBlur()} onKeyDown={(event) => { if (event.key === 'Enter') event.currentTarget.blur(); }} /> : <FormaButton type="button" onClick={() => setEditingNickname(true)} className="text-left text-xl font-semibold break-all" aria-label={`编辑昵称：${displayName}`}>{displayName}<span className="ml-3 text-xs font-normal text-muted">编辑</span></FormaButton>}
          <p className="mt-2 break-all text-sm text-muted">{session.user?.email || session.user?.phone_number || '尚未绑定联系方式'}</p>
          <p className="mt-1 break-all font-mono text-xs text-muted">UID · {session.user?.id || '-'}</p>
        </div>
      </section>
      <div className="grid gap-12 pt-8 lg:grid-cols-[minmax(0,1fr)_256px]">
        <div>
          <section aria-labelledby="login-security"><h2 id="login-security" className="font-editorial text-2xl">登录与验证</h2>
            <div className="epass-settings-list">
              <SettingRow title="账户密码" description="验证身份后，为账户设置新密码。" action="重置密码" onClick={() => openSecurityModal(setResetModalOpen)} />
              <SettingRow title="通行密钥" description="使用指纹、人脸或设备凭据登录。" ready={hasPasskey} readyLabel={`${passkeyCount || 1} 已连接`} pendingLabel="未设置" action={hasPasskey ? '管理通行密钥' : '添加通行密钥'} onClick={() => openSecurityModal(setPasskeyModalOpen)} />
              <SettingRow title="验证器" description="使用验证器应用生成的动态验证码。" ready={hasAuthenticator} readyLabel="已连接" pendingLabel="未设置" action={hasAuthenticator ? '更新验证器' : '设置验证器'} onClick={() => openSecurityModal(setAuthenticatorModalOpen)} />
            </div>
          </section>
          <section className="mt-10" aria-labelledby="recovery"><h2 id="recovery" className="font-editorial text-2xl">联系与恢复</h2>
            <div className="epass-settings-list">
              <SettingRow title="邮箱" description={session.user?.email || '绑定邮箱，用于接收验证码和恢复账户。'} ready={!mustBindEmail} readyLabel="已绑定" pendingLabel="待绑定" action={session.user?.email ? '更换邮箱' : '绑定邮箱'} onClick={() => openSecurityModal(setBindModalOpen)} />
              <SettingRow title="手机号" description={session.user?.phone_number || '绑定手机号，用于短信验证。'} ready={Boolean(session.user?.phone_number)} readyLabel="已绑定" pendingLabel="未绑定" action={session.user?.phone_number ? '更换手机号' : '绑定手机号'} onClick={() => openSecurityModal(setBindPhoneModalOpen)} />
            </div>
          </section>
        </div>
        <aside className="space-y-6">
          <div className="rounded-panel border border-line p-6"><Shield size={20} className="mb-4 text-accent" aria-hidden="true" /><h2 className="font-semibold">安全提示</h2><p className="mt-3 text-sm text-muted">{mustBindEmail ? '请先绑定邮箱，以便接收验证码和恢复账户。' : '保持恢复方式可用，避免更换设备后无法登录。'}</p><p className="mt-3 text-sm text-muted">修改安全设置时，需要使用其他已绑定方式验证身份。</p></div>
          <p className="text-xs text-muted">账户角色 · {(session.user?.roles || []).join(' · ') || '普通用户'}</p>
        </aside>
      </div>

      <AnimatePresence>{bindModalOpen && (
        <Modal key="bindModalOpen"
          title="绑定邮箱"
          onClose={() => {
            setBindModalOpen(false);
            setBindError('');
            setBindCodeSent(false);
          }}
          actions={
            <>
              <FormaButton type="button" onClick={handleSendBindCode} className="btn-secondary" disabled={bindSendDisabled}>
                <LoadingButtonText loading={bindSending} loadingText="发送中..." idleText={bindCooldownRemaining > 0 ? `${bindCooldownRemaining} 秒后重发` : '发送验证码'} />
              </FormaButton>
              <FormaButton type="button" onClick={handleConfirmBindEmail} className="btn-primary" disabled={bindSaving || !bindCodeSent || !bindForm.email_code}>
                <LoadingButtonText loading={bindSaving} loadingText="绑定中..." idleText="完成绑定" />
              </FormaButton>
            </>
          }
        >
          <div className="space-y-2">
            <label htmlFor="epass-userpages-field-1" className="text-sm font-bold text-ink">新邮箱</label>
            <FormaInput id="epass-userpages-field-1" className="input-field" type="email" value={bindForm.email} onChange={(event) => setBindForm((current) => ({ ...current, email: event.target.value }))} />
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="email" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          <div className="space-y-2">
            <label htmlFor="epass-userpages-field-2" className="text-sm font-bold text-ink">邮箱验证码</label>
            <FormaInput id="epass-userpages-field-2" className="input-field" value={bindForm.email_code} onChange={(event) => setBindForm((current) => ({ ...current, email_code: event.target.value }))} />
          </div>
          <p className="text-xs text-muted">发送成功后，这个邮箱会进入共享发码冷却；在倒计时结束前不能再次发送。</p>
          {bindError ? <p className="text-sm text-danger">{bindError}</p> : null}
        </Modal>
      )}</AnimatePresence>

      <AnimatePresence>{bindPhoneModalOpen && (
        <Modal key="bindPhoneModalOpen"
          title="绑定手机号"
          onClose={() => {
            setBindPhoneModalOpen(false);
            setBindPhoneError('');
            setBindPhoneCodeSent(false);
          }}
          actions={
            <>
              <FormaButton type="button" onClick={handleSendBindPhoneCode} className="btn-secondary" disabled={bindPhoneSendDisabled}>
                <LoadingButtonText loading={bindPhoneSending} loadingText="发送中..." idleText={bindPhoneCooldownRemaining > 0 ? `${bindPhoneCooldownRemaining} 秒后重发` : '发送验证码'} />
              </FormaButton>
              <FormaButton type="button" onClick={handleConfirmBindPhone} className="btn-primary" disabled={bindPhoneSaving || !bindPhoneCodeSent || !bindPhoneForm.verify_code}>
                <LoadingButtonText loading={bindPhoneSaving} loadingText="绑定中..." idleText="完成绑定" />
              </FormaButton>
            </>
          }
        >
          <div className="space-y-2">
            <label htmlFor="epass-userpages-field-3" className="text-sm font-bold text-ink">手机号</label>
            <FormaInput id="epass-userpages-field-3" className="input-field" value={bindPhoneForm.phone_number} onChange={(event) => setBindPhoneForm((current) => ({ ...current, phone_number: event.target.value.replace(/[^\d+]/g, '') }))} />
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="phone" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          <div className="space-y-2">
            <label htmlFor="epass-userpages-field-4" className="text-sm font-bold text-ink">短信验证码</label>
            <FormaInput id="epass-userpages-field-4" className="input-field" value={bindPhoneForm.verify_code} onChange={(event) => setBindPhoneForm((current) => ({ ...current, verify_code: event.target.value.replace(/\D/g, '') }))} />
          </div>
          {bindPhoneError ? <p className="text-sm text-danger">{bindPhoneError}</p> : null}
        </Modal>
      )}</AnimatePresence>

      <AnimatePresence>{resetModalOpen && (
        <Modal key="resetModalOpen"
          title="重置密码"
          onClose={() => {
            setResetModalOpen(false);
            setResetError('');
            setStepUp({ method: 'password', password: '', code: '', response: null });
          }}
          actions={
            <FormaButton type="button" onClick={handleResetPassword} className="btn-primary" disabled={resetSaving || !stepUpReady || !evaluatePassword(resetForm.new_password).ok}>
              <LoadingButtonText loading={resetSaving} loadingText="重置中..." idleText="重置密码" />
            </FormaButton>
          }
        >
          <div className="rounded-panel border border-line bg-canvas p-4 text-sm text-muted">
            可使用当前邮箱、手机、Authenticator 或通行密钥中任意一种完成校验。
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="password" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          <NewPasswordField label="新密码" value={resetForm.new_password} onChange={(event) => setResetForm((current) => ({ ...current, new_password: event.target.value }))} />
          {resetError ? <p className="text-sm text-danger">{resetError}</p> : null}
        </Modal>
      )}</AnimatePresence>

      <AnimatePresence>{passkeyModalOpen && (
        <Modal key="passkeyModalOpen"
          title="系统通行密钥"
          onClose={() => {
            setPasskeyModalOpen(false);
            setPasskeyError('');
            setStepUp({ method: 'password', password: '', code: '', response: null });
          }}
          actions={
            <FormaButton type="button" onClick={handleRegisterPasskey} className="btn-primary" disabled={passkeySaving || passkeyLimitReached || !stepUpReady}>
              <LoadingButtonText loading={passkeySaving} loadingText="等待系统验证..." idleText={passkeyLimitReached ? '已达上限' : '新增通行密钥'} />
            </FormaButton>
          }
        >
          <div className="rounded-panel border border-line bg-canvas p-4 text-sm text-muted">
            最多可连接 5 个系统通行密钥。连接时会调用浏览器和操作系统提供的 WebAuthn 服务，通过指纹、人脸或设备凭据完成注册。
          </div>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-sm font-bold text-ink">已连接通行密钥</label>
              <span className="text-xs font-medium text-muted">{passkeyCount} / {passkeyMaxCount}</span>
            </div>
            <div className="space-y-2">
              {passkeyLoading ? (
                <div className="rounded-panel border border-line bg-canvas p-4 text-sm text-muted">读取中...</div>
              ) : passkeyCredentials.length ? (
                passkeyCredentials.map((credential) => (
                  <div key={credential.credential_id} className="flex flex-col items-stretch gap-4 rounded-panel border border-line bg-canvas p-4 min-[400px]:flex-row min-[400px]:items-center min-[400px]:justify-between">
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-ink">
                        {credential.device_type === 'platform' ? '本机设备通行密钥' : '外部设备通行密钥'}
                      </p>
                      <p className="mt-1 truncate text-xs text-muted">{credential.credential_id}</p>
                    </div>
                    <FormaButton
                      type="button"
                      onClick={() => void handleDeletePasskey(credential.credential_id)}
                      className="btn-secondary px-3 py-2"
                      disabled={passkeyRemovingId === credential.credential_id || !stepUpReady}
                    >
                      <LoadingButtonText
                        loading={passkeyRemovingId === credential.credential_id}
                        loadingText="移除中..."
                        idleText="移除"
                      />
                    </FormaButton>
                  </div>
                ))
              ) : (
                <div className="rounded-panel border border-dashed border-line bg-canvas p-4 text-sm text-muted">
                  当前还没有已连接的系统通行密钥。
                </div>
              )}
            </div>
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="passkey" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          {passkeyError ? <p className="text-sm text-danger">{passkeyError}</p> : null}
        </Modal>
      )}</AnimatePresence>

      <AnimatePresence>{authenticatorModalOpen && (
        <Modal key="authenticatorModalOpen"
          title={hasAuthenticator ? '更新 Authenticator 验证器' : '设置 Authenticator 验证器'}
          onClose={() => {
            setAuthenticatorModalOpen(false);
            setAuthenticatorError('');
            setAuthenticatorForm({ current_password: '', code: '' });
            setAuthenticatorSecret('');
            setAuthenticatorOtpAuthUri('');
          }}
          actions={
            <>
              {!authenticatorSecret ? (
                <FormaButton type="button" onClick={handleBeginAuthenticatorSetup} className="btn-secondary" disabled={authenticatorSettingUp}>
                  <LoadingButtonText loading={authenticatorSettingUp} loadingText="初始化中..." idleText="显示新验证器" />
                </FormaButton>
              ) : null}
              <FormaButton type="button" onClick={handleVerifyAuthenticator} className="btn-primary" disabled={authenticatorSaving || !authenticatorSecret || !authenticatorForm.code || !stepUpReady}>
                <LoadingButtonText loading={authenticatorSaving} loadingText="验证中..." idleText={hasAuthenticator ? '更新验证器' : '完成设置'} />
              </FormaButton>
            </>
          }
        >
          <div className="rounded-panel border border-line bg-canvas p-4 text-sm text-muted">
            新验证器动态码只证明新配置可用；账户校验必须使用验证器以外的因素。
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="authenticator" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          {authenticatorSecret ? (
            <div className="space-y-4 rounded-panel border border-line bg-canvas p-4">
              {authenticatorQrDataUrl ? <img src={authenticatorQrDataUrl} alt="Authenticator QR" className="aspect-square h-auto w-40 max-w-full rounded-control border border-line bg-surface p-2" /> : null}
              <div className="space-y-1 text-sm text-muted">
                <p className="font-semibold text-ink">手动输入密钥</p>
                <p className="break-all font-mono text-xs text-ink">{authenticatorSecret}</p>
              </div>
            </div>
          ) : null}
          {authenticatorSecret ? (
            <div className="space-y-2">
              <label htmlFor="epass-userpages-field-6" className="text-sm font-bold text-ink">Authenticator 动态验证码</label>
              <FormaInput id="epass-userpages-field-6" className="input-field" inputMode="numeric" value={authenticatorForm.code} onChange={(event) => setAuthenticatorForm((current) => ({ ...current, code: event.target.value.replace(/\D/g, '') }))} />
            </div>
          ) : null}
          {authenticatorError ? <p className="text-sm text-danger">{authenticatorError}</p> : null}
        </Modal>
      )}</AnimatePresence>
    </div>
  );
}
