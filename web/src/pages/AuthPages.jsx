import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import {
  ArrowRight,
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
import { Link } from 'react-router-dom';
import { ThemeToggle } from '../theme';
import {
  preparePublicKeyRequestOptions,
  serializeAuthenticationCredential,
} from '../lib/utils';

function AuthPageFrame({ children }) {
  return (
    <div className="relative">
      <div className="fixed right-4 top-4 z-40 sm:right-6 sm:top-6">
        <ThemeToggle />
      </div>
      <motion.div
        initial={{ opacity: 0, x: 28 }}
        animate={{ opacity: 1, x: 0 }}
        exit={{ opacity: 0, x: -20 }}
        transition={{ duration: 0.38, ease: [0.22, 1, 0.36, 1] }}
      >
        {children}
      </motion.div>
    </div>
  );
}

function AuthInput({ icon: Icon, label, type = 'text', placeholder, value, onChange }) {
  return (
    <div className="space-y-2">
      <label className="ml-1 text-sm font-bold text-sage-700">{label}</label>
      <div className="group relative">
        <div className="absolute left-4 top-1/2 -translate-y-1/2 text-sage-400 transition-colors group-focus-within:text-sage-600">
          <Icon size={18} />
        </div>
        <input
          type={type}
          placeholder={placeholder}
          className="w-full rounded-2xl border border-sage-200 bg-sage-50/50 py-3 pl-12 pr-4 transition-all duration-300 placeholder:text-sage-300 focus:border-sage-400 focus:outline-none focus:ring-4 focus:ring-sage-400/10"
          value={value}
          onChange={onChange}
        />
      </div>
    </div>
  );
}

function CodeInputWithAction({
  icon: Icon,
  label,
  placeholder,
  value,
  onChange,
  actionLabel,
  onAction,
  actionDisabled,
}) {
  return (
    <div className="space-y-2">
      <label className="ml-1 text-sm font-bold text-sage-700">{label}</label>
      <div className="group relative">
        <div className="absolute left-4 top-1/2 -translate-y-1/2 text-sage-400 transition-colors group-focus-within:text-sage-600">
          <Icon size={18} />
        </div>
        <input
          type="text"
          placeholder={placeholder}
          className="w-full rounded-2xl border border-sage-200 bg-sage-50/50 py-3 pl-12 pr-32 transition-all duration-300 placeholder:text-sage-300 focus:border-sage-400 focus:outline-none focus:ring-4 focus:ring-sage-400/10"
          value={value}
          onChange={onChange}
        />
        <button
          type="button"
          onClick={onAction}
          disabled={actionDisabled}
          className="absolute right-2 top-1/2 -translate-y-1/2 rounded-xl border border-sage-200 bg-white px-3 py-2 text-xs font-bold text-sage-600 shadow-sm transition-colors hover:bg-sage-50 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {actionLabel}
        </button>
      </div>
    </div>
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
  return (
    <div className="relative hidden flex-col justify-between overflow-hidden bg-sage-900 p-12 text-white lg:flex">
      <div className="absolute right-0 top-0 -mr-48 -mt-48 h-96 w-96 rounded-full bg-sage-600/20 blur-[120px]" />
      <div className="absolute bottom-0 left-0 -mb-48 -ml-48 h-96 w-96 rounded-full bg-sage-400/10 blur-[100px]" />

      <div className="relative z-10">
        <div className="mb-12 flex items-center gap-3">
          <div className="flex h-12 w-12 items-center justify-center overflow-hidden rounded-2xl bg-white shadow-xl">
            <img
              src="https://tianyue.s3.bitiful.net/logo/rosemary_pure.png"
              alt="ROSM"
              className="h-8 w-8 object-contain"
            />
          </div>
          <span className="text-2xl font-bold tracking-tight">ROSM Pass</span>
        </div>

        <motion.div initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.2, duration: 0.8 }}>
          <h2 className="mb-6 text-5xl font-bold leading-tight">
            登入ROSM通行证
            <br />
            享受完整与便捷的服务
          </h2>
          <p className="max-w-md text-lg leading-relaxed text-sage-400">
            保护热情 维护附近 / 相信美好 全人健康
          </p>
        </motion.div>
      </div>

      <div className="relative z-10">
        <p className="text-xs font-medium uppercase tracking-widest text-sage-600">ROSEMARY STUDIO</p>
      </div>
    </div>
  );
}

function FactorListItem({ title, subtitle, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center justify-between rounded-2xl border border-sage-200 bg-white px-5 py-4 text-left transition-colors hover:border-sage-300 hover:bg-sage-50/60"
    >
      <div className="space-y-1">
        <p className="text-base font-bold text-sage-900">{title}</p>
        {subtitle ? <p className="text-sm leading-relaxed text-sage-500">{subtitle}</p> : null}
      </div>
      <ArrowRight size={18} className="text-sage-400" />
    </button>
  );
}

function getWebAuthnErrorMessage(error) {
  if (error?.name === 'NotAllowedError' || error?.name === 'AbortError') {
    return '你已取消本次通行密钥验证，或验证已超时。';
  }
  if (error?.name === 'NotSupportedError') {
    return '当前浏览器或设备不支持通行密钥。';
  }
  if (error?.name === 'SecurityError') {
    return '当前环境不允许使用通行密钥，请检查域名和安全上下文。';
  }
  if (error?.name === 'InvalidStateError') {
    return '当前通行密钥状态异常，请重新尝试。';
  }
  if (error instanceof Error) {
    return error.message;
  }
  return '通行密钥登录失败，请重试。';
}

export function LoginPage({
  loginForm,
  setLoginForm,
  loginMethod,
  setLoginMethod,
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
  resendPasswordLoginCode,
  resendPasswordPhoneCode,
  resendEmailCodeLogin,
  resendPhoneCodeLogin,
  loadLoginCodeCooldown,
  beginWebAuthnLogin,
  completeWebAuthnLogin,
  authNext = '',
}) {
  const [webauthnLoading, setWebauthnLoading] = useState(false);
  const [webauthnError, setWebauthnError] = useState('');
  const panelKey = `${loginMethod}:${loginStep}:${selectedPasswordFactor || 'none'}`;
  const panelTransition = {
    duration: 0.34,
    ease: [0.22, 1, 0.36, 1],
  };

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

  function renderPanel(view) {
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
            className="flex w-full items-center justify-center gap-2 text-sm font-bold text-sage-500 transition-colors hover:text-sage-700"
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
              );
            } catch (error) {
              setWebauthnError(getWebAuthnErrorMessage(error));
            } finally {
              setWebauthnLoading(false);
            }
          }}
        >
          {webauthnError ? (
            <p className="text-sm text-red-600">{webauthnError}</p>
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

          <div className="flex items-center justify-between px-1">
            <div className="flex items-center gap-2">
              <input type="checkbox" id="remember" className="h-4 w-4 rounded text-sage-600 focus:ring-sage-400" />
              <label htmlFor="remember" className="text-sm text-sage-500">
                保持登录状态
              </label>
            </div>
            <Link to={authNext ? `/forgot-password?next=${encodeURIComponent(authNext)}` : '/forgot-password'} className="text-xs font-bold text-sage-600 transition-colors hover:text-sage-900">
              忘记密码？
            </Link>
          </div>

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
              <p className="text-sm text-red-600">{webauthnError}</p>
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
                  );
                } catch (error) {
                  setWebauthnError(getWebAuthnErrorMessage(error));
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
          className="flex w-full items-center justify-center gap-2 text-sm font-bold text-sage-500 transition-colors hover:text-sage-700"
        >
          <ChevronLeft size={18} />
          返回上一步
        </button>
      </form>
    );
  }

  return (
    <AuthPageFrame>
      <div className="grid min-h-screen grid-cols-1 bg-white lg:grid-cols-2">
        <BrandSection />

        <div className="relative flex flex-col justify-center p-8 sm:p-12 lg:p-24">
          <div className="mx-auto w-full max-w-md space-y-10">
            <div className="space-y-3">
              <div className="space-y-2">
                <h1 className="text-3xl font-bold text-sage-900">欢迎回来</h1>
                <p className="text-sage-500">
                  {loginMethod === 'phone_code'
                    ? '请输入手机号并使用短信验证码完成登录。'
                    : loginStep === 'credentials'
                      ? '请输入您的凭据以访问账户。'
                      : '请输入二因素验证信息以完成本次登录。'}
                </p>
              </div>
              <div className="relative grid grid-cols-4 rounded-2xl border border-sage-200 bg-sage-50/70 p-1">
                <button
                  type="button"
                  onClick={() => switchTab('phone_code')}
                  className={`relative z-10 rounded-xl px-4 py-2 text-sm font-bold transition-colors ${loginMethod === 'phone_code' ? 'text-sage-900' : 'text-sage-500 hover:text-sage-700'}`}
                >
                  {loginMethod === 'phone_code' ? (
                    <motion.span
                      layoutId="login-method-pill"
                      className="absolute inset-0 -z-10 rounded-xl bg-white shadow-sm"
                      transition={{ type: 'spring', stiffness: 360, damping: 32, mass: 0.9 }}
                    />
                  ) : null}
                  手机
                </button>
                <button
                  type="button"
                  onClick={() => switchTab('email_code')}
                  className={`relative z-10 rounded-xl px-4 py-2 text-sm font-bold transition-colors ${loginMethod === 'email_code' ? 'text-sage-900' : 'text-sage-500 hover:text-sage-700'}`}
                >
                  {loginMethod === 'email_code' ? (
                    <motion.span
                      layoutId="login-method-pill"
                      className="absolute inset-0 -z-10 rounded-xl bg-white shadow-sm"
                      transition={{ type: 'spring', stiffness: 360, damping: 32, mass: 0.9 }}
                    />
                  ) : null}
                  验证码
                </button>
                <button
                  type="button"
                  onClick={() => switchTab('webauthn')}
                  className={`relative z-10 rounded-xl px-4 py-2 text-sm font-bold transition-colors ${loginMethod === 'webauthn' ? 'text-sage-900' : 'text-sage-500 hover:text-sage-700'}`}
                >
                  {loginMethod === 'webauthn' ? (
                    <motion.span
                      layoutId="login-method-pill"
                      className="absolute inset-0 -z-10 rounded-xl bg-white shadow-sm"
                      transition={{ type: 'spring', stiffness: 360, damping: 32, mass: 0.9 }}
                    />
                  ) : null}
                  通行密钥
                </button>
                <button
                  type="button"
                  onClick={() => switchTab('password')}
                  className={`relative z-10 rounded-xl px-4 py-2 text-sm font-bold transition-colors ${loginMethod === 'password' ? 'text-sage-900' : 'text-sage-500 hover:text-sage-700'}`}
                >
                  {loginMethod === 'password' ? (
                    <motion.span
                      layoutId="login-method-pill"
                      className="absolute inset-0 -z-10 rounded-xl bg-white shadow-sm"
                      transition={{ type: 'spring', stiffness: 360, damping: 32, mass: 0.9 }}
                    />
                  ) : null}
                  密码
                </button>
              </div>
            </div>

            <motion.div
              layout="size"
              className="relative overflow-hidden pb-6"
              transition={panelTransition}
            >
              <AnimatePresence initial={false} mode="popLayout">
                <motion.div
                  key={panelKey}
                  layout="position"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                  transition={panelTransition}
                  className="will-change-transform"
                >
                  {renderPanel({
                    method: loginMethod,
                    step: loginStep,
                    selectedPasswordFactor,
                  })}
                </motion.div>
              </AnimatePresence>
            </motion.div>

            <p className="text-center text-sm text-sage-500">
              还没有账户？
              {' '}
              <Link to={authNext ? `/register?next=${encodeURIComponent(authNext)}` : '/register'} className="font-bold text-sage-900 underline-offset-4 hover:underline">
                立即注册
              </Link>
            </p>
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
  hcaptchaRef,
  publicConfig,
  mountCaptcha,
  authNext = '',
}) {
  useEffect(() => {
    mountCaptcha?.();
  }, [mountCaptcha]);

  const registerCodeDisabled =
    registerCodeSending ||
    registerCodeCooldownRemaining > 0 ||
    !(registerMethod === 'phone' ? registerForm.phone_number.trim() : registerForm.email.trim()) ||
    !publicConfig?.captcha?.site_key;

  return (
    <AuthPageFrame>
    <div className="grid min-h-screen grid-cols-1 bg-white lg:grid-cols-2">
      <BrandSection />

      <div className="flex flex-col justify-center p-8 sm:p-12 lg:p-24">
        <div className="mx-auto w-full max-w-md space-y-8">
          <div className="space-y-2">
            <h1 className="text-3xl font-bold text-sage-900">创建新账户</h1>
            <p className="text-sage-500">支持邮箱或手机号注册，完成验证码验证后即可开始使用。</p>
          </div>

          <div className="relative grid grid-cols-2 rounded-2xl border border-sage-200 bg-sage-50/70 p-1">
            <button
              type="button"
              onClick={() => setRegisterMethod('email')}
              className={`relative z-10 rounded-xl px-4 py-2 text-sm font-bold transition-colors ${registerMethod === 'email' ? 'text-sage-900' : 'text-sage-500 hover:text-sage-700'}`}
            >
              邮箱注册
            </button>
            <button
              type="button"
              onClick={() => setRegisterMethod('phone')}
              className={`relative z-10 rounded-xl px-4 py-2 text-sm font-bold transition-colors ${registerMethod === 'phone' ? 'text-sage-900' : 'text-sage-500 hover:text-sage-700'}`}
            >
              手机注册
            </button>
          </div>

          <form className="space-y-5" onSubmit={submitRegister}>
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
                onChange={(event) => setRegisterForm((current) => ({ ...current, email: event.target.value }))}
              />
            ) : (
              <AuthInput
                icon={Smartphone}
                label="手机号码"
                placeholder="13800138000"
                value={registerForm.phone_number}
                onChange={(event) => setRegisterForm((current) => ({ ...current, phone_number: event.target.value.replace(/[^\d+]/g, '') }))}
              />
            )}
            <div className="grid grid-cols-[1fr_auto] gap-3">
              <AuthInput
                icon={ShieldCheck}
                label={registerMethod === 'email' ? '邮箱验证码' : '短信验证码'}
                placeholder="输入验证码"
                value={registerMethod === 'email' ? registerForm.email_code : registerForm.phone_code}
                onChange={(event) => setRegisterForm((current) => ({ ...current, [registerMethod === 'email' ? 'email_code' : 'phone_code']: event.target.value }))}
              />
              <button type="button" onClick={() => void submitRegisterCode()} className="btn-secondary mt-[30px] whitespace-nowrap px-4" disabled={registerCodeDisabled}>
                <LoadingButtonText
                  loading={registerCodeSending}
                  loadingText="发送中..."
                  idleText={registerCodeCooldownRemaining > 0 ? `${registerCodeCooldownRemaining} 秒后重发` : '发送验证码'}
                />
              </button>
            </div>
            <AuthInput
              icon={Lock}
              label="设置密码"
              type="password"
              placeholder="••••••••"
              value={registerForm.password}
              onChange={(event) => setRegisterForm((current) => ({ ...current, password: event.target.value }))}
            />

            <div className="space-y-3 rounded-2xl border border-sage-100 bg-sage-50 p-4">
              <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-sage-400">
                <Info size={14} />
                密码建议
              </div>
              <p className="text-xs leading-relaxed text-sage-500">建议同时包含大写字母、数字和特殊符号，并避免与其他系统复用。</p>
            </div>

            <div className="space-y-2">
              <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-sage-400">
                <ShieldCheck size={14} />
                人机验证
              </div>
              <div className="rounded-2xl border border-sage-100 bg-sage-50/60 p-4">
                {publicConfig?.captcha?.site_key ? (
                  <div className="space-y-3">
                    <div ref={hcaptchaRef} />
                    <p className="text-xs text-sage-500">发送验证码前需要先完成一次人机验证。</p>
                  </div>
                ) : (
                  <p className="text-sm text-sage-500">当前不可用</p>
                )}
              </div>
            </div>

            <button type="submit" disabled={loading} className="btn-primary w-full py-4 text-lg font-bold">
              <LoadingButtonText loading={loading} loadingText="注册中..." idleText="注册账户" />
            </button>
          </form>

          <p className="text-center text-sm text-sage-500">
            已经有账户了？
            {' '}
            <Link to={authNext ? `/login?next=${encodeURIComponent(authNext)}` : '/login'} className="font-bold text-sage-900 underline-offset-4 hover:underline">
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
  authNext = '',
}) {
  const [method, setMethod] = useState('email');
  const [step, setStep] = useState('request');
  const [form, setForm] = useState({ account: '', code: '', new_password: '' });
  const [error, setError] = useState('');

  return (
    <div className="flex min-h-screen items-center justify-center bg-sage-50 p-6">
      <div className="w-full max-w-md">
        <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} className="glass-card rounded-[2.5rem] p-10 shadow-2xl shadow-sage-900/5">
          <AnimatePresence mode="wait">
            {step === 'request' ? (
              <motion.div key="request" initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }} className="space-y-8">
                <div className="space-y-4 text-center">
                  <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-sage-100 text-sage-600">
                    <Lock size={32} />
                  </div>
                  <h1 className="text-2xl font-bold text-sage-900">忘记密码了？</h1>
                  <p className="leading-relaxed text-sage-500">通过邮箱或手机号验证码重置密码。</p>
                </div>

                <div className="space-y-6">
                  <div className="relative grid grid-cols-2 rounded-2xl border border-sage-200 bg-sage-50/70 p-1">
                    <button type="button" onClick={() => setMethod('email')} className={`rounded-xl px-4 py-2 text-sm font-bold ${method === 'email' ? 'bg-white text-sage-900' : 'text-sage-500'}`}>邮箱</button>
                    <button type="button" onClick={() => setMethod('phone')} className={`rounded-xl px-4 py-2 text-sm font-bold ${method === 'phone' ? 'bg-white text-sage-900' : 'text-sage-500'}`}>手机</button>
                  </div>
                  <AuthInput icon={method === 'email' ? Mail : Smartphone} label={method === 'email' ? '邮箱地址' : '手机号码'} placeholder={method === 'email' ? 'name@example.com' : '13800138000'} value={form.account} onChange={(event) => setForm((current) => ({ ...current, account: event.target.value }))} />
                  {error ? <p className="text-sm text-red-600">{error}</p> : null}
                  <button onClick={async () => {
                    setError('');
                    try {
                      await sendRecoveryCode({ method, account: form.account });
                      setStep('verify');
                    } catch (e) {
                      setError(e.message || '发送失败');
                    }
                  }} className="btn-primary w-full py-4 font-bold" type="button" disabled={loading}>
                    发送验证码
                  </button>
                  <Link to={authNext ? `/login?next=${encodeURIComponent(authNext)}` : '/login'} className="flex items-center justify-center gap-2 text-sm font-bold text-sage-400 transition-colors hover:text-sage-600">
                    <ChevronLeft size={18} />
                    返回登录
                  </Link>
                </div>
              </motion.div>
            ) : (
              <motion.div key="success" initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }} className="space-y-8 py-4 text-center">
                <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-full bg-green-100 text-green-600">
                  <CheckCircle2 size={48} />
                </div>
                <div className="space-y-3">
                  <h1 className="text-2xl font-bold text-sage-900">输入验证码并设置新密码</h1>
                  <p className="leading-relaxed text-sage-500">若账号存在，你将收到验证码。</p>
                </div>
                <div className="pt-4">
                  <div className="space-y-4 text-left">
                    <AuthInput icon={ShieldCheck} label="验证码" placeholder="6位验证码" value={form.code} onChange={(event) => setForm((current) => ({ ...current, code: event.target.value }))} />
                    <AuthInput icon={Lock} label="新密码" type="password" placeholder="••••••••" value={form.new_password} onChange={(event) => setForm((current) => ({ ...current, new_password: event.target.value }))} />
                    {error ? <p className="text-sm text-red-600">{error}</p> : null}
                  </div>
                  <button onClick={async () => {
                    setError('');
                    try {
                      await resetPasswordByCode({
                        method,
                        account: form.account,
                        code: form.code,
                        new_password: form.new_password,
                      });
                      setStep('done');
                    } catch (e) {
                      setError(e.message || '重置失败');
                    }
                  }} className="btn-primary mb-3 mt-4 w-full py-4 font-bold" type="button" disabled={loading}>
                    重置密码
                  </button>
                  <button onClick={() => setStep('request')} className="btn-secondary mb-4 w-full py-4 font-bold" type="button">
                    重新填写
                  </button>
                  <Link to={authNext ? `/login?next=${encodeURIComponent(authNext)}` : '/login'} className="text-sm font-bold text-sage-600 underline-offset-4 hover:underline">
                    返回登录页面
                  </Link>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
      </div>
    </div>
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
  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-sage-950/45 p-6 backdrop-blur-sm">
      <div className="w-full max-w-xl overflow-hidden rounded-[2rem] border border-white/60 bg-[#fcfaf5] shadow-2xl shadow-sage-950/20">
        <div className="border-b border-sage-200/80 bg-gradient-to-br from-white via-[#f8f3ea] to-[#eef4ea] px-8 py-7">
          <div className="mb-4 flex items-center gap-3">
            <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-sage-900 text-white shadow-lg shadow-sage-900/15">
              <Fingerprint size={22} />
            </div>
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.24em] text-sage-500">ROSM 账户安全</p>
              <h3 className="text-2xl font-bold text-sage-950">添加系统通行密钥？</h3>
            </div>
          </div>
          <p className="max-w-lg text-sm leading-7 text-sage-700">
            你刚刚已经完成注册，我们可以直接调用系统完成一次通行密钥录入。
            以后登录通常会更快，也更不容易忘记密码。
          </p>
        </div>

        <div className="space-y-5 px-8 py-7">
          <div className="rounded-3xl border border-sage-200 bg-white/80 p-5">
            <div className="mb-3 flex items-center gap-2 text-sm font-bold text-sage-800">
              <CheckCircle2 size={18} className="text-green-600" />
              这样做的好处
            </div>
            <div className="space-y-2 text-sm leading-7 text-sage-600">
              <p>登录时通常只需指纹、面容或设备解锁，无需反复输入密码。</p>
              <p>通行密钥基于当前设备安全能力，抗钓鱼能力通常比传统密码更强。</p>
              <p>
                建议在完成注册后，再补充一种不同于当前注册方式的二因素：
                {registrationMethod === 'phone'
                  ? '可添加邮箱验证码、Authenticator 或通行密钥。'
                  : '可添加手机验证码、Authenticator 或通行密钥。'}
              </p>
              <p>现在也可以跳过，之后仍可在账户安全页面手动添加。</p>
            </div>
          </div>

          {error ? (
            <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {error}
            </div>
          ) : null}

          <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <button type="button" onClick={onSkip} disabled={saving} className="btn-secondary px-5 py-3">
              稍后再说
            </button>
            <button type="button" onClick={onConfirm} disabled={saving} className="btn-primary min-w-[180px] px-5 py-3">
              <LoadingButtonText
                loading={saving}
                loadingText="等待系统验证..."
                idleText="立即添加通行密钥"
                icon={ArrowRight}
              />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
