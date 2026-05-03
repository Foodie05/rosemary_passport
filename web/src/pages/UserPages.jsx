import { useEffect, useRef, useState } from 'react';
import QRCode from 'qrcode';
import { KeyRound, Mail, Shield } from 'lucide-react';
import { cleanDisplayName } from '../utils';
import { cn } from '../lib/utils';
import {
  preparePublicKeyCreationOptions,
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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-sage-900/20 p-6 backdrop-blur-sm">
      <div className="glass-card w-full max-w-lg rounded-[2rem] p-8 shadow-2xl shadow-sage-900/10">
        <div className="mb-6 flex items-center justify-between gap-4">
          <h3 className="text-xl font-bold text-sage-900">{title}</h3>
          <button type="button" onClick={onClose} className="rounded-xl px-3 py-2 text-sm font-medium text-sage-500 hover:bg-sage-100 hover:text-sage-900">
            关闭
          </button>
        </div>
        <div className="space-y-5">{children}</div>
        <div className="mt-8 flex justify-end gap-3">{actions}</div>
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
  if (error instanceof Error) {
    return error.message;
  }
  return '通行密钥连接失败，请重试。';
}

export function UserAccountPage({
  session,
  mustBindEmail,
  updateNicknameSilently,
  sendBindEmailCode,
  bindEmail,
  sendPasswordResetCode,
  resetPasswordWithCode,
  beginAuthenticatorSetup,
  verifyAuthenticatorSetup,
  beginWebAuthnRegistration,
  verifyWebAuthnRegistration,
  listWebAuthnCredentials,
  deleteWebAuthnCredential,
}) {
  const displayName = cleanDisplayName(session.user?.nickname, session.user?.email || '-');
  const [nickname, setNickname] = useState(displayName);
  const [editingNickname, setEditingNickname] = useState(false);
  const [bindModalOpen, setBindModalOpen] = useState(false);
  const [resetModalOpen, setResetModalOpen] = useState(false);
  const [authenticatorModalOpen, setAuthenticatorModalOpen] = useState(false);
  const [passkeyModalOpen, setPasskeyModalOpen] = useState(false);
  const [bindForm, setBindForm] = useState({ email: '', current_password: '', email_code: '' });
  const [resetForm, setResetForm] = useState({ new_password: '', email_code: '' });
  const [authenticatorForm, setAuthenticatorForm] = useState({ current_password: '', code: '' });
  const [passkeyForm, setPasskeyForm] = useState({ current_password: '' });
  const [bindError, setBindError] = useState('');
  const [resetError, setResetError] = useState('');
  const [authenticatorError, setAuthenticatorError] = useState('');
  const [passkeyError, setPasskeyError] = useState('');
  const [bindCodeSent, setBindCodeSent] = useState(false);
  const [resetCodeSent, setResetCodeSent] = useState(false);
  const [bindSending, setBindSending] = useState(false);
  const [resetSending, setResetSending] = useState(false);
  const [bindSaving, setBindSaving] = useState(false);
  const [resetSaving, setResetSaving] = useState(false);
  const [authenticatorSettingUp, setAuthenticatorSettingUp] = useState(false);
  const [authenticatorSaving, setAuthenticatorSaving] = useState(false);
  const [passkeySaving, setPasskeySaving] = useState(false);
  const [passkeyLoading, setPasskeyLoading] = useState(false);
  const [passkeyRemovingId, setPasskeyRemovingId] = useState('');
  const [bindCooldownRemaining, setBindCooldownRemaining] = useState(0);
  const [resetCooldownRemaining, setResetCooldownRemaining] = useState(0);
  const [authenticatorSecret, setAuthenticatorSecret] = useState('');
  const [authenticatorOtpAuthUri, setAuthenticatorOtpAuthUri] = useState('');
  const [authenticatorQrDataUrl, setAuthenticatorQrDataUrl] = useState('');
  const [passkeyCredentials, setPasskeyCredentials] = useState([]);
  const [passkeyMaxCount, setPasskeyMaxCount] = useState(5);
  const nicknameRef = useRef(null);

  const hasAuthenticator = Boolean(session.security?.has_authenticator);
  const hasPasskey = Boolean(session.security?.has_passkey);
  const passkeyCount = passkeyCredentials.length;
  const passkeyLimitReached = passkeyCount >= passkeyMaxCount;
  const bindSendDisabled =
    bindSending ||
    bindCooldownRemaining > 0 ||
    !bindForm.email.trim() ||
    !bindForm.current_password;
  const resetSendDisabled = resetSending || resetCooldownRemaining > 0;

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
    if (resetCooldownRemaining <= 0) {
      return undefined;
    }
    const timer = window.setInterval(() => {
      setResetCooldownRemaining((current) => (current > 1 ? current - 1 : 0));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [resetCooldownRemaining]);

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
      setBindError(error.message || '发送失败');
    } finally {
      setBindSending(false);
    }
  }

  async function handleConfirmBindEmail() {
    setBindError('');
    setBindSaving(true);
    try {
      await bindEmail(bindForm);
      setBindModalOpen(false);
      setBindCodeSent(false);
      setBindForm({ email: '', current_password: '', email_code: '' });
    } catch (error) {
      setBindError(error.message || '绑定失败');
    } finally {
      setBindSaving(false);
    }
  }

  async function handleSendResetCode() {
    setResetError('');
    setResetSending(true);
    try {
      const result = await sendPasswordResetCode();
      setResetCodeSent(true);
      setResetCooldownRemaining(Math.max(0, Number(result?.retry_after || 0)));
    } catch (error) {
      setResetError(error.message || '发送失败');
    } finally {
      setResetSending(false);
    }
  }

  async function handleResetPassword() {
    setResetError('');
    setResetSaving(true);
    try {
      await resetPasswordWithCode(resetForm);
      setResetModalOpen(false);
      setResetCodeSent(false);
      setResetForm({ new_password: '', email_code: '' });
    } catch (error) {
      setResetError(error.message || '重置失败');
    } finally {
      setResetSaving(false);
    }
  }

  async function handleBeginAuthenticatorSetup() {
    setAuthenticatorError('');
    setAuthenticatorSettingUp(true);
    try {
      const payload = await beginAuthenticatorSetup({
        current_password: authenticatorForm.current_password,
      });
      setAuthenticatorSecret(payload.secret || '');
      setAuthenticatorOtpAuthUri(payload.otpauth_uri || '');
    } catch (error) {
      setAuthenticatorError(error.message || '初始化失败');
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
      setPasskeyError(error.message || '读取失败');
    } finally {
      setPasskeyLoading(false);
    }
  }

  async function handleVerifyAuthenticator() {
    setAuthenticatorError('');
    setAuthenticatorSaving(true);
    try {
      await verifyAuthenticatorSetup({
        current_password: authenticatorForm.current_password,
        secret: authenticatorSecret,
        code: authenticatorForm.code,
      });
      setAuthenticatorModalOpen(false);
      setAuthenticatorForm({ current_password: '', code: '' });
      setAuthenticatorSecret('');
      setAuthenticatorOtpAuthUri('');
    } catch (error) {
      setAuthenticatorError(error.message || '启用失败');
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
        current_password: passkeyForm.current_password,
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
      setPasskeyForm({ current_password: '' });
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
      await deleteWebAuthnCredential(credentialId);
      await loadPasskeys();
    } catch (error) {
      setPasskeyError(error.message || '移除失败');
    } finally {
      setPasskeyRemovingId('');
    }
  }

  return (
    <div className="space-y-10 py-6">
      <div className="flex flex-col gap-8 rounded-[2.5rem] border border-white/50 bg-white/40 p-8 shadow-sm md:flex-row md:items-center">
        <div className="flex h-32 w-32 items-center justify-center rounded-[2.5rem] border-4 border-white bg-sage-200 text-4xl font-bold text-sage-700 shadow-xl">
          {(session.user?.email || 'R').charAt(0).toUpperCase()}
        </div>
        <div className="flex-1 space-y-4 text-center md:text-left">
          <div>
            {editingNickname ? (
              <input
                ref={nicknameRef}
                className="w-full max-w-xl border-none bg-transparent p-0 text-3xl font-bold text-sage-900 focus:outline-none"
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
              <button type="button" onClick={() => setEditingNickname(true)} className="text-left text-3xl font-bold text-sage-900">
                {displayName}
              </button>
            )}
            <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 text-sage-500">
              <span>UID: {session.user?.id || '-'}</span>
              <span>·</span>
              <button type="button" onClick={() => setBindModalOpen(true)} className="font-medium text-sage-600 hover:text-sage-900">
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
              <div className="flex items-center justify-between gap-4 p-5">
                <div>
                  <p className="text-xs font-bold uppercase tracking-tight text-sage-400">重置密码</p>
                  <p className="mt-0.5 text-sm font-semibold text-sage-900">通过邮箱验证码重置当前账户密码</p>
                </div>
                <button type="button" onClick={() => setResetModalOpen(true)} className="btn-primary px-4 py-2.5">
                  重置密码
                </button>
              </div>
            </div>
            <div className="glass-card overflow-hidden rounded-3xl">
              <div className="flex items-center justify-between gap-4 p-5">
                <div>
                  <p className="text-xs font-bold uppercase tracking-tight text-sage-400">系统通行密钥</p>
                  <p className="mt-0.5 text-sm font-semibold text-sage-900">连接浏览器和操作系统的 WebAuthn 服务，使用指纹、人脸或设备凭据完成验证</p>
                </div>
                <button type="button" onClick={() => setPasskeyModalOpen(true)} className="btn-primary px-4 py-2.5">
                  {hasPasskey ? '管理通行密钥' : '连接通行密钥'}
                </button>
              </div>
            </div>
            <div className="glass-card overflow-hidden rounded-3xl">
              <div className="flex items-center justify-between gap-4 p-5">
                <div>
                  <p className="text-xs font-bold uppercase tracking-tight text-sage-400">Authenticator 验证器</p>
                  <p className="mt-0.5 text-sm font-semibold text-sage-900">连接 Google Authenticator、1Password 或其他 TOTP 应用作为动态口令验证方式</p>
                </div>
                <button type="button" onClick={() => setAuthenticatorModalOpen(true)} className="btn-primary px-4 py-2.5">
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
              <button type="button" onClick={() => setBindModalOpen(true)} className="btn-primary px-4 py-2.5">
                绑定邮箱
              </button>
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
              <div className="flex items-center justify-between">
                <span className="text-sm text-sage-600">当前邮箱</span>
                <span className="max-w-[180px] truncate text-sm font-semibold text-sage-900">{session.user?.email || '-'}</span>
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
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">当前密码</label>
            <input className="input-field" type="password" value={bindForm.current_password} onChange={(event) => setBindForm((current) => ({ ...current, current_password: event.target.value }))} />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">邮箱验证码</label>
            <input className="input-field" value={bindForm.email_code} onChange={(event) => setBindForm((current) => ({ ...current, email_code: event.target.value }))} />
          </div>
          <p className="text-xs text-sage-500">发送成功后，这个邮箱会进入共享发码冷却；在倒计时结束前不能再次发送。</p>
          {bindError ? <p className="text-sm text-red-600">{bindError}</p> : null}
        </Modal>
      )}

      {resetModalOpen && (
        <Modal
          title="重置密码"
          onClose={() => {
            setResetModalOpen(false);
            setResetError('');
            setResetCodeSent(false);
          }}
          actions={
            <>
              <button type="button" onClick={handleSendResetCode} className="btn-secondary" disabled={resetSendDisabled}>
                <LoadingButtonText loading={resetSending} loadingText="发送中..." idleText={resetCooldownRemaining > 0 ? `${resetCooldownRemaining} 秒后重发` : '发送验证码'} />
              </button>
              <button type="button" onClick={handleResetPassword} className="btn-primary" disabled={resetSaving || !resetCodeSent || !resetForm.new_password || !resetForm.email_code}>
                <LoadingButtonText loading={resetSaving} loadingText="重置中..." idleText="重置密码" />
              </button>
            </>
          }
        >
          <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4 text-sm text-sage-600">
            验证码会发送到当前绑定邮箱 {session.user?.email || '-'}。
          </div>
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">新密码</label>
            <input className="input-field" type="password" value={resetForm.new_password} onChange={(event) => setResetForm((current) => ({ ...current, new_password: event.target.value }))} />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">邮箱验证码</label>
            <input className="input-field" value={resetForm.email_code} onChange={(event) => setResetForm((current) => ({ ...current, email_code: event.target.value }))} />
          </div>
          <p className="text-xs text-sage-500">发送成功后，这个邮箱会进入共享发码冷却；在倒计时结束前不能再次发送。</p>
          {resetError ? <p className="text-sm text-red-600">{resetError}</p> : null}
        </Modal>
      )}

      {passkeyModalOpen && (
        <Modal
          title="系统通行密钥"
          onClose={() => {
            setPasskeyModalOpen(false);
            setPasskeyError('');
            setPasskeyForm({ current_password: '' });
          }}
          actions={
            <button type="button" onClick={handleRegisterPasskey} className="btn-primary" disabled={passkeySaving || passkeyLimitReached || !passkeyForm.current_password}>
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
                  <div key={credential.credential_id} className="flex items-center justify-between gap-4 rounded-2xl border border-sage-100 bg-sage-50/70 p-4">
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
                      disabled={passkeyRemovingId === credential.credential_id}
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
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">当前密码</label>
            <input className="input-field" type="password" value={passkeyForm.current_password} onChange={(event) => setPasskeyForm((current) => ({ ...current, current_password: event.target.value }))} />
          </div>
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
                <button type="button" onClick={handleBeginAuthenticatorSetup} className="btn-secondary" disabled={authenticatorSettingUp || !authenticatorForm.current_password}>
                  <LoadingButtonText loading={authenticatorSettingUp} loadingText="校验中..." idleText="验证密码" />
                </button>
              ) : null}
              <button type="button" onClick={handleVerifyAuthenticator} className="btn-primary" disabled={authenticatorSaving || !authenticatorSecret || !authenticatorForm.code}>
                <LoadingButtonText loading={authenticatorSaving} loadingText="验证中..." idleText={hasAuthenticator ? '更新验证器' : '完成设置'} />
              </button>
            </>
          }
        >
          <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4 text-sm text-sage-600">
            输入当前密码并通过校验后，会直接显示二维码。此验证器仅保留一个配置，如再次设置会覆盖原有绑定。
          </div>
          <div className="space-y-2">
            <label className="text-sm font-bold text-sage-700">当前密码</label>
            <input className="input-field" type="password" value={authenticatorForm.current_password} onChange={(event) => setAuthenticatorForm((current) => ({ ...current, current_password: event.target.value }))} />
          </div>
          {authenticatorSecret ? (
            <div className="space-y-4 rounded-2xl border border-sage-100 bg-sage-50/70 p-4">
              {authenticatorQrDataUrl ? <img src={authenticatorQrDataUrl} alt="Authenticator QR" className="h-40 w-40 rounded-xl border border-sage-100 bg-white p-2" /> : null}
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
