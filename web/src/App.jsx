import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { AdminLayout, UserLayout } from './components/Layouts';
import { HCAPTCHA_SITE_KEY, API_BASE, SECURITY_FIELDS, SECURITY_FIELD_DEFAULTS, SECURITY_TOGGLE_DEFAULTS } from './constants';
import { AdminFlutterSdkDocsPage, AdminOIDCConfig, AdminOidcDocsPage, AdminSecurityPolicy, AdminServiceConfig, AdminUsers } from './pages/AdminPages';
import { ForgotPasswordPage, LoginPage, PostRegisterPasskeyPrompt, RegisterPage } from './pages/AuthPages';
import { UserAccountPage } from './pages/UserPages';
import { useTheme } from './theme';
import { preparePublicKeyCreationOptions, serializeRegistrationCredential } from './lib/utils';

const POST_LOGIN_TOAST_STORAGE_KEY = 'rosm_pending_toast';

function AppRoutes({
  isLoggedIn,
  defaultAuthedPath,
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
  requestPasswordLoginCode,
  requestPasswordPhoneCode,
  requestEmailCodeLogin,
  requestPhoneCodeLogin,
  loadLoginCodeCooldown,
  beginWebAuthnLogin,
  completeWebAuthnLogin,
  registerForm,
  setRegisterForm,
  registerMethod,
  setRegisterMethod,
  registerCodeSending,
  registerCodeCooldownRemaining,
  submitRegister,
  submitRegisterCode,
  publicHcaptchaRef,
  publicConfig,
  mountPublicCaptcha,
  sendRecoveryCode,
  resetPasswordByCode,
  session,
  logout,
  mustBindEmail,
  updateNicknameSilently,
  sendBindEmailCode,
  bindEmail,
  sendBindPhoneCode,
  bindPhone,
  sendPasswordResetCode,
  resetPasswordWithCode,
  beginAuthenticatorSetup,
  verifyAuthenticatorSetup,
  beginWebAuthnRegistration,
  verifyWebAuthnRegistration,
  listWebAuthnCredentials,
  deleteWebAuthnCredential,
  systemForm,
  setSystemForm,
  saveServiceConfig,
  testSmtpConnection,
  testHcaptchaConnection,
  testPhoneSmsConnection,
  users,
  usersPagination,
  loadUsers,
  createManagedUser,
  updateManagedUserRoles,
  deleteManagedUser,
  safely,
  discovery,
  systemSettings,
  loadDiscovery,
  oidcClients,
  loadOidcClients,
  oidcForm,
  setOidcForm,
  saveOidcClient,
  deleteOidcClient,
  saveSecurityPolicy,
  addRegistrationProvider,
  importRegistrationProviders,
  removeRegistrationProvider,
  isAdmin,
}) {
  const location = useLocation();
  const loginNext = location.pathname === '/login'
    ? new URLSearchParams(location.search).get('next')?.trim() || ''
    : '';
  const registerNext = location.pathname === '/register'
    ? new URLSearchParams(location.search).get('next')?.trim() || ''
    : '';
  const forgotNext = location.pathname === '/forgot-password'
    ? new URLSearchParams(location.search).get('next')?.trim() || ''
    : '';

  return (
      <Routes location={location}>
        <Route
          path="/login"
          element={
            isLoggedIn ? (
              <PostLoginRedirect target={loginNext} fallback={defaultAuthedPath} />
            ) : (
              <LoginPage
                loginForm={loginForm}
                setLoginForm={setLoginForm}
                loginMethod={loginMethod}
                setLoginMethod={setLoginMethod}
                loginStep={loginStep}
                setLoginStep={setLoginStep}
                loading={loading}
                loginCodeSending={loginCodeSending}
                loginCodeCooldownRemaining={loginCodeCooldownRemaining}
                passwordLoginFactors={passwordLoginFactors}
                selectedPasswordFactor={selectedPasswordFactor}
                setSelectedPasswordFactor={setSelectedPasswordFactor}
                selectPasswordFactor={selectPasswordFactor}
                prepareLogin={prepareLogin}
                completeLogin={completeLogin}
                prepareEmailCodeLogin={prepareEmailCodeLogin}
                completeEmailCodeLogin={completeEmailCodeLogin}
                preparePhoneCodeLogin={preparePhoneCodeLogin}
                completePhoneCodeLogin={completePhoneCodeLogin}
                resendPasswordLoginCode={requestPasswordLoginCode}
                resendPasswordPhoneCode={requestPasswordPhoneCode}
                resendEmailCodeLogin={requestEmailCodeLogin}
                resendPhoneCodeLogin={requestPhoneCodeLogin}
                loadLoginCodeCooldown={loadLoginCodeCooldown}
                beginWebAuthnLogin={beginWebAuthnLogin}
                completeWebAuthnLogin={completeWebAuthnLogin}
                authNext={loginNext}
              />
            )
          }
        />
        <Route
          path="/register"
          element={
            isLoggedIn ? (
              <Navigate to={defaultAuthedPath} replace />
            ) : (
              <RegisterPage
                registerForm={registerForm}
                setRegisterForm={setRegisterForm}
                registerMethod={registerMethod}
                setRegisterMethod={setRegisterMethod}
                loading={loading}
                registerCodeSending={registerCodeSending}
                registerCodeCooldownRemaining={registerCodeCooldownRemaining}
                submitRegister={submitRegister}
                submitRegisterCode={submitRegisterCode}
                hcaptchaRef={publicHcaptchaRef}
                publicConfig={publicConfig}
                mountCaptcha={mountPublicCaptcha}
                authNext={registerNext}
              />
            )
          }
        />
        <Route path="/forgot-password" element={isLoggedIn ? <Navigate to={defaultAuthedPath} replace /> : <ForgotPasswordPage loading={loading} sendRecoveryCode={sendRecoveryCode} resetPasswordByCode={resetPasswordByCode} authNext={forgotNext} />} />

        <Route path="/admin" element={isLoggedIn ? <AdminLayout session={session} logout={logout} mustBindEmail={mustBindEmail} /> : <Navigate to="/login" replace />}>
          <Route index element={<Navigate to="/admin/account" replace />} />
          <Route
            path="account"
            element={
              <UserAccountPage
                session={session}
                mustBindEmail={mustBindEmail}
                updateNicknameSilently={updateNicknameSilently}
                sendBindEmailCode={sendBindEmailCode}
                bindEmail={bindEmail}
                sendBindPhoneCode={sendBindPhoneCode}
                bindPhone={bindPhone}
                sendPasswordResetCode={sendPasswordResetCode}
                resetPasswordWithCode={resetPasswordWithCode}
                beginAuthenticatorSetup={beginAuthenticatorSetup}
                verifyAuthenticatorSetup={verifyAuthenticatorSetup}
                beginWebAuthnRegistration={beginWebAuthnRegistration}
                verifyWebAuthnRegistration={verifyWebAuthnRegistration}
                listWebAuthnCredentials={listWebAuthnCredentials}
                deleteWebAuthnCredential={deleteWebAuthnCredential}
              />
            }
          />
          <Route path="service" element={<AdminServiceConfig systemForm={systemForm} setSystemForm={setSystemForm} saveServiceConfig={saveServiceConfig} testSmtpConnection={testSmtpConnection} testHcaptchaConnection={testHcaptchaConnection} testPhoneSmsConnection={testPhoneSmsConnection} />} />
          <Route
            path="users"
            element={
              <AdminUsers
                users={users}
                pagination={usersPagination}
                loadUsers={loadUsers}
                safely={safely}
                createUser={createManagedUser}
                updateUserRoles={updateManagedUserRoles}
                deleteUser={deleteManagedUser}
              />
            }
          />
          <Route path="oidc" element={<AdminOIDCConfig discovery={discovery} oidcSettings={systemSettings?.oidc} loadDiscovery={loadDiscovery} oidcClients={oidcClients} loadOidcClients={loadOidcClients} safely={safely} oidcForm={oidcForm} setOidcForm={setOidcForm} saveOidcClient={saveOidcClient} deleteOidcClient={deleteOidcClient} />} />
          <Route path="oidc/docs" element={<AdminOidcDocsPage discovery={discovery} oidcSettings={systemSettings?.oidc} />} />
          <Route path="oidc/docs/flutter-sdk" element={<AdminFlutterSdkDocsPage discovery={discovery} oidcSettings={systemSettings?.oidc} />} />
          <Route
            path="security"
            element={
              <AdminSecurityPolicy
                systemForm={systemForm}
                setSystemForm={setSystemForm}
                saveSecurityPolicy={saveSecurityPolicy}
                addRegistrationProvider={addRegistrationProvider}
                importRegistrationProviders={importRegistrationProviders}
                removeRegistrationProvider={removeRegistrationProvider}
              />
            }
          />
        </Route>

        <Route path="/account" element={isLoggedIn && !isAdmin ? <UserLayout session={session} logout={logout} /> : <Navigate to={isLoggedIn ? '/admin/account' : '/login'} replace />}>
          <Route
            index
            element={
              <UserAccountPage
                session={session}
                mustBindEmail={mustBindEmail}
                updateNicknameSilently={updateNicknameSilently}
                sendBindEmailCode={sendBindEmailCode}
                bindEmail={bindEmail}
                sendPasswordResetCode={sendPasswordResetCode}
                resetPasswordWithCode={resetPasswordWithCode}
                beginAuthenticatorSetup={beginAuthenticatorSetup}
                verifyAuthenticatorSetup={verifyAuthenticatorSetup}
                beginWebAuthnRegistration={beginWebAuthnRegistration}
                verifyWebAuthnRegistration={verifyWebAuthnRegistration}
                listWebAuthnCredentials={listWebAuthnCredentials}
                deleteWebAuthnCredential={deleteWebAuthnCredential}
              />
            }
          />
        </Route>

        <Route path="/" element={<Navigate to={isLoggedIn ? defaultAuthedPath : '/login'} replace />} />
        <Route path="*" element={<Navigate to={isLoggedIn ? defaultAuthedPath : '/login'} replace />} />
      </Routes>
  );
}

function PostLoginRedirect({ target, fallback }) {
  useEffect(() => {
    if (!target) {
      return;
    }
    window.location.replace(target);
  }, [target]);

  if (target) {
    return null;
  }
  return <Navigate to={fallback} replace />;
}

function App() {
  const { resolvedTheme } = useTheme();
  const normalizeProvider = useCallback((value) => {
    const trimmed = `${value || ''}`.trim().toLowerCase();
    if (!trimmed) {
      return '';
    }
    let candidate = trimmed;
    if (candidate.includes('@') && !candidate.startsWith('@')) {
      candidate = candidate.slice(candidate.lastIndexOf('@'));
    }
    if (!candidate.startsWith('@')) {
      candidate = `@${candidate}`;
    }
    return candidate;
  }, []);

  const normalizeProviderList = useCallback((value) => {
    const source = Array.isArray(value) ? value : `${value || ''}`.split(/[\n,]/);
    return source
      .map((item) => normalizeProvider(item))
      .filter(Boolean)
      .reduce((items, item) => (items.includes(item) ? items : [...items, item]), []);
  }, [normalizeProvider]);

  const [toast, setToast] = useState(null);
  const [loginMethod, setLoginMethod] = useState('phone_code');
  const [loginStep, setLoginStep] = useState('credentials');
  const [status, setStatus] = useState('');
  const [publicConfig, setPublicConfig] = useState(null);
  const [session, setSession] = useState({ user: null, security: null });
  const [systemSettings, setSystemSettings] = useState(null);
  const [templates, setTemplates] = useState([]);
  const [selectedTemplate, setSelectedTemplate] = useState('');
  const [oidcClients, setOidcClients] = useState([]);
  const [users, setUsers] = useState([]);
  const [usersPagination, setUsersPagination] = useState({
    page: 1,
    page_size: 10,
    total: 0,
    total_pages: 0,
  });
  const [discovery, setDiscovery] = useState(null);
  const [loading, setLoading] = useState(false);
  const [registerCodeSending, setRegisterCodeSending] = useState(false);
  const [registerCodeCooldownRemaining, setRegisterCodeCooldownRemaining] = useState(0);
  const [loginCodeSending, setLoginCodeSending] = useState(false);
  const [loginCodeCooldownRemaining, setLoginCodeCooldownRemaining] = useState(0);
  const [passwordLoginFactors, setPasswordLoginFactors] = useState([]);
  const [selectedPasswordFactor, setSelectedPasswordFactor] = useState('phone_code');
  const [postRegisterPasskeyPromptOpen, setPostRegisterPasskeyPromptOpen] = useState(false);
  const [postRegisterPasskeySaving, setPostRegisterPasskeySaving] = useState(false);
  const [postRegisterPasskeyError, setPostRegisterPasskeyError] = useState('');
  const [postRegisterMethod, setPostRegisterMethod] = useState('email');
  const [pendingAuthRedirect, setPendingAuthRedirect] = useState('');

  const [loginForm, setLoginForm] = useState({
    email: '',
    phone_number: '',
    password: '',
    email_code: '',
    phone_code: '',
    authenticator_code: '',
  });
  const [registerForm, setRegisterForm] = useState({
    email: '',
    email_code: '',
    phone_number: '',
    phone_code: '',
    nickname: '',
    password: '',
  });
  const [registerMethod, setRegisterMethod] = useState('email');
  const [systemForm, setSystemForm] = useState({});
  const [oidcForm, setOidcForm] = useState({
    client_id: '',
    display_name: '',
    is_official: false,
    redirect_uris: '',
    scopes: 'openid\nprofile\nemail\nphone',
    grant_types: 'authorization_code\nrefresh_token',
    client_secret: '',
    is_confidential: false,
    is_active: true,
  });

  const publicHcaptchaRef = useRef(null);
  const publicHcaptchaWidgetRef = useRef(null);
  const publicHcaptchaMountRef = useRef(null);
  const publicHcaptchaThemeRef = useRef(null);
  const backgroundHcaptchaContainerRef = useRef(null);
  const backgroundHcaptchaWidgetRef = useRef(null);
  const backgroundHcaptchaPromiseRef = useRef(null);

  const isLoggedIn = Boolean(session.user);
  const isAdmin = session.user?.roles?.includes('admin');
  const mustBindEmail = Boolean(session.security?.must_bind_email);
  const defaultAuthedPath = isAdmin ? '/admin/account' : '/account';

  useEffect(() => {
    if (!toast) {
      return undefined;
    }
    const timer = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    void loadPublicConfig();
  }, []);

  useEffect(() => {
    try {
      const raw = window.sessionStorage.getItem(POST_LOGIN_TOAST_STORAGE_KEY);
      if (!raw) {
        return;
      }
      window.sessionStorage.removeItem(POST_LOGIN_TOAST_STORAGE_KEY);
      const pending = JSON.parse(raw);
      if (pending?.message) {
        showToast(pending.message, pending.type || 'info');
      }
    } catch (_) {
      window.sessionStorage.removeItem(POST_LOGIN_TOAST_STORAGE_KEY);
    }
  }, []);

  useEffect(() => {
    void bootstrapSession();
  }, []);

  useEffect(() => {
    try {
      const pathname = window.location.pathname;
      if (pathname !== '/login' && pathname !== '/register') {
        return;
      }
      const params = new URLSearchParams(window.location.search);
      const next = (params.get('next') || '').trim();
      if (next) {
        setPendingAuthRedirect(next);
      }
    } catch (_) {
      // ignore malformed URL parsing
    }
  }, []);

  useEffect(() => {
    void ensureBackgroundCaptchaWidget();
  }, [publicConfig]);

  useEffect(() => {
    void ensurePublicCaptchaWidget();
  }, [publicConfig, resolvedTheme]);

  useEffect(() => {
    if (registerCodeCooldownRemaining <= 0) {
      return undefined;
    }
    const timer = window.setInterval(() => {
      setRegisterCodeCooldownRemaining((current) => (current > 1 ? current - 1 : 0));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [registerCodeCooldownRemaining]);

  useEffect(() => {
    if (loginCodeCooldownRemaining <= 0) {
      return undefined;
    }
    const timer = window.setInterval(() => {
      setLoginCodeCooldownRemaining((current) => (current > 1 ? current - 1 : 0));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [loginCodeCooldownRemaining]);

  function showToast(message, type = 'info') {
    setToast({ message, type });
  }

  function redirectToLoginWithToast(message) {
    try {
      window.sessionStorage.setItem(
        POST_LOGIN_TOAST_STORAGE_KEY,
        JSON.stringify({ message, type: 'info' }),
      );
    } catch (_) {
      // Ignore storage failures and still complete the redirect.
    }
    logout('');
    window.location.replace('/login');
  }

  function hasConfiguredCaptcha() {
    return Boolean(`${publicConfig?.captcha?.site_key || HCAPTCHA_SITE_KEY}`.trim());
  }

  async function api(path, options = {}) {
    const { method = 'GET', body, auth = false } = options;
    const headers = {};
    if (body !== undefined) {
      headers['content-type'] = 'application/json';
    }
    let response;
    try {
      response = await fetch(`${API_BASE}${path}`, {
        method,
        headers,
        credentials: 'include',
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch (_) {
      const error = new Error('当前无法连接到服务，请检查网络后重试。');
      error.code = 'network_error';
      error.status = 0;
      throw error;
    }
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(data.message || `请求失败(${response.status})`);
      error.code = data.error || data.code || 'request_failed';
      error.status = response.status;
      throw error;
    }
    return data;
  }

  function getAuthErrorMessage(error, context) {
    const code = error?.code || 'request_failed';
    if (code === 'network_error') {
      return '当前无法连接到服务，请检查网络后重试。';
    }
    if (code === 'login_failed') {
      return '账号或密码错误';
    }
    if (code === 'rate_limited') {
      return '请求过于频繁，请稍后再试。';
    }
    if (code === 'mfa_required' || code === 'invalid_totp_code') {
      return error.message || '验证信息无效，请重试。';
    }
    if (code === 'not_configured') {
      return '当前账户未配置通行密钥。';
    }
    if (code === 'verification_failed') {
      return '通行密钥校验未通过，请重试。';
    }
    if (code === 'invalid_factor') {
      return '当前验证方式不可用，请重新选择。';
    }
    if (code === 'invalid_request') {
      return error.message || '请求参数不完整，请检查后重试。';
    }
    if (code === 'captcha_failed') {
      return error.message || '人机验证未通过，请重试。';
    }
    if (code === 'email_already_registered') {
      return error.message || '该邮箱已注册。';
    }
    if (code === 'invalid_email_code') {
      return error.message || '邮箱验证码无效或已过期。';
    }
    if (code === 'registration_email_not_allowed') {
      return error.message || '当前邮箱暂不支持注册。';
    }
    if (code === 'temporary_issue') {
      return error.message || '服务暂时不可用，请稍后重试。';
    }
    if (context === 'password_factor_select') {
      return error.message || '无法读取当前账户可用的验证方式。';
    }
    if (context === 'password_code_send') {
      return error.message || '邮箱验证码发送失败，请稍后重试。';
    }
    if (context === 'password_login') {
      return error.message || '登录失败，请检查验证信息后重试。';
    }
    if (context === 'email_code_send') {
      return error.message || '登录验证码发送失败，请稍后重试。';
    }
    if (context === 'email_code_login') {
      return error.message || '登录失败，请检查验证码后重试。';
    }
    return error.message || '请求失败，请稍后重试。';
  }

  function getPasskeySetupErrorMessage(error) {
    if (error?.name === 'NotAllowedError' || error?.name === 'AbortError') {
      return '你已取消本次通行密钥操作，或操作已超时。';
    }
    if (
      error?.name === 'InvalidStateError' ||
      error?.message === 'The object is in an invalid state.'
    ) {
      return '这把通行密钥已存在于当前浏览器或钥匙串中，不能重复添加。';
    }
    if (error?.name === 'NotSupportedError') {
      return '当前浏览器或设备不支持通行密钥。';
    }
    if (error?.name === 'SecurityError') {
      return '当前环境不允许使用通行密钥，请检查域名与安全上下文。';
    }
    return error?.message || '通行密钥添加失败，请稍后再试。';
  }

  const safely = useCallback(async (task, fallbackMessage) => {
    try {
      await task();
    } catch (error) {
      showToast(error.message || fallbackMessage, 'error');
    }
  }, []);

  async function bootstrapSession() {
    const ok = await tryLoadMe();
    if (!ok) {
      logout('登录态失效，请重新登录');
    }
  }

  async function tryLoadMe() {
    try {
      const data = await api('/api/v1/me', { auth: true });
      setSession({ user: data.user, security: data.security || {} });
      setStatus(`已登录：${data.user?.email || ''}`);
      if (!(data.security?.must_bind_email)) {
        void Promise.allSettled([loadSystemConfig(), loadOidcClients()]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  async function loadPublicConfig() {
    try {
      const data = await api('/api/v1/public/config');
      setPublicConfig(data);
    } catch (_) {
      setPublicConfig(null);
    }
  }

  const loadSystemConfig = useCallback(async () => {
    const data = await api('/api/v1/admin/settings', { auth: true });
    setSystemSettings(data.settings || {});
    const smtp = data.settings?.smtp || {};
    const registration = data.settings?.registration || {};
    const security = data.settings?.security || {};
    setSystemForm({
      ...SECURITY_TOGGLE_DEFAULTS,
      ...SECURITY_FIELD_DEFAULTS,
      ...security,
      registration_email_provider_mode: security.registration_email_provider_mode === 'whitelist' ? 'whitelist' : 'blacklist',
      registration_email_provider_blacklist: normalizeProviderList(security.registration_email_provider_blacklist),
      registration_email_provider_whitelist: normalizeProviderList(security.registration_email_provider_whitelist),
      registration_email_provider_blacklist_input: '',
      registration_email_provider_whitelist_input: '',
      hcaptcha_site_key: security.hcaptcha_site_key || '',
      smtp_host: smtp.host || '',
      smtp_port: smtp.port || 587,
      smtp_from: smtp.from || '',
      smtp_username: smtp.username || '',
      smtp_password: smtp.password || '',
      smtp_password_confirm: smtp.password || '',
      smtp_secure: Boolean(smtp.secure),
      registration_email_verify: registration.require_email_verification !== false,
      phone_verification_enabled: security.phone_verification_enabled !== false,
      phone_sms_access_key_id: security.phone_sms_access_key_id || '',
      phone_sms_access_key_secret: '',
      phone_sms_sign_name: security.phone_sms_sign_name || '',
      phone_sms_template_code: security.phone_sms_template_code || '',
      phone_sms_scheme_name: security.phone_sms_scheme_name || '',
    });
  }, [normalizeProviderList, usersPagination.page_size]);

  const loadOidcClients = useCallback(async () => {
    const data = await api('/api/v1/admin/oidc/clients', { auth: true });
    setOidcClients(data.clients || []);
  }, []);

  const loadUsers = useCallback(async ({ page = 1, search = '' } = {}) => {
    const params = new URLSearchParams({
      page: `${page}`,
      page_size: `${usersPagination.page_size || 10}`,
    });
    if (search.trim()) {
      params.set('search', search.trim());
    }
    const data = await api(`/api/v1/admin/users?${params.toString()}`, { auth: true });
    setUsers(data.users || []);
    setUsersPagination(
      data.pagination || { page, page_size: 10, total: data.users?.length || 0, total_pages: 1 },
    );
  }, [usersPagination.page_size]);

  const loadDiscovery = useCallback(async () => {
    const data = await api('/.well-known/openid-configuration');
    setDiscovery(data);
  }, []);

  function ensureHcaptchaScript() {
    return new Promise((resolve, reject) => {
      if (window.hcaptcha) {
        resolve();
        return;
      }
      const existing = document.querySelector('script[data-hcaptcha]');
      if (existing) {
        existing.addEventListener('load', resolve, { once: true });
        existing.addEventListener('error', reject, { once: true });
        return;
      }
      const script = document.createElement('script');
      script.src = 'https://js.hcaptcha.com/1/api.js?render=explicit';
      script.async = true;
      script.defer = true;
      script.dataset.hcaptcha = 'true';
      script.addEventListener('load', resolve, { once: true });
      script.addEventListener('error', reject, { once: true });
      document.body.appendChild(script);
    });
  }

  async function ensurePublicCaptchaWidget() {
    const siteKey = `${publicConfig?.captcha?.site_key || HCAPTCHA_SITE_KEY}`.trim();
    if (!siteKey || !publicHcaptchaRef.current) {
      return null;
    }

    await ensureHcaptchaScript();
    if (
      publicHcaptchaWidgetRef.current !== null &&
      publicHcaptchaMountRef.current === publicHcaptchaRef.current &&
      publicHcaptchaThemeRef.current === resolvedTheme
    ) {
      return publicHcaptchaWidgetRef.current;
    }

    if (publicHcaptchaWidgetRef.current !== null) {
      try {
        window.hcaptcha.remove(publicHcaptchaWidgetRef.current);
      } catch (_) {
        // ignore
      }
      publicHcaptchaWidgetRef.current = null;
    }

    publicHcaptchaWidgetRef.current = window.hcaptcha.render(publicHcaptchaRef.current, {
      sitekey: siteKey,
      theme: resolvedTheme === 'dark' ? 'dark' : 'light',
    });
    publicHcaptchaMountRef.current = publicHcaptchaRef.current;
    publicHcaptchaThemeRef.current = resolvedTheme;
    return publicHcaptchaWidgetRef.current;
  }

  const mountPublicCaptcha = useCallback(() => {
    void ensurePublicCaptchaWidget();
  }, [publicConfig]);

  function getPublicCaptchaToken() {
    if (!window.hcaptcha || publicHcaptchaWidgetRef.current === null) {
      throw new Error('请先完成人机验证');
    }
    const token = window.hcaptcha.getResponse(publicHcaptchaWidgetRef.current);
    if (!token) {
      throw new Error('请先完成人机验证');
    }
    return token;
  }

  function resetPublicCaptcha() {
    if (window.hcaptcha && publicHcaptchaWidgetRef.current !== null) {
      window.hcaptcha.reset(publicHcaptchaWidgetRef.current);
    }
  }

  async function ensureBackgroundCaptchaWidget() {
    const siteKey = `${publicConfig?.captcha?.site_key || HCAPTCHA_SITE_KEY}`.trim();
    if (!siteKey || !backgroundHcaptchaContainerRef.current) {
      return null;
    }

    await ensureHcaptchaScript();
    if (backgroundHcaptchaWidgetRef.current !== null) {
      return backgroundHcaptchaWidgetRef.current;
    }

    backgroundHcaptchaWidgetRef.current = window.hcaptcha.render(backgroundHcaptchaContainerRef.current, {
      sitekey: siteKey,
      size: 'invisible',
      callback: (token) => {
        const pending = backgroundHcaptchaPromiseRef.current;
        if (!pending) {
          return;
        }
        backgroundHcaptchaPromiseRef.current = null;
        pending.resolve(token);
      },
      'error-callback': () => {
        const pending = backgroundHcaptchaPromiseRef.current;
        if (!pending) {
          return;
        }
        backgroundHcaptchaPromiseRef.current = null;
        pending.reject(new Error('人机验证失败，请重试。'));
      },
      'expired-callback': () => {
        const pending = backgroundHcaptchaPromiseRef.current;
        if (!pending) {
          return;
        }
        backgroundHcaptchaPromiseRef.current = null;
        pending.reject(new Error('人机验证已过期，请重试。'));
      },
    });
    return backgroundHcaptchaWidgetRef.current;
  }

  async function executeBackgroundCaptcha() {
    const widgetId = await ensureBackgroundCaptchaWidget();
    if (widgetId === null || !window.hcaptcha) {
      throw new Error('当前未配置 hCaptcha');
    }
    if (backgroundHcaptchaPromiseRef.current) {
      throw new Error('人机验证正在处理中，请稍后再试。');
    }
    return new Promise((resolve, reject) => {
      backgroundHcaptchaPromiseRef.current = { resolve, reject };
      try {
        window.hcaptcha.execute(widgetId);
      } catch (error) {
        backgroundHcaptchaPromiseRef.current = null;
        reject(error instanceof Error ? error : new Error('请先完成人机验证'));
      }
    });
  }

  function resetBackgroundCaptcha() {
    if (window.hcaptcha && backgroundHcaptchaWidgetRef.current !== null) {
      window.hcaptcha.reset(backgroundHcaptchaWidgetRef.current);
    }
  }

  async function submitRegisterCode() {
    setRegisterCodeSending(true);
    try {
      const captchaToken = getPublicCaptchaToken();
      const data = registerMethod === 'phone'
        ? await api('/api/v1/auth/send-phone-register-code', {
            method: 'POST',
            body: { phone_number: registerForm.phone_number.trim(), captcha_token: captchaToken },
          })
        : await api('/api/v1/auth/send-code', {
            method: 'POST',
            body: { email: registerForm.email.trim(), captcha_token: captchaToken },
          });
      showToast(registerMethod === 'phone' ? '验证码已发送，请检查短信。' : '验证码已发送，请检查邮箱。', 'success');
      setRegisterCodeCooldownRemaining(Number(data.retry_after || 0));
    } catch (error) {
      showToast(error.message || '验证码发送失败', 'error');
    } finally {
      resetPublicCaptcha();
      setRegisterCodeSending(false);
    }
  }

  async function requestPasswordLoginCode() {
    setLoginCodeSending(true);
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const data = await api('/api/v1/auth/send-login-code', {
        method: 'POST',
        body: {
          email: loginForm.email.trim(),
          password: loginForm.password,
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      setLoginCodeCooldownRemaining(Number(data.retry_after || 0));
      showToast('邮箱验证码已发送，请完成验证。', 'success');
      return true;
    } catch (error) {
      showToast(getAuthErrorMessage(error, 'password_code_send'), 'error');
      return false;
    } finally {
      resetBackgroundCaptcha();
      setLoginCodeSending(false);
    }
  }

  async function requestPasswordPhoneCode() {
    setLoginCodeSending(true);
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      await api('/api/v1/auth/send-phone-code', {
        method: 'POST',
        body: {
          phone_number: loginForm.phone_number.trim(),
          captcha_token: captchaToken,
        },
      });
      showToast('手机验证码已发送，请完成验证。', 'success');
      setLoginCodeCooldownRemaining(60);
      return true;
    } catch (error) {
      showToast(error.message || '手机验证码发送失败，请稍后重试。', 'error');
      return false;
    } finally {
      resetBackgroundCaptcha();
      setLoginCodeSending(false);
    }
  }

  async function selectPasswordFactor(factor) {
    setSelectedPasswordFactor(factor);
    setLoginForm((current) => ({
      ...current,
      email_code: '',
      phone_code: '',
      authenticator_code: '',
    }));
    if (factor === 'email_code') {
      await requestPasswordLoginCode();
    } else if (factor === 'phone_code') {
      await requestPasswordPhoneCode();
    }
  }

  async function prepareLogin(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const data = await api('/api/v1/auth/password-factors', {
        method: 'POST',
        body: {
          email: loginForm.email.trim(),
          password: loginForm.password,
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      if (data.direct_login) {
        const payload = await api('/api/v1/auth/login', {
          method: 'POST',
          body: {
            email: loginForm.email.trim(),
            password: loginForm.password,
          },
        });
        onLoginSuccess(payload);
        return;
      }
      const factors = Array.isArray(data.factors) ? data.factors : ['email_code'];
      setPasswordLoginFactors(factors);
      setSelectedPasswordFactor('');
      setLoginStep('code');
      showToast('请选择二因素验证方式。', 'success');
    } catch (error) {
      showToast(getAuthErrorMessage(error, 'password_factor_select'), 'error');
    } finally {
      setLoading(false);
    }
  }

  async function completeLogin(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const payload = await api('/api/v1/auth/login', {
        method: 'POST',
        body: {
          email: loginForm.email.trim(),
          password: loginForm.password,
          factor_type: selectedPasswordFactor,
          email_code: loginForm.email_code.trim(),
          phone_code: loginForm.phone_code.trim(),
          authenticator_code: loginForm.authenticator_code.trim(),
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      onLoginSuccess(payload);
    } catch (error) {
      showToast(getAuthErrorMessage(error, 'password_login'), 'error');
    } finally {
      setLoading(false);
    }
  }

  async function requestEmailCodeLogin() {
    setLoginCodeSending(true);
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const data = await api('/api/v1/auth/send-email-login-code', {
        method: 'POST',
        body: {
          email: loginForm.email.trim(),
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      setLoginStep('code');
      setLoginCodeCooldownRemaining(Number(data.retry_after || 0));
      showToast('登录验证码已发送，请检查邮箱。', 'success');
    } catch (error) {
      showToast(getAuthErrorMessage(error, 'email_code_send'), 'error');
    } finally {
      resetBackgroundCaptcha();
      setLoginCodeSending(false);
    }
  }

  async function requestPhoneCodeLogin() {
    setLoginCodeSending(true);
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const data = await api('/api/v1/auth/send-phone-login-code', {
        method: 'POST',
        body: {
          phone_number: loginForm.phone_number.trim(),
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      setLoginStep('code');
      setLoginCodeCooldownRemaining(Math.max(60, Number(data.retry_after || 0)));
      showToast('请求已受理。若该手机号已绑定账号，将收到短信验证码。', 'success');
    } catch (error) {
      showToast(error.message || '登录验证码发送失败，请稍后重试。', 'error');
    } finally {
      resetBackgroundCaptcha();
      setLoginCodeSending(false);
    }
  }

  async function preparePhoneCodeLogin(event) {
    event.preventDefault();
    setLoading(true);
    try {
      await requestPhoneCodeLogin();
    } finally {
      setLoading(false);
    }
  }

  async function completePhoneCodeLogin(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const payload = await api('/api/v1/auth/phone-login', {
        method: 'POST',
        body: {
          phone_number: loginForm.phone_number.trim(),
          verify_code: loginForm.phone_code.trim(),
        },
      });
      onLoginSuccess(payload);
    } catch (error) {
      showToast(error.message || '登录失败，请检查验证码后重试。', 'error');
    } finally {
      setLoading(false);
    }
  }

  async function prepareEmailCodeLogin(event) {
    event.preventDefault();
    setLoading(true);
    try {
      await requestEmailCodeLogin();
    } finally {
      setLoading(false);
    }
  }

  async function completeEmailCodeLogin(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const payload = await api('/api/v1/auth/email-login', {
        method: 'POST',
        body: {
          email: loginForm.email.trim(),
          email_code: loginForm.email_code.trim(),
        },
      });
      onLoginSuccess(payload);
    } catch (error) {
      showToast(getAuthErrorMessage(error, 'email_code_login'), 'error');
    } finally {
      setLoading(false);
    }
  }

  const loadLoginCodeCooldown = useCallback(async () => {
    if (!loginForm.email.trim()) {
      setLoginCodeCooldownRemaining(0);
      return;
    }
    try {
      const flow = loginMethod === 'password' && selectedPasswordFactor === 'email_code'
        ? 'mfa'
        : 'login';
      const data = await api(`/api/v1/auth/login-code-status?email=${encodeURIComponent(loginForm.email.trim())}&flow=${encodeURIComponent(flow)}`);
      setLoginCodeCooldownRemaining(Number(data.retry_after || 0));
    } catch (_) {
      setLoginCodeCooldownRemaining(0);
    }
  }, [loginForm.email, loginMethod, selectedPasswordFactor]);

  function onLoginSuccess(payload) {
    setSession({ user: payload.user, security: payload.security || {} });
    setStatus(`已登录：${payload.user?.email || ''}`);
    setLoginMethod('phone_code');
    setLoginStep('credentials');
    setPasswordLoginFactors([]);
    setSelectedPasswordFactor('phone_code');
    setLoginForm({
      email: payload.user?.email || '',
      phone_number: payload.user?.phone_number || '',
      password: '',
      email_code: '',
      phone_code: '',
      authenticator_code: '',
    });
    if (!(payload.security?.must_bind_email)) {
      void Promise.allSettled([loadSystemConfig(), loadOidcClients()]);
    }
    if (pendingAuthRedirect && payload.post_register_passkey_bootstrap !== true) {
      window.location.replace(pendingAuthRedirect);
      return;
    }
    showToast('登录成功', 'success');
  }

  async function submitRegister(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const payload = registerMethod === 'phone'
        ? await api('/api/v1/auth/register-phone', {
            method: 'POST',
            body: {
              phone_number: registerForm.phone_number.trim(),
              verify_code: registerForm.phone_code.trim(),
              nickname: registerForm.nickname.trim(),
              password: registerForm.password,
            },
          })
        : await api('/api/v1/auth/register', {
            method: 'POST',
            body: {
              email: registerForm.email.trim(),
              email_code: registerForm.email_code.trim(),
              nickname: registerForm.nickname.trim(),
              password: registerForm.password,
            },
          });
      onLoginSuccess(payload);
      setRegisterForm({
        email: '',
        email_code: '',
        phone_number: '',
        phone_code: '',
        nickname: '',
        password: '',
      });
      setPostRegisterPasskeyError('');
      setPostRegisterMethod(registerMethod);
      setPostRegisterPasskeyPromptOpen(
        payload.post_register_passkey_bootstrap === true,
      );
    } catch (error) {
      showToast(getAuthErrorMessage(error, 'register'), 'error');
    } finally {
      setLoading(false);
    }
  }

  async function completePostRegisterPasskeySetup() {
    setPostRegisterPasskeyError('');
    setPostRegisterPasskeySaving(true);
    try {
      const options = await beginWebAuthnRegistration({
        post_register_bootstrap: true,
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
      setPostRegisterPasskeyPromptOpen(false);
      if (pendingAuthRedirect) {
        window.location.replace(pendingAuthRedirect);
        return;
      }
      showToast('系统通行密钥已连接，后续可更快捷登录。', 'success');
    } catch (error) {
      setPostRegisterPasskeyError(getPasskeySetupErrorMessage(error));
    } finally {
      setPostRegisterPasskeySaving(false);
    }
  }

  async function updateNicknameSilently(nickname) {
    await api('/api/v1/me', {
      method: 'PATCH',
      auth: true,
      body: { nickname },
    });
    await tryLoadMe();
  }

  async function sendBindEmailCode(payload) {
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const result = await api('/api/v1/me/send-bind-email-code', {
        method: 'POST',
        auth: true,
        body: {
          ...payload,
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      showToast('验证码已发送，请注意查收邮箱。', 'success');
      return result;
    } finally {
      resetBackgroundCaptcha();
    }
  }

  async function bindEmail(payload) {
    const result = await api('/api/v1/me/bind-email', {
      method: 'POST',
      auth: true,
      body: payload,
    });
    redirectToLoginWithToast('邮箱绑定成功，请重新登录。');
    return result;
  }

  async function sendBindPhoneCode(payload) {
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const result = await api('/api/v1/me/send-bind-phone-code', {
        method: 'POST',
        auth: true,
        body: {
          ...payload,
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      showToast('验证码已发送，请注意查收短信。', 'success');
      return result;
    } finally {
      resetBackgroundCaptcha();
    }
  }

  async function bindPhone(payload) {
    const result = await api('/api/v1/me/bind-phone', {
      method: 'POST',
      auth: true,
      body: payload,
    });
    redirectToLoginWithToast('手机号绑定成功，请重新登录。');
    return result;
  }

  async function sendPasswordResetCode() {
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const result = await api('/api/v1/me/send-password-reset-code', {
        method: 'POST',
        auth: true,
        body: {
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      showToast('验证码已发送，请注意查收邮箱。', 'success');
      return result;
    } finally {
      resetBackgroundCaptcha();
    }
  }

  async function resetPasswordWithCode(payload) {
    const result = await api('/api/v1/me/reset-password', {
      method: 'POST',
      auth: true,
      body: payload,
    });
    redirectToLoginWithToast('密码已重置，请使用新密码重新登录。');
    return result;
  }

  async function beginAuthenticatorSetup(payload) {
    return api('/api/v1/me/authenticator/setup', {
      method: 'POST',
      auth: true,
      body: payload,
    });
  }

  async function verifyAuthenticatorSetup(payload) {
    const result = await api('/api/v1/me/authenticator/verify', {
      method: 'POST',
      auth: true,
      body: payload,
    });
    const nextSecurity = {
      ...(session.security || {}),
      has_authenticator: true,
    };
    setSession((current) => ({
      ...current,
      security: nextSecurity,
    }));
    showToast('Authenticator 验证器已启用', 'success');
    return result;
  }

  async function beginWebAuthnRegistration(payload) {
    return api('/api/v1/me/webauthn/register/options', {
      method: 'POST',
      auth: true,
      body: payload,
    });
  }

  async function verifyWebAuthnRegistration(payload) {
    const result = await api('/api/v1/me/webauthn/register/verify', {
      method: 'POST',
      auth: true,
      body: payload,
    });
    const nextSecurity = {
      ...(session.security || {}),
      has_passkey: true,
    };
    setSession((current) => ({
      ...current,
      security: nextSecurity,
    }));
    showToast('系统通行密钥已连接', 'success');
    return result;
  }

  async function listWebAuthnCredentials() {
    return api('/api/v1/me/webauthn/credentials', {
      auth: true,
    });
  }

  async function deleteWebAuthnCredential(credentialId) {
    const result = await api(
      `/api/v1/me/webauthn/credentials/${encodeURIComponent(credentialId)}`,
      {
        method: 'DELETE',
        auth: true,
      },
    );
    setSession((current) => ({
      ...current,
      security: {
        ...(current.security || {}),
        has_passkey: true,
      },
    }));
    showToast('系统通行密钥已移除', 'success');
    await tryLoadMe();
    return result;
  }

  async function sendRecoveryCode(payload) {
    try {
      const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
      const result = await api('/api/v1/auth/send-recovery-code', {
        method: 'POST',
        body: {
          method: payload.method,
          account: payload.account,
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      showToast('若账号存在，验证码已发送。', 'success');
      return result;
    } finally {
      resetBackgroundCaptcha();
    }
  }

  async function resetPasswordByCode(payload) {
    const result = await api('/api/v1/auth/reset-password-by-code', {
      method: 'POST',
      body: payload,
    });
    redirectToLoginWithToast('密码已重置，请使用新密码登录。');
    return result;
  }

  async function beginWebAuthnLogin(email = '') {
    return api('/api/v1/auth/webauthn/options', {
      method: 'POST',
      body: email ? { email } : {},
    });
  }

  async function completeWebAuthnLogin(email, response) {
    const payload = await api('/api/v1/auth/webauthn/verify', {
      method: 'POST',
      body: email ? { email, response } : { response },
    });
    onLoginSuccess(payload);
    return payload;
  }

  async function saveServiceConfig(event) {
    event.preventDefault();
    if (systemForm.smtp_password !== systemForm.smtp_password_confirm) {
      showToast('两次输入的 SMTP 密码不一致', 'error');
      return;
    }
    try {
      await api('/api/v1/admin/settings', {
        method: 'PUT',
        auth: true,
        body: {
          security: {
            hcaptcha_site_key: systemForm.hcaptcha_site_key || '',
            hcaptcha_secret: systemForm.hcaptcha_secret || '',
            phone_verification_enabled: Boolean(systemForm.phone_verification_enabled ?? true),
            phone_sms_access_key_id: systemForm.phone_sms_access_key_id || '',
            phone_sms_access_key_secret: systemForm.phone_sms_access_key_secret || '',
            phone_sms_sign_name: systemForm.phone_sms_sign_name || '',
            phone_sms_template_code: systemForm.phone_sms_template_code || '',
            phone_sms_scheme_name: systemForm.phone_sms_scheme_name || '',
          },
          registration: {
            require_email_verification: Boolean(systemForm.registration_email_verify),
          },
          smtp: {
            host: systemForm.smtp_host || '',
            port: Number(systemForm.smtp_port || 587),
            from: systemForm.smtp_from || '',
            username: systemForm.smtp_username || '',
            password: systemForm.smtp_password || '',
            secure: Boolean(systemForm.smtp_secure),
          },
        },
      });
      await loadSystemConfig();
      await loadPublicConfig();
      showToast('服务配置已保存', 'success');
    } catch (error) {
      showToast(error.message || '保存失败', 'error');
    }
  }

  async function testSmtpConnection() {
    try {
      await api('/api/v1/admin/settings', {
        method: 'PUT',
        auth: true,
        body: {
          security: {
            hcaptcha_site_key: systemForm.hcaptcha_site_key || '',
            hcaptcha_secret: systemForm.hcaptcha_secret || '',
            phone_verification_enabled: Boolean(systemForm.phone_verification_enabled ?? true),
            phone_sms_access_key_id: systemForm.phone_sms_access_key_id || '',
            phone_sms_access_key_secret: systemForm.phone_sms_access_key_secret || '',
            phone_sms_sign_name: systemForm.phone_sms_sign_name || '',
            phone_sms_template_code: systemForm.phone_sms_template_code || '',
            phone_sms_scheme_name: systemForm.phone_sms_scheme_name || '',
          },
          registration: {
            require_email_verification: Boolean(systemForm.registration_email_verify),
          },
          smtp: {
            host: systemForm.smtp_host || '',
            port: Number(systemForm.smtp_port || 587),
            from: systemForm.smtp_from || '',
            username: systemForm.smtp_username || '',
            password: systemForm.smtp_password || '',
            secure: Boolean(systemForm.smtp_secure),
          },
        },
      });
      const result = await api('/api/v1/admin/settings/smtp-test', {
        method: 'POST',
        auth: true,
      });
      showToast(result.message || 'SMTP 连接验证成功。', 'success');
      await loadSystemConfig();
      await loadPublicConfig();
    } catch (error) {
      showToast(error.message || 'SMTP 连接验证失败。', 'error');
    }
  }

  async function testHcaptchaConnection() {
    try {
      await api('/api/v1/admin/settings', {
        method: 'PUT',
        auth: true,
        body: {
          security: {
            hcaptcha_site_key: systemForm.hcaptcha_site_key || '',
            hcaptcha_secret: systemForm.hcaptcha_secret || '',
          },
          registration: {
            require_email_verification: Boolean(systemForm.registration_email_verify),
          },
        },
      });
      const result = await api('/api/v1/admin/settings/hcaptcha-test', {
        method: 'POST',
        auth: true,
      });
      showToast(result.message || 'hCaptcha 连接验证成功。', 'success');
      await loadSystemConfig();
      await loadPublicConfig();
    } catch (error) {
      showToast(error.message || 'hCaptcha 连接验证失败。', 'error');
    }
  }

  async function testPhoneSmsConnection() {
    try {
      await api('/api/v1/admin/settings', {
        method: 'PUT',
        auth: true,
        body: {
          security: {
            phone_verification_enabled: Boolean(systemForm.phone_verification_enabled ?? true),
            phone_sms_access_key_id: systemForm.phone_sms_access_key_id || '',
            phone_sms_access_key_secret: systemForm.phone_sms_access_key_secret || '',
            phone_sms_sign_name: systemForm.phone_sms_sign_name || '',
            phone_sms_template_code: systemForm.phone_sms_template_code || '',
            phone_sms_scheme_name: systemForm.phone_sms_scheme_name || '',
          },
        },
      });
      const result = await api('/api/v1/admin/settings/phone-sms-test', {
        method: 'POST',
        auth: true,
      });
      showToast(result.message || '短信配置验证成功。', 'success');
      await loadSystemConfig();
    } catch (error) {
      showToast(error.message || '短信配置验证失败。', 'error');
    }
  }

  async function saveSecurityPolicy(event) {
    event.preventDefault();
    const security = SECURITY_FIELDS.reduce(
      (result, [key]) => ({ ...result, [key]: Number(systemForm[key] || 0) }),
      {
        email_rate_limit_enabled: Boolean(systemForm.email_rate_limit_enabled ?? true),
        ip_rate_limit_enabled: Boolean(systemForm.ip_rate_limit_enabled ?? true),
        email_code_max_attempts: Number(systemForm.email_code_max_attempts || 0),
        registration_email_provider_mode:
          systemForm.registration_email_provider_mode === 'whitelist' ? 'whitelist' : 'blacklist',
        registration_email_provider_blacklist: normalizeProviderList(systemForm.registration_email_provider_blacklist),
        registration_email_provider_whitelist: normalizeProviderList(systemForm.registration_email_provider_whitelist),
      },
    );
    try {
      await api('/api/v1/admin/settings', {
        method: 'PUT',
        auth: true,
        body: { security },
      });
      await loadSystemConfig();
      showToast('安全策略已保存', 'success');
    } catch (error) {
      showToast(error.message || '保存失败', 'error');
    }
  }

  function addRegistrationProvider(listKey, inputKey) {
    const provider = normalizeProvider(systemForm[inputKey]);
    if (!/^@[a-z0-9.-]+\.[a-z]{2,}$/i.test(provider)) {
      showToast('请输入合法的邮箱提供商，例如 @gmail.com', 'error');
      return;
    }
    const currentList = normalizeProviderList(systemForm[listKey]);
    if (currentList.includes(provider)) {
      showToast(`${provider} 已存在于当前名单中`, 'error');
      return;
    }
    setSystemForm((current) => ({
      ...current,
      [listKey]: [...currentList, provider],
      [inputKey]: '',
    }));
  }

  async function importRegistrationProviders(listKey, file) {
    if (!file) {
      return;
    }

    if (!/\.txt$/i.test(file.name) && file.type && file.type !== 'text/plain') {
      showToast('请上传 txt 文本文件', 'error');
      return;
    }

    const content = await file.text();
    const importedProviders = content
      .split(/\r?\n/)
      .map((item) => item.trim())
      .filter(Boolean)
      .map((item) => normalizeProvider(item));
    const validProviders = importedProviders.filter((item) => /^@[a-z0-9.-]+\.[a-z]{2,}$/i.test(item));

    if (!validProviders.length) {
      showToast('未在 txt 文件中识别到合法的邮箱提供商', 'error');
      return;
    }

    setSystemForm((current) => {
      const merged = normalizeProviderList([...(current[listKey] || []), ...validProviders]);
      return {
        ...current,
        [listKey]: merged,
      };
    });
    showToast(`已导入 ${normalizeProviderList(validProviders).length} 个邮箱提供商`, 'success');
  }

  function removeRegistrationProvider(listKey, provider) {
    setSystemForm((current) => ({
      ...current,
      [listKey]: normalizeProviderList(current[listKey]).filter((item) => item !== provider),
    }));
  }

  async function createManagedUser(form) {
    const roles = `${form.roles || ''}`
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean)
      .reduce((items, item) => (items.includes(item) ? items : [...items, item]), []);
    if (!form.email?.trim() || !form.nickname?.trim() || !form.password || !roles.length) {
      throw new Error('邮箱、昵称、密码和至少一个角色都是必填项。');
    }

    await api('/api/v1/admin/users', {
      method: 'POST',
      auth: true,
      body: {
        email: form.email.trim(),
        nickname: form.nickname.trim(),
        password: form.password,
        roles,
      },
    });
    showToast('用户已创建', 'success');
  }

  async function updateManagedUserRoles(userId, rolesInput) {
    const roles = `${rolesInput || ''}`
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean)
      .reduce((items, item) => (items.includes(item) ? items : [...items, item]), []);
    if (!roles.length) {
      throw new Error('至少保留一个角色或权限标识。');
    }

    await api(`/api/v1/admin/users/${encodeURIComponent(userId)}/roles`, {
      method: 'PATCH',
      auth: true,
      body: { roles },
    });
    showToast('用户权限已更新', 'success');
  }

  async function deleteManagedUser(userId) {
    await api(`/api/v1/admin/users/${encodeURIComponent(userId)}`, {
      method: 'DELETE',
      auth: true,
    });
    showToast('用户已删除', 'success');
  }

  async function saveOidcClient(event) {
    event.preventDefault();
    const parseLines = (value, fallback = []) =>
      value
        .split('\n')
        .map((item) => item.trim())
        .filter(Boolean)
        .reduce((items, item) => (items.includes(item) ? items : [...items, item]), fallback);
    try {
      await api(`/api/v1/admin/oidc/clients/${encodeURIComponent(oidcForm.client_id.trim())}`, {
        method: 'PUT',
        auth: true,
        body: {
          client_id: oidcForm.client_id.trim(),
          display_name: oidcForm.display_name.trim(),
          is_official: Boolean(oidcForm.is_official),
          redirect_uris: parseLines(oidcForm.redirect_uris),
          scopes: parseLines(oidcForm.scopes, ['openid', 'profile', 'email', 'phone']),
          grant_types: parseLines(oidcForm.grant_types, ['authorization_code', 'refresh_token']),
          client_secret: oidcForm.client_secret,
          is_confidential: Boolean(oidcForm.is_confidential),
          is_active: Boolean(oidcForm.is_active),
        },
      });
      await loadOidcClients();
      setOidcForm((current) => ({ ...current, client_secret: '' }));
      showToast('OIDC 客户端已保存', 'success');
    } catch (error) {
      showToast(error.message || '保存失败', 'error');
    }
  }

  async function deleteOidcClient(clientId) {
    await api(`/api/v1/admin/oidc/clients/${encodeURIComponent(clientId)}`, {
      method: 'DELETE',
      auth: true,
    });
    await loadOidcClients();
    showToast('OIDC 应用已删除', 'success');
  }

  function logout(nextStatus = '') {
    void fetch(`${API_BASE}/api/v1/auth/logout`, {
      method: 'POST',
      credentials: 'include',
    }).catch(() => {});
    setSession({ user: null, security: null });
    setStatus(nextStatus);
    setUsers([]);
    setUsersPagination({ page: 1, page_size: 10, total: 0, total_pages: 0 });
    setDiscovery(null);
    setOidcClients([]);
    setSystemSettings(null);
    setLoginMethod('phone_code');
    setLoginStep('credentials');
    setPasswordLoginFactors([]);
    setSelectedPasswordFactor('phone_code');
  }

  return (
    <>
      <div
        ref={backgroundHcaptchaContainerRef}
        aria-hidden="true"
        style={{ position: 'fixed', left: '-9999px', top: '0', width: '1px', height: '1px', opacity: 0, pointerEvents: 'none' }}
      />
      <BrowserRouter>
      {toast && (
        <div className={`fixed right-5 top-5 z-50 rounded-2xl px-4 py-3 text-sm font-medium shadow-lg ${toast.type === 'error' ? 'bg-red-50 text-red-700' : 'bg-sage-900 text-white'}`}>
          {toast.message}
        </div>
      )}
        <PostRegisterPasskeyPrompt
          open={postRegisterPasskeyPromptOpen}
          registrationMethod={postRegisterMethod}
          saving={postRegisterPasskeySaving}
          error={postRegisterPasskeyError}
          onConfirm={() => void completePostRegisterPasskeySetup()}
          onSkip={() => {
            setPostRegisterPasskeyError('');
            setPostRegisterPasskeyPromptOpen(false);
            if (pendingAuthRedirect) {
              window.location.replace(pendingAuthRedirect);
              return;
            }
          }}
        />
        <AppRoutes
        isLoggedIn={isLoggedIn}
        defaultAuthedPath={defaultAuthedPath}
        loginForm={loginForm}
        setLoginForm={setLoginForm}
        loginMethod={loginMethod}
        setLoginMethod={setLoginMethod}
        loginStep={loginStep}
        setLoginStep={setLoginStep}
        loading={loading}
        loginCodeSending={loginCodeSending}
        loginCodeCooldownRemaining={loginCodeCooldownRemaining}
        passwordLoginFactors={passwordLoginFactors}
        selectedPasswordFactor={selectedPasswordFactor}
        setSelectedPasswordFactor={setSelectedPasswordFactor}
        selectPasswordFactor={selectPasswordFactor}
        prepareLogin={prepareLogin}
        completeLogin={completeLogin}
        prepareEmailCodeLogin={prepareEmailCodeLogin}
        completeEmailCodeLogin={completeEmailCodeLogin}
        preparePhoneCodeLogin={preparePhoneCodeLogin}
        completePhoneCodeLogin={completePhoneCodeLogin}
        requestPasswordLoginCode={requestPasswordLoginCode}
        requestPasswordPhoneCode={requestPasswordPhoneCode}
        requestEmailCodeLogin={requestEmailCodeLogin}
        requestPhoneCodeLogin={requestPhoneCodeLogin}
        loadLoginCodeCooldown={loadLoginCodeCooldown}
        beginWebAuthnLogin={beginWebAuthnLogin}
        completeWebAuthnLogin={completeWebAuthnLogin}
        registerForm={registerForm}
        setRegisterForm={setRegisterForm}
        registerMethod={registerMethod}
        setRegisterMethod={setRegisterMethod}
        registerCodeSending={registerCodeSending}
        registerCodeCooldownRemaining={registerCodeCooldownRemaining}
        submitRegister={submitRegister}
        submitRegisterCode={submitRegisterCode}
        publicHcaptchaRef={publicHcaptchaRef}
        publicConfig={publicConfig}
        mountPublicCaptcha={mountPublicCaptcha}
        sendRecoveryCode={sendRecoveryCode}
        resetPasswordByCode={resetPasswordByCode}
        session={session}
        logout={logout}
        mustBindEmail={mustBindEmail}
        updateNicknameSilently={updateNicknameSilently}
        sendBindEmailCode={sendBindEmailCode}
        bindEmail={bindEmail}
        sendBindPhoneCode={sendBindPhoneCode}
        bindPhone={bindPhone}
        sendPasswordResetCode={sendPasswordResetCode}
        resetPasswordWithCode={resetPasswordWithCode}
        beginAuthenticatorSetup={beginAuthenticatorSetup}
        verifyAuthenticatorSetup={verifyAuthenticatorSetup}
        beginWebAuthnRegistration={beginWebAuthnRegistration}
        verifyWebAuthnRegistration={verifyWebAuthnRegistration}
        listWebAuthnCredentials={listWebAuthnCredentials}
        deleteWebAuthnCredential={deleteWebAuthnCredential}
        systemForm={systemForm}
        setSystemForm={setSystemForm}
        saveServiceConfig={saveServiceConfig}
        testSmtpConnection={testSmtpConnection}
        testHcaptchaConnection={testHcaptchaConnection}
        testPhoneSmsConnection={testPhoneSmsConnection}
        users={users}
        usersPagination={usersPagination}
        loadUsers={loadUsers}
        createManagedUser={createManagedUser}
        updateManagedUserRoles={updateManagedUserRoles}
        deleteManagedUser={deleteManagedUser}
        safely={safely}
        discovery={discovery}
        systemSettings={systemSettings}
        loadDiscovery={loadDiscovery}
        oidcClients={oidcClients}
        loadOidcClients={loadOidcClients}
        oidcForm={oidcForm}
        setOidcForm={setOidcForm}
        saveOidcClient={saveOidcClient}
        deleteOidcClient={deleteOidcClient}
          saveSecurityPolicy={saveSecurityPolicy}
          addRegistrationProvider={addRegistrationProvider}
          importRegistrationProviders={importRegistrationProviders}
          removeRegistrationProvider={removeRegistrationProvider}
          isAdmin={isAdmin}
        />
      </BrowserRouter>
    </>
  );
}

export default App;
