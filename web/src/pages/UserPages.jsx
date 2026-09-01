import { useEffect, useRef, useState } from 'react';
import QRCode from 'qrcode';
import { KeyRound, Mail, Shield } from 'lucide-react';
import { cleanDisplayName } from '../utils';
import { getUserErrorMessage } from '../lib/errors';
import { cn } from '../lib/utils';
import {
  preparePublicKeyCreationOptions,
  preparePublicKeyRequestOptions,
  serializeAuthenticationCredential,
  serializeRegistrationCredential,
} from '../lib/utils';

function StatusBadge({ ready, readyLabel = '已设置', pendingLabel = '待完成' }) {
  return (
    <span
      className={cn(
        'rounded-full px-2 py-1 text-[10px] font-bold uppercase tracking-wide',
        ready ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700',
      )}
    >
      {ready ? readyLabel : pendingLabel}
    </span>
  );
}

function Modal({ title, children, onClose, actions }) {
  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-sage-900/20 p-3 backdrop-blur-sm sm:items-center sm:p-6">
      <div className="glass-card my-auto flex max-h-[calc(100dvh-1.5rem)] w-full max-w-lg flex-col overflow-hidden rounded-3xl shadow-2xl shadow-sage-900/10 sm:max-h-[calc(100dvh-3rem)] sm:rounded-[2rem]">
        <div className="flex shrink-0 items-center justify-between gap-4 border-b border-sage-100 px-5 py-4 sm:px-8 sm:py-5">
          <h3 className="text-xl font-bold text-sage-900">{title}</h3>
          <button type="button" onClick={onClose} className="rounded-xl px-3 py-2 text-sm font-medium text-sage-500 hover:bg-sage-100 hover:text-sage-900">
            关闭
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-5 sm:px-8 sm:py-6">
          <div className="space-y-5">{children}</div>
        </div>
        <div className="flex shrink-0 flex-col-reverse gap-3 border-t border-sage-100 px-5 py-4 [&>*]:w-full sm:flex-row sm:justify-end sm:px-8 sm:[&>*]:w-auto">{actions}</div>
      </div>
    </div>
  );
}

function LoadingButtonText({ loading, loadingText, idleText }) {
  return loading ? (
    <span className="inline-flex items-center gap-2">
      <span className="loading-spinner" aria-hidden="true" />
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

  if (!available.length) return <p className="text-sm text-red-600">当前没有可用的其他验证方式，请先绑定一种恢复因素。</p>;
  return (
    <div className="space-y-3 rounded-2xl border border-sage-100 bg-sage-50/70 p-4">
      <label className="text-sm font-bold text-sage-700">账户二次验证</label>
      <select className="input-field" value={selected} onChange={(event) => onChange({ method: event.target.value, password: '', code: '', response: null })}>
        {available.map((method) => <option key={method} value={method}>{STEP_UP_LABELS[method] || method}</option>)}
      </select>
      {selected === 'password' ? (
        <input className="input-field" type="password" placeholder="输入当前密码" value={value.password || ''} onChange={(event) => onChange({ ...value, method: selected, password: event.target.value })} />
      ) : selected === 'passkey' ? (
        <button className="btn-secondary w-full" type="button" disabled={busy} onClick={() => void handleAction()}>{value.response ? '通行密钥已验证' : busy ? '等待系统验证...' : '使用通行密钥验证'}</button>
      ) : (
        <div className="grid grid-cols-[minmax(0,1fr)_auto] gap-2">
          <input className="input-field" inputMode="numeric" placeholder="输入验证码" value={value.code || ''} onChange={(event) => onChange({ ...value, method: selected, code: event.target.value.replace(/\D/g, '') })} />
          {selected !== 'authenticator' ? <button className="btn-secondary" type="button" disabled={busy} onClick={() => void handleAction()}>{busy ? '发送中...' : '发送'}</button> : null}
        </div>
      )}
      <p className="text-xs text-sage-500">当前变更项本身不能用于本次校验。</p>
      {error ? <p className="text-sm text-red-600">{error}</p> : null}
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
    <div className="space-y-7 py-2 sm:space-y-10 sm:py-6">
      <div className="flex flex-col items-center gap-5 rounded-3xl border border-white/50 bg-white/40 p-5 shadow-sm sm:gap-8 sm:p-8 md:flex-row md:items-center md:rounded-[2.5rem]">
        <div className="flex h-24 w-24 shrink-0 items-center justify-center rounded-3xl border-4 border-white bg-sage-200 text-3xl font-bold text-sage-700 shadow-xl sm:h-32 sm:w-32 sm:rounded-[2.5rem] sm:text-4xl">
          {(session.user?.email || 'R').charAt(0).toUpperCase()}
        </div>
        <div className="flex-1 space-y-4 text-center md:text-left">
          <div>
            {editingNickname ? (
              <input
                ref={nicknameRef}
                className="w-full max-w-xl border-none bg-transparent p-0 text-2xl font-bold text-sage-900 focus:outline-none sm:text-3xl"
                value={nickname}
                onChange={(event) => setNickname(event.target.value)}
                onBlur={() => void handleNicknameBlur()}
                onKeyDown={(event) => {
                  if (event.key === 'Enter') {
                    event.currentTarget.blur();
                  }
                }}
              />
            ) : (
              <button type="button" onClick={() => setEditingNickname(true)} className="text-center text-2xl font-bold text-sage-900 sm:text-3xl md:text-left">
                {displayName}
              </button>
            )}
            <div className="mt-3 flex min-w-0 flex-wrap items-center justify-center gap-x-3 gap-y-2 text-sage-500 md:justify-start">
              <span className="max-w-full break-all">UID: {session.user?.id || '-'}</span>
              <span aria-hidden="true">·</span>
              <button type="button" onClick={() => openSecurityModal(setBindModalOpen)} className="max-w-full break-all font-medium text-sage-600 hover:text-sage-900">
                {session.user?.email || '-'}
              </button>
            </div>
          </div>
          <div className="flex flex-wrap justify-center gap-2 md:justify-start">
            <StatusBadge ready={!mustBindEmail} readyLabel="已绑定邮箱" pendingLabel="待绑定邮箱" />
            <span className="rounded-full bg-sage-100 px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-sage-600">
              {(session.user?.roles || []).join(' · ') || '普通用户'}
            </span>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-10 lg:grid-cols-[minmax(0,1fr)_360px]">
        <div className="space-y-8">
          <div className="space-y-4">
            <div className="flex items-center gap-2 px-2">
              <KeyRound size={18} className="text-sage-400" />
              <h3 className="text-sm font-bold uppercase tracking-wider text-sage-400">基础操作</h3>
            </div>
            <div className="glass-card overflow-hidden rounded-3xl">
              <div className="flex flex-col items-stretch gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <p className="text-xs font-bold uppercase tracking-tight text-sage-400">重置密码</p>
                  <p className="mt-0.5 text-sm font-semibold text-sage-900">通过邮箱验证码重置当前账户密码</p>
                </div>
                <button type="button" onClick={() => openSecurityModal(setResetModalOpen)} className="btn-primary w-full shrink-0 px-4 py-2.5 sm:w-auto">
                  重置密码
                </button>
              </div>
            </div>
            <div className="glass-card overflow-hidden rounded-3xl">
              <div className="flex flex-col items-stretch gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <p className="text-xs font-bold uppercase tracking-tight text-sage-400">系统通行密钥</p>
                  <p className="mt-0.5 text-sm font-semibold text-sage-900">连接浏览器和操作系统的 WebAuthn 服务，使用指纹、人脸或设备凭据完成验证</p>
                </div>
                <button type="button" onClick={() => openSecurityModal(setPasskeyModalOpen)} className="btn-primary w-full shrink-0 px-4 py-2.5 sm:w-auto">
                  {hasPasskey ? '管理通行密钥' : '连接通行密钥'}
                </button>
              </div>
            </div>
            <div className="glass-card overflow-hidden rounded-3xl">
              <div className="flex flex-col items-stretch gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <p className="text-xs font-bold uppercase tracking-tight text-sage-400">Authenticator 验证器</p>
                  <p className="mt-0.5 text-sm font-semibold text-sage-900">连接 Google Authenticator、1Password 或其他 TOTP 应用作为动态口令验证方式</p>
                </div>
                <button type="button" onClick={() => openSecurityModal(setAuthenticatorModalOpen)} className="btn-primary w-full shrink-0 px-4 py-2.5 sm:w-auto">
                  {hasAuthenticator ? '更新验证器' : '设置验证器'}
                </button>
              </div>
            </div>
          </div>

          <div className="rounded-[2rem] border border-sage-200 bg-sage-100/50 p-6">
            <h3 className="mb-4 flex items-center gap-2 font-bold text-sage-900">
              <Mail size={18} className="text-sage-400" />
              账户提示
            </h3>
            <p className="text-sm leading-relaxed text-sage-600">
              {mustBindEmail
                ? '当前账号需要先完成邮箱绑定，绑定完成后后台高级能力会自动恢复。'
                : '如需更换绑定邮箱，可通过邮箱验证码完成验证与绑定。'}
            </p>
            <div className="mt-6 flex justify-end">
              <div className="flex w-full flex-col gap-3 sm:w-auto sm:flex-row">
                <button type="button" onClick={() => openSecurityModal(setBindModalOpen)} className="btn-primary px-4 py-2.5">
                  绑定邮箱
                </button>
                <button type="button" onClick={() => openSecurityModal(setBindPhoneModalOpen)} className="btn-secondary px-4 py-2.5">
                  绑定手机号
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="space-y-8">
          <div className="glass-card rounded-[2rem] p-6">
            <h3 className="mb-4 flex items-center gap-2 font-bold text-sage-900">
              <Shield size={18} className="text-sage-400" />
              安全状态
            </h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-sage-600">邮箱绑定</span>
                <StatusBadge ready={!mustBindEmail} />
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-sage-600">系统通行密钥</span>
                <StatusBadge ready={hasPasskey} readyLabel={`${passkeyCount || 1} 已连接`} pendingLabel="未连接" />
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-sage-600">Authenticator 验证器</span>
                <StatusBadge ready={hasAuthenticator} readyLabel="已连接" pendingLabel="未连接" />
              </div>
              <div className="flex min-w-0 items-center justify-between gap-3">
                <span className="text-sm text-sage-600">当前邮箱</span>
                <span className="min-w-0 truncate text-right text-sm font-semibold text-sage-900">{session.user?.email || '-'}</span>
              </div>
              <div className="flex min-w-0 items-center justify-between gap-3">
                <span className="text-sm text-sage-600">当前手机号</span>
                <span className="min-w-0 truncate text-right text-sm font-semibold text-sage-900">{session.user?.phone_number || '-'}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {bindModalOpen && (
        <Modal
          title="绑定邮箱"
          onClose={() => {
            setBindModalOpen(false);
            setBindError('');
            setBindCodeSent(false);
          }}
          actions={
            <>
              <button type="button" onClick={handleSendBindCode} className="btn-secondary" disabled={bindSendDisabled}>
                <LoadingButtonText loading={bindSending} loadingText="发送中..." idleText={bindCooldownRemaining > 0 ? `${bindCooldownRemaining} 秒后重发` : '发送验证码'} />
              </button>
              <button type="button" onClick={handleConfirmBindEmail} className="btn-primary" disabled={bindSaving || !bindCodeSent || !bindForm.email_code}>
                <LoadingButtonText loading={bindSaving} loadingText="绑定中..." idleText="完成绑定" />
              </button>
            </>
          }
        >
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">新邮箱</label>
            <input className="input-field" type="email" value={bindForm.email} onChange={(event) => setBindForm((current) => ({ ...current, email: event.target.value }))} />
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="email" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">邮箱验证码</label>
            <input className="input-field" value={bindForm.email_code} onChange={(event) => setBindForm((current) => ({ ...current, email_code: event.target.value }))} />
          </div>
          <p className="text-xs text-sage-500">发送成功后，这个邮箱会进入共享发码冷却；在倒计时结束前不能再次发送。</p>
          {bindError ? <p className="text-sm text-red-600">{bindError}</p> : null}
        </Modal>
      )}

      {bindPhoneModalOpen && (
        <Modal
          title="绑定手机号"
          onClose={() => {
            setBindPhoneModalOpen(false);
            setBindPhoneError('');
            setBindPhoneCodeSent(false);
          }}
          actions={
            <>
              <button type="button" onClick={handleSendBindPhoneCode} className="btn-secondary" disabled={bindPhoneSendDisabled}>
                <LoadingButtonText loading={bindPhoneSending} loadingText="发送中..." idleText={bindPhoneCooldownRemaining > 0 ? `${bindPhoneCooldownRemaining} 秒后重发` : '发送验证码'} />
              </button>
              <button type="button" onClick={handleConfirmBindPhone} className="btn-primary" disabled={bindPhoneSaving || !bindPhoneCodeSent || !bindPhoneForm.verify_code}>
                <LoadingButtonText loading={bindPhoneSaving} loadingText="绑定中..." idleText="完成绑定" />
              </button>
            </>
          }
        >
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">手机号</label>
            <input className="input-field" value={bindPhoneForm.phone_number} onChange={(event) => setBindPhoneForm((current) => ({ ...current, phone_number: event.target.value.replace(/[^\d+]/g, '') }))} />
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="phone" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">短信验证码</label>
            <input className="input-field" value={bindPhoneForm.verify_code} onChange={(event) => setBindPhoneForm((current) => ({ ...current, verify_code: event.target.value.replace(/\D/g, '') }))} />
          </div>
          {bindPhoneError ? <p className="text-sm text-red-600">{bindPhoneError}</p> : null}
        </Modal>
      )}

      {resetModalOpen && (
        <Modal
          title="重置密码"
          onClose={() => {
            setResetModalOpen(false);
            setResetError('');
            setStepUp({ method: 'password', password: '', code: '', response: null });
          }}
          actions={
            <button type="button" onClick={handleResetPassword} className="btn-primary" disabled={resetSaving || !stepUpReady || !resetForm.new_password}>
              <LoadingButtonText loading={resetSaving} loadingText="重置中..." idleText="重置密码" />
            </button>
          }
        >
          <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4 text-sm text-sage-600">
            可使用当前邮箱、手机、Authenticator 或通行密钥中任意一种完成校验。
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="password" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">新密码</label>
            <input className="input-field" type="password" value={resetForm.new_password} onChange={(event) => setResetForm((current) => ({ ...current, new_password: event.target.value }))} />
          </div>
          {resetError ? <p className="text-sm text-red-600">{resetError}</p> : null}
        </Modal>
      )}

      {passkeyModalOpen && (
        <Modal
          title="系统通行密钥"
          onClose={() => {
            setPasskeyModalOpen(false);
            setPasskeyError('');
            setStepUp({ method: 'password', password: '', code: '', response: null });
          }}
          actions={
            <button type="button" onClick={handleRegisterPasskey} className="btn-primary" disabled={passkeySaving || passkeyLimitReached || !stepUpReady}>
              <LoadingButtonText loading={passkeySaving} loadingText="等待系统验证..." idleText={passkeyLimitReached ? '已达上限' : '新增通行密钥'} />
            </button>
          }
        >
          <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4 text-sm text-sage-600">
            最多可连接 5 个系统通行密钥。连接时会调用浏览器和操作系统提供的 WebAuthn 服务，通过指纹、人脸或设备凭据完成注册。
          </div>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-sm font-bold text-sage-700">已连接通行密钥</label>
              <span className="text-xs font-medium text-sage-500">{passkeyCount} / {passkeyMaxCount}</span>
            </div>
            <div className="space-y-2">
              {passkeyLoading ? (
                <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4 text-sm text-sage-500">读取中...</div>
              ) : passkeyCredentials.length ? (
                passkeyCredentials.map((credential) => (
                  <div key={credential.credential_id} className="flex flex-col items-stretch gap-4 rounded-2xl border border-sage-100 bg-sage-50/70 p-4 min-[400px]:flex-row min-[400px]:items-center min-[400px]:justify-between">
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-sage-900">
                        {credential.device_type === 'platform' ? '本机设备通行密钥' : '外部设备通行密钥'}
                      </p>
                      <p className="mt-1 truncate text-xs text-sage-500">{credential.credential_id}</p>
                    </div>
                    <button
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
                    </button>
                  </div>
                ))
              ) : (
                <div className="rounded-2xl border border-dashed border-sage-200 bg-sage-50/60 p-4 text-sm text-sage-500">
                  当前还没有已连接的系统通行密钥。
                </div>
              )}
            </div>
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="passkey" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          {passkeyError ? <p className="text-sm text-red-600">{passkeyError}</p> : null}
        </Modal>
      )}

      {authenticatorModalOpen && (
        <Modal
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
                <button type="button" onClick={handleBeginAuthenticatorSetup} className="btn-secondary" disabled={authenticatorSettingUp}>
                  <LoadingButtonText loading={authenticatorSettingUp} loadingText="初始化中..." idleText="显示新验证器" />
                </button>
              ) : null}
              <button type="button" onClick={handleVerifyAuthenticator} className="btn-primary" disabled={authenticatorSaving || !authenticatorSecret || !authenticatorForm.code || !stepUpReady}>
                <LoadingButtonText loading={authenticatorSaving} loadingText="验证中..." idleText={hasAuthenticator ? '更新验证器' : '完成设置'} />
              </button>
            </>
          }
        >
          <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4 text-sm text-sage-600">
            新验证器动态码只证明新配置可用；账户校验必须使用验证器以外的因素。
          </div>
          <StepUpFields methods={stepUpMethods} excludedFactor="authenticator" value={stepUp} onChange={setStepUp} sendStepUpCode={sendStepUpCode} beginStepUpPasskey={beginStepUpPasskey} />
          {authenticatorSecret ? (
            <div className="space-y-4 rounded-2xl border border-sage-100 bg-sage-50/70 p-4">
              {authenticatorQrDataUrl ? <img src={authenticatorQrDataUrl} alt="Authenticator QR" className="aspect-square h-auto w-40 max-w-full rounded-xl border border-sage-100 bg-white p-2" /> : null}
              <div className="space-y-1 text-sm text-sage-600">
                <p className="font-semibold text-sage-900">手动输入密钥</p>
                <p className="break-all font-mono text-xs text-sage-700">{authenticatorSecret}</p>
              </div>
            </div>
          ) : null}
          {authenticatorSecret ? (
            <div className="space-y-2">
              <label className="text-sm font-bold text-sage-700">Authenticator 动态验证码</label>
              <input className="input-field" inputMode="numeric" value={authenticatorForm.code} onChange={(event) => setAuthenticatorForm((current) => ({ ...current, code: event.target.value.replace(/\D/g, '') }))} />
            </div>
          ) : null}
          {authenticatorError ? <p className="text-sm text-red-600">{authenticatorError}</p> : null}
        </Modal>
      )}
    </div>
  );
}
