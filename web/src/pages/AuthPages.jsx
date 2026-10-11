import { Link } from '../design/NavigationMotion';
import { AnimatePresence } from 'motion/react';
import { SelectionGroup, SelectionContent } from '../design/SelectionMotion';
import { useEffect, useId, useState } from 'react';
import { NewPasswordField } from '../components/NewPasswordField';
import { evaluatePassword } from '../lib/password-policy';
import { Dialog } from '../components/Dialog';
import { Brand, BrandDrawing, SiteFooter } from '../components/Brand';
import {
  ArrowRight,
  Eye,
  EyeOff,
  CheckCircle2,
  ChevronLeft,
  Fingerprint,
  Info,
  Lock,
  Mail,
  Smartphone,
  ShieldCheck,
  User,
} from 'lucide-react';
import { useLocation } from 'react-router-dom';
import { ThemeToggle } from '../theme';
import { RosemaryCheckbox } from '../components/ui';
import { getPasskeyErrorMessage, getUserErrorMessage } from '../lib/errors';
import {
  preparePublicKeyRequestOptions,
  serializeAuthenticationCredential,
} from '../lib/utils';

function AuthPageFrame({ children }) {
  return <div className="epass-auth">
    <a href="#auth-main" className="epass-skip">跳到主要内容</a>
    <header className="epass-auth-header"><Brand /><ThemeToggle /></header>
    <main id="auth-main" className="epass-auth-body" tabIndex={-1}>{children}</main>
    <SiteFooter />
  </div>;
}

function AuthInput({ icon: Icon, label, type = 'text', placeholder, value, onChange, ...inputProps }) {
  const id = useId();
  const [visible, setVisible] = useState(false);
  const password = type === 'password';
  const autoComplete = password ? (label.includes('新') || label.includes('设置') ? 'new-password' : 'current-password') : label.includes('验证码') || label.includes('动态码') ? 'one-time-code' : label.includes('邮箱') ? 'email' : label.includes('手机') ? 'tel' : undefined;
  return <div className="epass-auth-field">
    <label htmlFor={id}>{label}</label>
    <div className="relative">
      <Icon className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" size={20} aria-hidden="true" />
      <input id={id} name={inputProps.name || autoComplete || id} type={password && visible ? 'text' : type} autoComplete={autoComplete} placeholder={placeholder} value={value} onChange={onChange} className={`input-field pl-12 ${password ? 'pr-12' : ''}`} {...inputProps} />
      {password && <button type="button" className="epass-password-toggle" aria-label={visible ? '隐藏密码' : '显示密码'} aria-pressed={visible} onClick={() => setVisible(!visible)}>{visible ? <EyeOff size={20} /> : <Eye size={20} />}</button>}
    </div>
  </div>;
}

function CodeInputWithAction({ icon: Icon, label, placeholder, value, onChange, actionLabel, onAction, actionDisabled }) {
  const id = useId();
  return <div className="epass-auth-field">
    <label htmlFor={id}>{label}</label>
    <div className="flex flex-wrap gap-2">
      <div className="relative min-w-0 flex-1 basis-32"><Icon size={20} aria-hidden="true" className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" /><input id={id} name="verification-code" autoComplete="one-time-code" inputMode="numeric" type="text" placeholder={placeholder} value={value} onChange={onChange} className="input-field pl-12" /></div>
      <button type="button" className="btn-secondary" onClick={onAction} disabled={actionDisabled}>{actionLabel}</button>
    </div>
  </div>;
}

function RememberMeCheckbox({ checked, onChange }) {
  return (
    <RosemaryCheckbox checked={checked} onCheckedChange={onChange} className="px-1 text-muted">
      保持登录状态（3 天）
    </RosemaryCheckbox>
  );
}

function LegalAgreementCheckbox({ checked, onChange, documents }) {
  return (
    <div className="flex items-start gap-2.5 px-1 text-sm leading-6 text-muted">
      <RosemaryCheckbox
        checked={checked}
        onCheckedChange={onChange}
        ariaLabel="同意使用条款与隐私政策"
      />
      <span>
        我已阅读并同意
        <Link to="/legal/terms" target="_blank" rel="noopener noreferrer" onClick={(event) => event.stopPropagation()} className="mx-1 font-bold text-ink underline underline-offset-4">《使用条款》</Link>
        与
        <Link to="/legal/privacy" target="_blank" rel="noopener noreferrer" onClick={(event) => event.stopPropagation()} className="mx-1 font-bold text-ink underline underline-offset-4">《隐私政策》</Link>
        {documents?.terms && documents?.privacy ? `（版本 ${documents.terms.version}/${documents.privacy.version}）` : ''}
      </span>
    </div>
  );
}

function AccountCenterLink() {
  return (
    <Link
      to="/account"
      className="mx-auto flex w-fit items-center gap-2 rounded-control px-3 py-2 text-sm font-semibold text-muted transition-colors hover:bg-subtle hover:text-ink"
    >
      账户中心
      <ArrowRight size={15} aria-hidden="true" />
    </Link>
  );
}

function LoadingButtonText({ loading, loadingText, idleText, icon: Icon }) {
  return loading ? (
    <span className="inline-flex items-center gap-2">
      <span className="loading-spinner" aria-hidden="true" />
      <span>{loadingText}</span>
    </span>
  ) : (
    <span className="inline-flex items-center gap-2">
      <span>{idleText}</span>
      {Icon ? <Icon size={20} /> : null}
    </span>
  );
}

function BrandSection() {
  return <aside className="epass-auth-brand" aria-label="关于 Rosemary Epass">
    <span className="epass-eyebrow">YOUR ROSEMARY ACCOUNT</span>
    <h2>一个账户，<br />连接 Rosemary 服务。</h2>
    <p>登录并管理你的账户与安全设置。</p>
    <BrandDrawing />
  </aside>;
}

function FactorListItem({ title, subtitle, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center justify-between rounded-panel border border-line bg-surface px-5 py-4 text-left transition-colors hover:border-control hover:bg-canvas"
    >
      <div className="space-y-1">
        <p className="text-base font-bold text-ink">{title}</p>
        {subtitle ? <p className="text-sm leading-relaxed text-muted">{subtitle}</p> : null}
      </div>
      <ArrowRight size={18} className="text-muted" />
    </button>
  );
}

export function LoginPage({
  loginForm,
  setLoginForm,
  loginMethod,
  setLoginMethod,
  rememberMe,
  setRememberMe,
  loginStep,
  setLoginStep,
  loading,
  loginCodeSending,
  loginCodeCooldownRemaining,
  passwordLoginFactors,
  selectedPasswordFactor,
  setSelectedPasswordFactor,
  selectPasswordFactor,
  prepareLogin,
  completeLogin,
  prepareEmailCodeLogin,
  completeEmailCodeLogin,
  preparePhoneCodeLogin,
  completePhoneCodeLogin,
  selectDirectLoginStepUpFactor,
  completeDirectLoginStepUp,
  beginDirectLoginStepUpPasskey,
  resendPasswordLoginCode,
  resendPasswordPhoneCode,
  resendEmailCodeLogin,
  resendPhoneCodeLogin,
  loadLoginCodeCooldown,
  beginWebAuthnLogin,
  completeWebAuthnLogin,
  legalAccepted,
  setLegalAccepted,
  legalDocuments,
  authNext = '',
}) {
  const [webauthnLoading, setWebauthnLoading] = useState(false);
  const [webauthnError, setWebauthnError] = useState('');

  useEffect(() => {
    if (loginStep !== 'code' || selectedPasswordFactor !== 'email_code') {
      return;
    }
    void loadLoginCodeCooldown?.();
  }, [loginStep, loginForm.email, selectedPasswordFactor, loadLoginCodeCooldown]);

  useEffect(() => {
    setWebauthnError('');
  }, [loginMethod, loginForm.email]);

  function switchTab(nextMethod) {
    if (nextMethod === loginMethod && loginStep === 'credentials') {
      return;
    }
    setLoginMethod(nextMethod);
    setLoginStep('credentials');
    setSelectedPasswordFactor('');
  }

  function switchAccount() {
    setLoginForm({
      email: '',
      phone_number: '',
      password: '',
      email_code: '',
      phone_code: '',
      authenticator_code: '',
    });
    setLoginMethod('phone_code');
    setLoginStep('credentials');
    setSelectedPasswordFactor('');
    setWebauthnError('');
  }

  function renderPanel(view) {
    if (view.step === 'step_up') {
      return (
        <form className="space-y-6" onSubmit={completeDirectLoginStepUp}>
          {!view.selectedPasswordFactor ? (
            <div className="space-y-4">
              {passwordLoginFactors.includes('password') ? (
                <FactorListItem title="账户密码" subtitle="使用当前账户密码完成二次验证" onClick={() => void selectDirectLoginStepUpFactor('password')} />
              ) : null}
              {passwordLoginFactors.includes('email_code') ? (
                <FactorListItem title="邮箱验证码" subtitle="发送验证码到已绑定邮箱" onClick={() => void selectDirectLoginStepUpFactor('email_code')} />
              ) : null}
              {passwordLoginFactors.includes('phone_code') ? (
                <FactorListItem title="手机验证码" subtitle="发送验证码到已绑定手机号" onClick={() => void selectDirectLoginStepUpFactor('phone_code')} />
              ) : null}
              {passwordLoginFactors.includes('authenticator') ? (
                <FactorListItem title="Authenticator 验证器" subtitle="输入验证器当前显示的动态验证码" onClick={() => void selectDirectLoginStepUpFactor('authenticator')} />
              ) : null}
              {passwordLoginFactors.includes('webauthn') ? (
                <FactorListItem title="系统通行密钥" subtitle="使用另一把已绑定的通行密钥验证" onClick={() => void selectDirectLoginStepUpFactor('webauthn')} />
              ) : null}
            </div>
          ) : null}

          {view.selectedPasswordFactor === 'password' ? (
            <AuthInput icon={Lock} label="账户密码" type="password" autoComplete="current-password" value={loginForm.password} onChange={(event) => setLoginForm((current) => ({ ...current, password: event.target.value }))} />
          ) : null}
          {view.selectedPasswordFactor === 'email_code' ? (
            <CodeInputWithAction icon={ShieldCheck} label="邮箱验证码" value={loginForm.email_code} onChange={(event) => setLoginForm((current) => ({ ...current, email_code: event.target.value }))} actionLabel={loginCodeSending ? '发送中...' : '重新发送'} onAction={() => void selectDirectLoginStepUpFactor('email_code')} actionDisabled={loginCodeSending} />
          ) : null}
          {view.selectedPasswordFactor === 'phone_code' ? (
            <CodeInputWithAction icon={ShieldCheck} label="手机验证码" value={loginForm.phone_code} onChange={(event) => setLoginForm((current) => ({ ...current, phone_code: event.target.value.replace(/\D/g, '') }))} actionLabel={loginCodeSending ? '发送中...' : '重新发送'} onAction={() => void selectDirectLoginStepUpFactor('phone_code')} actionDisabled={loginCodeSending} />
          ) : null}
          {view.selectedPasswordFactor === 'authenticator' ? (
            <AuthInput icon={ShieldCheck} label="Authenticator 动态验证码" value={loginForm.authenticator_code} onChange={(event) => setLoginForm((current) => ({ ...current, authenticator_code: event.target.value.replace(/\D/g, '') }))} />
          ) : null}
          {view.selectedPasswordFactor === 'webauthn' ? (
            <button
              type="button"
              disabled={webauthnLoading}
              className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold"
              onClick={async () => {
                setWebauthnLoading(true);
                setWebauthnError('');
                try {
                  const options = await beginDirectLoginStepUpPasskey();
                  const credential = await navigator.credentials.get({ publicKey: preparePublicKeyRequestOptions(options) });
                  if (!credential) throw new Error('未获取到系统通行密钥响应');
                  await completeDirectLoginStepUp(null, serializeAuthenticationCredential(credential));
                } catch (error) {
                  setWebauthnError(getPasskeyErrorMessage(error));
                } finally {
                  setWebauthnLoading(false);
                }
              }}
            >
              <LoadingButtonText loading={webauthnLoading} loadingText="等待系统验证..." idleText="使用系统通行密钥验证" icon={Fingerprint} />
            </button>
          ) : null}
          {webauthnError ? <p className="text-sm text-danger">{webauthnError}</p> : null}
          {view.selectedPasswordFactor && view.selectedPasswordFactor !== 'webauthn' ? (
            <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
              <LoadingButtonText loading={loading} loadingText="验证中..." idleText="完成二次验证" />
            </button>
          ) : null}
          <button type="button" onClick={() => setSelectedPasswordFactor('')} className="flex w-full items-center justify-center gap-2 text-sm font-bold text-muted hover:text-ink">
            <ChevronLeft size={18} />返回验证方式
          </button>
        </form>
      );
    }

    if (view.method === 'phone_code') {
      if (view.step === 'credentials') {
        return (
          <form className="space-y-6" onSubmit={preparePhoneCodeLogin}>
            <AuthInput
              icon={Smartphone}
              label="手机号"
              placeholder="13800138000"
              value={loginForm.phone_number}
              onChange={(event) => setLoginForm((current) => ({ ...current, phone_number: event.target.value.replace(/[^\d+]/g, '') }))}
            />
            <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
              <LoadingButtonText loading={loading} loadingText="发送中..." idleText="发送登录验证码" icon={ArrowRight} />
            </button>
          </form>
        );
      }

      return (
        <form className="space-y-6" onSubmit={completePhoneCodeLogin}>
          <CodeInputWithAction
            icon={ShieldCheck}
            label="手机验证码"
            placeholder="6位验证码"
            value={loginForm.phone_code}
            onChange={(event) => setLoginForm((current) => ({ ...current, phone_code: event.target.value.replace(/\D/g, '') }))}
            actionLabel={loginCodeSending ? '发送中...' : loginCodeCooldownRemaining > 0 ? `${loginCodeCooldownRemaining} 秒后重发` : '发送验证码'}
            onAction={() => void resendPhoneCodeLogin()}
            actionDisabled={loginCodeSending || loginCodeCooldownRemaining > 0}
          />
          <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
            <LoadingButtonText loading={loading} loadingText="登录中..." idleText="完成登录" />
          </button>
        </form>
      );
    }

    if (view.method === 'email_code') {
      if (view.step === 'credentials') {
        return (
          <form className="space-y-6" onSubmit={prepareEmailCodeLogin}>
            <AuthInput
              icon={Mail}
              label="邮箱地址"
              placeholder="name@example.com"
              value={loginForm.email}
              onChange={(event) => setLoginForm((current) => ({ ...current, email: event.target.value }))}
            />

            <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
              <LoadingButtonText loading={loading} loadingText="发送中..." idleText="发送登录验证码" icon={ArrowRight} />
            </button>
          </form>
        );
      }

      return (
        <form className="space-y-6" onSubmit={completeEmailCodeLogin}>
          <CodeInputWithAction
            icon={ShieldCheck}
            label="邮箱验证码"
            placeholder="6位验证码"
            value={loginForm.email_code}
            onChange={(event) => setLoginForm((current) => ({ ...current, email_code: event.target.value }))}
            actionLabel={loginCodeSending ? '发送中...' : loginCodeCooldownRemaining > 0 ? `${loginCodeCooldownRemaining} 秒后重发` : '发送验证码'}
            onAction={() => void resendEmailCodeLogin()}
            actionDisabled={loginCodeSending || loginCodeCooldownRemaining > 0}
          />
          <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
            <LoadingButtonText loading={loading} loadingText="登录中..." idleText="完成登录" />
          </button>
          <button
            type="button"
            onClick={() => {
              if (selectedPasswordFactor) {
                setSelectedPasswordFactor('');
              } else {
                setLoginStep('credentials');
              }
            }}
            className="flex w-full items-center justify-center gap-2 text-sm font-bold text-muted transition-colors hover:text-ink"
          >
            <ChevronLeft size={18} />
            {selectedPasswordFactor ? '返回验证方式' : '返回上一步'}
          </button>
        </form>
      );
    }

    if (view.method === 'webauthn') {
      return (
        <form
          className="space-y-6"
          onSubmit={async (event) => {
            event.preventDefault();
            setWebauthnError('');
            setWebauthnLoading(true);
            try {
              const options = await beginWebAuthnLogin();
              const credential = await navigator.credentials.get({
                publicKey: preparePublicKeyRequestOptions(options),
              });
              if (!credential) {
                throw new Error('未获取到系统通行密钥响应');
              }
              await completeWebAuthnLogin(
                '',
                serializeAuthenticationCredential(credential),
                rememberMe,
              );
            } catch (error) {
              setWebauthnError(getPasskeyErrorMessage(error));
            } finally {
              setWebauthnLoading(false);
            }
          }}
        >
          {webauthnError ? (
            <p className="text-sm text-danger">{webauthnError}</p>
          ) : null}
          <button type="submit" disabled={webauthnLoading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
            <LoadingButtonText loading={webauthnLoading} loadingText="等待系统验证..." idleText="使用系统通行密钥登录" icon={Fingerprint} />
          </button>
        </form>
      );
    }

    if (view.step === 'credentials') {
      return (
        <form className="space-y-6" onSubmit={prepareLogin}>
          <AuthInput
            icon={Mail}
            label="邮箱地址"
            placeholder="name@example.com"
            value={loginForm.email}
            onChange={(event) => setLoginForm((current) => ({ ...current, email: event.target.value }))}
          />
          <AuthInput
            icon={Lock}
            label="密码"
            type="password"
            placeholder="••••••••"
            value={loginForm.password}
            onChange={(event) => setLoginForm((current) => ({ ...current, password: event.target.value }))}
          />

          <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
            <LoadingButtonText loading={loading} loadingText="处理中..." idleText="继续登录" icon={ArrowRight} />
          </button>
        </form>
      );
    }

    return (
      <form className="space-y-6" onSubmit={completeLogin}>
        {!view.selectedPasswordFactor ? (
          <div className="space-y-4">
            {passwordLoginFactors.includes('email_code') ? (
              <FactorListItem
                title="邮箱验证码"
                subtitle="发送一次登录验证码到当前账户邮箱"
                onClick={() => void selectPasswordFactor('email_code')}
              />
            ) : null}
            {passwordLoginFactors.includes('phone_code') ? (
              <FactorListItem
                title="手机验证码"
                subtitle="发送一次登录验证码到当前账户手机号"
                onClick={() => void selectPasswordFactor('phone_code')}
              />
            ) : null}
            {passwordLoginFactors.includes('authenticator') ? (
              <FactorListItem
                title="Authenticator 验证器"
                subtitle="使用动态口令应用当前显示的 6 位验证码"
                onClick={() => void selectPasswordFactor('authenticator')}
              />
            ) : null}
            {passwordLoginFactors.includes('webauthn') ? (
              <FactorListItem
                title="系统通行密钥"
                onClick={() => void selectPasswordFactor('webauthn')}
              />
            ) : null}
          </div>
        ) : null}

        {view.selectedPasswordFactor === 'email_code' ? (
          <>
            <CodeInputWithAction
              icon={ShieldCheck}
              label="邮箱验证码"
              placeholder="6位验证码"
              value={loginForm.email_code}
              onChange={(event) => setLoginForm((current) => ({ ...current, email_code: event.target.value }))}
              actionLabel={loginCodeSending ? '发送中...' : loginCodeCooldownRemaining > 0 ? `${loginCodeCooldownRemaining} 秒后重发` : '发送验证码'}
              onAction={() => void resendPasswordLoginCode()}
              actionDisabled={loginCodeSending || loginCodeCooldownRemaining > 0}
            />
            <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
              <LoadingButtonText loading={loading} loadingText="登录中..." idleText="完成登录" />
            </button>
          </>
        ) : null}

        {view.selectedPasswordFactor === 'authenticator' ? (
          <>
            <AuthInput
              icon={ShieldCheck}
              label="Authenticator 动态验证码"
              placeholder="6位动态验证码"
              value={loginForm.authenticator_code}
              onChange={(event) => setLoginForm((current) => ({ ...current, authenticator_code: event.target.value.replace(/\D/g, '') }))}
            />
            <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
              <LoadingButtonText loading={loading} loadingText="登录中..." idleText="完成登录" />
            </button>
          </>
        ) : null}

        {view.selectedPasswordFactor === 'phone_code' ? (
          <>
            <CodeInputWithAction
              icon={ShieldCheck}
              label="手机验证码"
              placeholder="6位验证码"
              value={loginForm.phone_code}
              onChange={(event) => setLoginForm((current) => ({ ...current, phone_code: event.target.value.replace(/\D/g, '') }))}
              actionLabel={loginCodeSending ? '发送中...' : loginCodeCooldownRemaining > 0 ? `${loginCodeCooldownRemaining} 秒后重发` : '发送验证码'}
              onAction={() => void resendPasswordPhoneCode()}
              actionDisabled={loginCodeSending || loginCodeCooldownRemaining > 0}
            />
            <button type="submit" disabled={loading} className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold">
              <LoadingButtonText loading={loading} loadingText="登录中..." idleText="完成登录" />
            </button>
          </>
        ) : null}

        {view.selectedPasswordFactor === 'webauthn' ? (
          <>
            {webauthnError ? (
              <p className="text-sm text-danger">{webauthnError}</p>
            ) : null}
            <button
              type="button"
              disabled={webauthnLoading}
              onClick={async () => {
                setWebauthnError('');
                setWebauthnLoading(true);
                try {
                  const options = await beginWebAuthnLogin(loginForm.email.trim());
                  const credential = await navigator.credentials.get({
                    publicKey: preparePublicKeyRequestOptions(options),
                  });
                  if (!credential) {
                    throw new Error('未获取到系统通行密钥响应');
                  }
                  await completeWebAuthnLogin(
                    loginForm.email.trim(),
                    serializeAuthenticationCredential(credential),
                    rememberMe,
                  );
                } catch (error) {
                  setWebauthnError(getPasskeyErrorMessage(error));
                } finally {
                  setWebauthnLoading(false);
                }
              }}
              className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-lg font-bold"
            >
              <LoadingButtonText loading={webauthnLoading} loadingText="等待系统验证..." idleText="使用系统通行密钥验证" icon={Fingerprint} />
            </button>
          </>
        ) : null}

        <button
          type="button"
          onClick={() => setLoginStep('credentials')}
          className="flex w-full items-center justify-center gap-2 text-sm font-bold text-muted transition-colors hover:text-ink"
        >
          <ChevronLeft size={18} />
          返回上一步
        </button>
      </form>
    );
  }

  return (
    <AuthPageFrame>
      <div className="epass-auth-grid">
        <BrandSection />

        <div className="epass-auth-panel">
          <div className="mx-auto w-full max-w-md space-y-8">
            <div className="space-y-3">
              <div className="flex items-start justify-between gap-4">
                <div className="space-y-2">
                  <h1 className="text-3xl font-bold text-ink">登录</h1>
                  <p className="text-muted">
                    {loginMethod === 'phone_code'
                      ? '请输入手机号并使用短信验证码完成登录。'
                      : loginStep === 'credentials'
                        ? '选择一种方式，登录 Rosemary Epass。'
                        : '请完成身份验证，继续登录。'}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={switchAccount}
                  className="shrink-0 rounded-control border border-line bg-surface px-3 py-2 text-sm font-semibold text-muted  transition-colors hover:border-control hover:bg-canvas hover:text-ink"
                >
                  切换账号
                </button>
              </div>
              <SelectionGroup value={loginMethod} label="登录方式">
                {[['phone_code', '手机'], ['email_code', '邮箱'], ['webauthn', '通行密钥'], ['password', '密码']].map(([method, label]) => <button key={method} type="button" aria-pressed={loginMethod === method} onClick={() => switchTab(method)}>{label}</button>)}
              </SelectionGroup>
            </div>

            <div className="relative py-1">

                <SelectionContent value={`${loginMethod}:${loginStep}:${selectedPasswordFactor}`} index={['phone_code', 'email_code', 'webauthn', 'password'].indexOf(loginMethod)} className="auth-current-step">
                  {renderPanel({
                    method: loginMethod,
                    step: loginStep,
                    selectedPasswordFactor,
                  })}
                </SelectionContent>

            </div>

            <div className="space-y-4">
              <LegalAgreementCheckbox checked={legalAccepted} onChange={setLegalAccepted} documents={legalDocuments} />
              <div className="flex flex-wrap items-center justify-between gap-3">
                <RememberMeCheckbox checked={rememberMe} onChange={setRememberMe} />
                <p className="text-sm text-muted">
                  还没有账户？
                  {' '}
                  <Link to={authNext ? `/register?next=${encodeURIComponent(authNext)}` : '/register'} className="font-bold text-ink underline-offset-4 hover:underline">
                    立即注册
                  </Link>
                </p>
              </div>

              <Link
                to={authNext ? `/forgot-password?next=${encodeURIComponent(authNext)}` : '/forgot-password'}
                className="group flex w-full items-center justify-between gap-3 px-1 py-1 text-left"
              >
                <span className="min-w-0 text-sm">
                  <span className="font-bold text-ink transition-colors group-hover:text-ink">忘记密码？</span>
                  <span className="ml-2 text-muted">使用已绑定的验证方式重置密码</span>
                </span>
                <ArrowRight size={17} className="shrink-0 text-muted transition-transform group-hover:translate-x-0.5" aria-hidden="true" />
              </Link>

              <AccountCenterLink />
            </div>
          </div>
        </div>
      </div>
    </AuthPageFrame>
  );
}

export function RegisterPage({
  registerForm,
  setRegisterForm,
  registerMethod,
  setRegisterMethod,
  loading,
  registerCodeSending,
  registerCodeCooldownRemaining,
  submitRegister,
  submitRegisterCode,
  captchaRef,
  publicConfig,
  captchaConfigured,
  mountCaptcha,
  legalAccepted,
  setLegalAccepted,
  legalDocuments,
  authNext = '',
}) {
  const location = useLocation();

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const method = params.get('method');
    if (method === 'phone') {
      const phoneNumber = params.get('phone_number') || '';
      setRegisterMethod('phone');
      setRegisterForm((current) => ({ ...current, phone_number: phoneNumber }));
    } else if (method === 'email') {
      const email = params.get('email') || '';
      setRegisterMethod('email');
      setRegisterForm((current) => ({ ...current, email }));
    }
  }, [location.search, setRegisterForm, setRegisterMethod]);
  useEffect(() => {
    mountCaptcha?.();
  }, [mountCaptcha]);

  const registerCodeDisabled =
    registerCodeSending ||
    registerCodeCooldownRemaining > 0 ||
    !(registerMethod === 'phone' ? registerForm.phone_number.trim() : registerForm.email.trim()) ||
    !captchaConfigured;
  const verificationComplete = Boolean(registerForm.registration_handoff);
  const passwordValid = evaluatePassword(registerForm.password).ok;

  return (
    <AuthPageFrame>
    <div className="epass-auth-grid">
      <BrandSection />

      <div className="epass-auth-panel">
        <div className="mx-auto w-full max-w-md space-y-8">
          <div className="space-y-2">
            <h1 className="text-3xl font-bold text-ink">创建新账户</h1>
            <p className="text-muted">支持邮箱或手机号注册，完成验证码验证后即可开始使用。</p>
          </div>

          <SelectionGroup value={registerMethod} label="注册方式" className="!grid-cols-2">
            <button
              type="button"
              disabled={verificationComplete}
              aria-pressed={registerMethod === 'email'}
              onClick={() => setRegisterMethod('email')}
              className={`relative z-10 rounded-control px-4 py-2 text-sm font-bold transition-colors ${registerMethod === 'email' ? 'text-ink' : 'text-muted hover:text-ink'}`}
            >
              邮箱注册
            </button>
            <button
              type="button"
              disabled={verificationComplete}
              aria-pressed={registerMethod === 'phone'}
              onClick={() => setRegisterMethod('phone')}
              className={`relative z-10 rounded-control px-4 py-2 text-sm font-bold transition-colors ${registerMethod === 'phone' ? 'text-ink' : 'text-muted hover:text-ink'}`}
            >
              手机注册
            </button>
          </SelectionGroup>

          <SelectionContent value={registerMethod} index={registerMethod === 'email' ? 0 : 1}><form className="space-y-5" onSubmit={(event) => { if (!passwordValid) { event.preventDefault(); return; } submitRegister(event); }}>
            <AuthInput
              icon={User}
              label="昵称"
              placeholder="张三"
              value={registerForm.nickname}
              onChange={(event) => setRegisterForm((current) => ({ ...current, nickname: event.target.value }))}
            />
            {registerMethod === 'email' ? (
              <AuthInput
                icon={Mail}
                label="邮箱地址"
                placeholder="name@example.com"
                value={registerForm.email}
                disabled={verificationComplete}
                onChange={(event) => setRegisterForm((current) => ({ ...current, email: event.target.value }))}
              />
            ) : (
              <AuthInput
                icon={Smartphone}
                label="手机号码"
                placeholder="13800138000"
                value={registerForm.phone_number}
                disabled={verificationComplete}
                onChange={(event) => setRegisterForm((current) => ({ ...current, phone_number: event.target.value.replace(/[^\d+]/g, '') }))}
              />
            )}
            {verificationComplete ? (
              <div className="rounded-panel border border-line bg-canvas px-4 py-3 text-sm font-bold text-ink">
                验证码已通过，请填写昵称和密码完成注册。
              </div>
            ) : (
            <div className="grid grid-cols-1 gap-3 min-[400px]:grid-cols-[minmax(0,1fr)_auto]">
              <AuthInput
                icon={ShieldCheck}
                label={registerMethod === 'email' ? '邮箱验证码' : '短信验证码'}
                placeholder="输入验证码"
                value={registerMethod === 'email' ? registerForm.email_code : registerForm.phone_code}
                onChange={(event) => setRegisterForm((current) => ({ ...current, [registerMethod === 'email' ? 'email_code' : 'phone_code']: event.target.value }))}
              />
              <button type="button" onClick={() => void submitRegisterCode()} className="btn-secondary whitespace-nowrap px-4 min-[400px]:mt-[30px]" disabled={registerCodeDisabled}>
                <LoadingButtonText
                  loading={registerCodeSending}
                  loadingText="发送中..."
                  idleText={registerCodeCooldownRemaining > 0 ? `${registerCodeCooldownRemaining} 秒后重发` : '发送验证码'}
                />
              </button>
            </div>
            )}
            <NewPasswordField value={registerForm.password} personalInfo={[registerForm.nickname, registerForm.email, registerForm.phone_number]} onChange={(event) => setRegisterForm((current) => ({ ...current, password: event.target.value }))} />

            <div className="space-y-2">
              <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-muted">
                <ShieldCheck size={14} />
                人机验证
              </div>
              <div className="rounded-panel border border-line bg-canvas p-4">
                {captchaConfigured ? (
                  <div className="space-y-3">
                    <div id="aliyun-register-captcha" ref={captchaRef} className="min-h-10" />
                    <p className="text-xs text-muted">发送验证码前需要先完成一次人机验证。</p>
                  </div>
                ) : (
                  <p className="text-sm text-muted">当前不可用</p>
                )}
              </div>
            </div>

            <LegalAgreementCheckbox checked={legalAccepted} onChange={setLegalAccepted} documents={legalDocuments} />

            <button type="submit" disabled={loading || !passwordValid} className="btn-primary w-full py-4 text-lg font-bold">
              <LoadingButtonText loading={loading} loadingText="注册中..." idleText="注册账户" />
            </button>
          </form></SelectionContent>

          <p className="text-center text-sm text-muted">
            已经有账户了？
            {' '}
            <Link to={authNext ? `/login?next=${encodeURIComponent(authNext)}` : '/login'} className="font-bold text-ink underline-offset-4 hover:underline">
              返回登录
            </Link>
          </p>
        </div>
      </div>
    </div>
    </AuthPageFrame>
  );
}

export function ForgotPasswordPage({
  loading,
  sendRecoveryCode,
  resetPasswordByCode,
  beginWebAuthnLogin,
  authNext = '',
}) {
  const [method, setMethod] = useState('email');
  const [step, setStep] = useState('request');
  const [form, setForm] = useState({ account: '', code: '', new_password: '' });
  const [error, setError] = useState('');

  return (
    <AuthPageFrame>
      <div className="epass-auth-grid">
        <BrandSection />
        <div className="epass-auth-panel">
          <SelectionContent value={step} index={['request', 'verify', 'done'].indexOf(step)} className="mx-auto w-full max-w-md">

            {step === 'request' ? (
              <div className="space-y-8">
                <div className="space-y-4 text-center">
                  <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-panel bg-subtle text-muted">
                    <Lock size={32} />
                  </div>
                  <h1 className="text-2xl font-bold text-ink">忘记密码了？</h1>
                  <p className="leading-relaxed text-muted">使用密码以外的已绑定因素完成验证后重置密码。</p>
                </div>

                <div className="space-y-6">
                  <SelectionGroup value={method} label="账户恢复方式" indicator={false} className="!grid-cols-2 epass-segments">
                    <button type="button" aria-pressed={method === 'email'} onClick={() => setMethod('email')} className={`rounded-control px-4 py-2 text-sm font-bold ${method === 'email' ? 'bg-surface text-ink' : 'text-muted'}`}>邮箱</button>
                    <button type="button" aria-pressed={method === 'phone'} onClick={() => setMethod('phone')} className={`rounded-control px-4 py-2 text-sm font-bold ${method === 'phone' ? 'bg-surface text-ink' : 'text-muted'}`}>手机</button>
                    <button type="button" aria-pressed={method === 'authenticator'} onClick={() => setMethod('authenticator')} className={`rounded-control px-4 py-2 text-sm font-bold ${method === 'authenticator' ? 'bg-surface text-ink' : 'text-muted'}`}>Authenticator</button>
                    <button type="button" aria-pressed={method === 'passkey'} onClick={() => setMethod('passkey')} className={`rounded-control px-4 py-2 text-sm font-bold ${method === 'passkey' ? 'bg-surface text-ink' : 'text-muted'}`}>通行密钥</button>
                  </SelectionGroup>
                  <SelectionContent value={method} index={['email', 'phone', 'authenticator', 'passkey'].indexOf(method)}>
                  {method !== 'passkey' ? <AuthInput icon={method === 'phone' ? Smartphone : Mail} label={method === 'phone' ? '手机号码' : '账户邮箱或手机号'} placeholder={method === 'phone' ? '13800138000' : 'name@example.com'} value={form.account} onChange={(event) => setForm((current) => ({ ...current, account: event.target.value }))} /> : null}
                  </SelectionContent>
                  {error ? <p className="text-sm text-danger">{error}</p> : null}
                  <button onClick={async () => {
                    setError('');
                    try {
                      await sendRecoveryCode({ method, account: form.account });
                      setStep('verify');
                    } catch (e) {
                      setError(getUserErrorMessage(e, '发送失败，请稍后重试。'));
                    }
                  }} className="btn-primary w-full py-4 font-bold" type="button" disabled={loading}>
                    {method === 'email' || method === 'phone' ? '发送验证码' : '继续验证'}
                  </button>
                  <Link to={authNext ? `/login?next=${encodeURIComponent(authNext)}` : '/login'} className="flex items-center justify-center gap-2 text-sm font-bold text-muted transition-colors hover:text-muted">
                    <ChevronLeft size={18} />
                    返回登录
                  </Link>
                </div>
              </div>
            ) : step === 'verify' ? (
              <div className="space-y-8 py-4 text-center">
                <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-full bg-success-subtle text-success">
                  <CheckCircle2 size={48} />
                </div>
                <div className="space-y-3">
                  <h1 className="text-2xl font-bold text-ink">输入验证码并设置新密码</h1>
                  <p className="leading-relaxed text-muted">若账号存在，你将收到验证码。</p>
                </div>
                <div className="pt-4">
                  <div className="space-y-4 text-left">
                    {method !== 'passkey' ? <AuthInput icon={ShieldCheck} label={method === 'authenticator' ? 'Authenticator 动态码' : '验证码'} placeholder="6位验证码" value={form.code} onChange={(event) => setForm((current) => ({ ...current, code: event.target.value }))} /> : <p className="rounded-panel bg-canvas p-4 text-sm text-muted">提交时将调用系统通行密钥完成验证。</p>}
                    <NewPasswordField label="新密码" value={form.new_password} onChange={(event) => setForm((current) => ({ ...current, new_password: event.target.value }))} />
                    {error ? <p className="text-sm text-danger">{error}</p> : null}
                  </div>
                  <button onClick={async () => {
                    setError('');
                    try {
                      let passkeyResponse;
                      if (method === 'passkey') {
                        const options = await beginWebAuthnLogin();
                        const credential = await navigator.credentials.get({ publicKey: preparePublicKeyRequestOptions(options) });
                        if (!credential) throw new Error('未获取到通行密钥响应');
                        passkeyResponse = serializeAuthenticationCredential(credential);
                      }
                      await resetPasswordByCode({
                        method,
                        account: form.account,
                        code: form.code,
                        new_password: form.new_password,
                        ...(passkeyResponse ? { passkey_response: passkeyResponse } : {}),
                      });
                      setStep('done');
                    } catch (e) {
                      setError(getUserErrorMessage(e, '重置失败，请稍后重试。'));
                    }
                  }} className="btn-primary mb-3 mt-4 w-full py-4 font-bold" type="button" disabled={loading || !evaluatePassword(form.new_password).ok}>
                    重置密码
                  </button>
                  <button onClick={() => setStep('request')} className="btn-secondary mb-4 w-full py-4 font-bold" type="button">
                    重新填写
                  </button>
                  <Link to={authNext ? `/login?next=${encodeURIComponent(authNext)}` : '/login'} className="text-sm font-bold text-muted underline-offset-4 hover:underline">
                    返回登录页面
                  </Link>
                </div>
              </div>
            ) : (
              <div className="space-y-8 py-6 text-center">
                <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-full bg-success-subtle text-success">
                  <CheckCircle2 size={48} />
                </div>
                <div className="space-y-3">
                  <h1 className="text-2xl font-bold text-ink">密码已重置</h1>
                  <p className="leading-relaxed text-muted">旧会话已失效，请使用新密码重新登录。</p>
                </div>
                <Link to={authNext ? `/login?next=${encodeURIComponent(authNext)}` : '/login'} className="btn-primary block w-full py-4 font-bold">
                  返回登录
                </Link>
              </div>
            )}

          </SelectionContent>
        </div>
      </div>
    </AuthPageFrame>
  );
}

export function PostRegisterPasskeyPrompt({
  open,
  registrationMethod = 'email',
  saving,
  error,
  onConfirm,
  onSkip,
}) {

  return <AnimatePresence>{open && <Dialog key="passkey-prompt" title="添加通行密钥" onClose={() => { if (!saving) onSkip(); }} actions={<>
    <button type="button" className="btn-secondary" disabled={saving} onClick={onSkip}>稍后再说</button>
    <button type="button" className="btn-primary" disabled={saving} onClick={onConfirm}><LoadingButtonText loading={saving} loadingText="等待系统验证…" idleText="添加通行密钥" icon={Fingerprint} /></button>
  </>}><div className="space-y-4 text-sm text-muted"><p>账户已创建。添加通行密钥后，可以使用指纹、人脸或设备解锁登录。</p><p>建议再添加一种不同于当前注册方式的验证方式：{registrationMethod === 'phone' ? '邮箱、验证器或通行密钥。' : '手机、验证器或通行密钥。'}</p><p>也可以稍后在账户安全中设置。</p>{error && <p className="rounded-control bg-danger-subtle p-3 text-danger" role="alert">{error}</p>}</div></Dialog>}</AnimatePresence>;
}

export function PostRegisterBindingPrompt({
  open,
  registrationMethod = 'email',
  onSendCode,
  onConfirm,
  onSkip,
}) {
  const [account, setAccount] = useState('');
  const [code, setCode] = useState('');
  const [codeSent, setCodeSent] = useState(false);
  const [sending, setSending] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [cooldown, setCooldown] = useState(0);
  const bindingPhone = registrationMethod === 'email';

  useEffect(() => {
    if (!open) {
      setAccount('');
      setCode('');
      setCodeSent(false);
      setError('');
      setCooldown(0);
    }
  }, [open]);

  useEffect(() => {
    if (cooldown <= 0) {
      return undefined;
    }
    const timer = window.setInterval(() => {
      setCooldown((current) => (current > 1 ? current - 1 : 0));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [cooldown]);


  async function handleSendCode() {
    setError('');
    setSending(true);
    try {
      const result = await onSendCode(account.trim());
      setCodeSent(true);
      setCooldown(Math.max(1, Number(result?.retry_after || 60)));
    } catch (sendError) {
      setError(getUserErrorMessage(sendError, '验证码发送失败，请稍后重试。'));
    } finally {
      setSending(false);
    }
  }

  async function handleConfirm() {
    setError('');
    setSaving(true);
    try {
      await onConfirm(account.trim(), code.trim());
    } catch (bindError) {
      setError(getUserErrorMessage(bindError, '绑定失败，请检查验证码后重试。'));
    } finally {
      setSaving(false);
    }
  }

  return <AnimatePresence>{open && <Dialog key="binding-prompt" title={bindingPhone ? '添加手机号码' : '添加邮箱地址'} onClose={() => { if (!sending && !saving) onSkip(); }} actions={<>
    <button type="button" className="btn-secondary" onClick={onSkip} disabled={sending || saving}>跳过</button>
    <button type="button" className="btn-primary" onClick={() => void handleConfirm()} disabled={saving || !codeSent || !code.trim() || !account.trim()}><LoadingButtonText loading={saving} loadingText="验证并绑定中…" idleText="验证并添加" /></button>
  </>}><div className="space-y-5"><p className="text-sm text-muted">添加另一种联系方式，用于登录和恢复账户。</p>
    <AuthInput icon={bindingPhone ? Smartphone : Mail} label={bindingPhone ? '手机号码' : '邮箱地址'} type={bindingPhone ? 'tel' : 'email'} placeholder={bindingPhone ? '13800138000' : 'name@example.com'} value={account} onChange={(event) => setAccount(bindingPhone ? event.target.value.replace(/[^\d+]/g, '') : event.target.value)} />
    <CodeInputWithAction icon={ShieldCheck} label={bindingPhone ? '短信验证码' : '邮箱验证码'} placeholder="输入验证码" value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, ''))} onAction={() => void handleSendCode()} actionDisabled={sending || cooldown > 0 || !account.trim()} actionLabel={sending ? '发送中…' : cooldown > 0 ? `${cooldown} 秒后重发` : '发送验证码'} />
    {error && <p className="rounded-control bg-danger-subtle p-3 text-sm text-danger" role="alert">{error}</p>}
  </div></Dialog>}</AnimatePresence>;
}
