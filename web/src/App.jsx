import { lazy, Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import { AdminLayout, UserLayout } from './components/Layouts';
import { ALIYUN_CAPTCHA_PREFIX, ALIYUN_CAPTCHA_SCENE_ID, API_BASE, SECURITY_FIELDS, SECURITY_FIELD_DEFAULTS, SECURITY_TOGGLE_DEFAULTS } from './constants';
import { useTheme } from './theme';
import { getUserErrorMessage, getUserMessage } from './lib/errors';
import { oidcAuthorizationParameters } from './lib/oidc';
import { normalizeInternalRedirect } from './lib/redirects';
import { createSingleFlightRefresh, requestWithSessionRefresh } from './lib/session';
import { preparePublicKeyCreationOptions, serializeRegistrationCredential } from './lib/utils';

const POST_LOGIN_TOAST_STORAGE_KEY = 'rosm_pending_toast';
const PENDING_OIDC_SEARCH_STORAGE_KEY = 'rosm_pending_oidc_search';
const lazyNamed = (loader, name) => lazy(() => loader().then((module) => ({ default: module[name] })));
const loadAdminPages = () => import('./pages/AdminPages');
const loadAuthPages = () => import('./pages/AuthPages');
const AdminFlutterSdkDocsPage = lazyNamed(loadAdminPages, 'AdminFlutterSdkDocsPage');
const AdminOIDCConfig = lazyNamed(loadAdminPages, 'AdminOIDCConfig');
const AdminOidcDocsPage = lazyNamed(loadAdminPages, 'AdminOidcDocsPage');
const AdminSecurityPolicy = lazyNamed(loadAdminPages, 'AdminSecurityPolicy');
const AdminServiceConfig = lazyNamed(loadAdminPages, 'AdminServiceConfig');
const AdminUsers = lazyNamed(loadAdminPages, 'AdminUsers');
const ForgotPasswordPage = lazyNamed(loadAuthPages, 'ForgotPasswordPage');
const LoginPage = lazyNamed(loadAuthPages, 'LoginPage');
const PostRegisterBindingPrompt = lazyNamed(loadAuthPages, 'PostRegisterBindingPrompt');
const PostRegisterPasskeyPrompt = lazyNamed(loadAuthPages, 'PostRegisterPasskeyPrompt');
const RegisterPage = lazyNamed(loadAuthPages, 'RegisterPage');
const UserAccountPage = lazyNamed(() => import('./pages/UserPages'), 'UserAccountPage');

function AppRoutes({
  isLoggedIn,
  defaultAuthedPath,
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
  publicCaptchaRef,
  publicConfig,
  captchaConfigured,
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
  sendStepUpCode,
  beginStepUpPasskey,
  systemForm,
  setSystemForm,
  saveServiceConfig,
  testSmtpConnection,
  testAliyunCaptchaConnection,
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
    ? normalizeInternalRedirect(new URLSearchParams(location.search).get('next'))
    : '';
  const registerNext = location.pathname === '/register'
    ? normalizeInternalRedirect(new URLSearchParams(location.search).get('next'))
    : '';
  const forgotNext = location.pathname === '/forgot-password'
    ? normalizeInternalRedirect(new URLSearchParams(location.search).get('next'))
    : '';

  return (
    <Suspense fallback={<div className="min-h-screen bg-slate-50" aria-busy="true" />}>
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
                rememberMe={rememberMe}
                setRememberMe={setRememberMe}
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
                selectDirectLoginStepUpFactor={selectDirectLoginStepUpFactor}
                completeDirectLoginStepUp={completeDirectLoginStepUp}
                beginDirectLoginStepUpPasskey={beginDirectLoginStepUpPasskey}
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
              <PostLoginRedirect target={registerNext} fallback={defaultAuthedPath} />
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
                captchaRef={publicCaptchaRef}
                publicConfig={publicConfig}
                captchaConfigured={captchaConfigured}
                mountCaptcha={mountPublicCaptcha}
                authNext={registerNext}
              />
            )
          }
        />
        <Route path="/forgot-password" element={isLoggedIn ? <PostLoginRedirect target={forgotNext} fallback={defaultAuthedPath} /> : <ForgotPasswordPage loading={loading} sendRecoveryCode={sendRecoveryCode} resetPasswordByCode={resetPasswordByCode} beginWebAuthnLogin={beginWebAuthnLogin} authNext={forgotNext} />} />

        <Route path="/docs" element={<Navigate to="/docs/oidc" replace />} />
        <Route path="/docs/oidc" element={<AdminOidcDocsPage discovery={discovery} />} />
        <Route path="/docs/flutter-sdk" element={<AdminFlutterSdkDocsPage discovery={discovery} />} />
        <Route path="/admin/oidc/docs" element={<AdminOidcDocsPage discovery={discovery} />} />
        <Route path="/admin/oidc/docs/flutter-sdk" element={<AdminFlutterSdkDocsPage discovery={discovery} />} />

        <Route
          path="/oidc/continue"
          element={
            isLoggedIn ? (
              <OidcContinueRedirect />
            ) : (
              <Navigate
                to={`/login?next=${encodeURIComponent(`${location.pathname}${location.search}`)}`}
                replace
              />
            )
          }
        />

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
                sendStepUpCode={sendStepUpCode}
                beginStepUpPasskey={beginStepUpPasskey}
              />
            }
          />
          <Route path="service" element={<AdminServiceConfig systemForm={systemForm} setSystemForm={setSystemForm} saveServiceConfig={saveServiceConfig} testSmtpConnection={testSmtpConnection} testAliyunCaptchaConnection={testAliyunCaptchaConnection} testPhoneSmsConnection={testPhoneSmsConnection} />} />
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
                sendStepUpCode={sendStepUpCode}
                beginStepUpPasskey={beginStepUpPasskey}
              />
            }
          />
        </Route>

        <Route path="/" element={<Navigate to={isLoggedIn ? defaultAuthedPath : '/login'} replace />} />
        <Route path="*" element={<Navigate to={isLoggedIn ? defaultAuthedPath : '/login'} replace />} />
      </Routes>
    </Suspense>
  );
}

function PostLoginRedirect({ target, fallback }) {
  return <Navigate to={normalizeInternalRedirect(target) || fallback} replace />;
}

function OidcContinueRedirect() {
  const location = useLocation();
  const formRef = useRef(null);
  const authorizationEndpoint = new URL('/oidc/authorize', API_BASE).toString();
  const authorizationSearch = location.search || (() => {
    try {
      return window.sessionStorage.getItem(PENDING_OIDC_SEARCH_STORAGE_KEY) || '';
    } catch (_) {
      return '';
    }
  })();
  const authorizationParameters = useMemo(
    () => oidcAuthorizationParameters(authorizationSearch),
    [authorizationSearch],
  );

  useEffect(() => {
    try {
      window.sessionStorage.removeItem(PENDING_OIDC_SEARCH_STORAGE_KEY);
    } catch (_) {
      // The form can still continue using the parameters already read above.
    }
    formRef.current?.submit();
  }, []);

  return (
    <main className="flex min-h-dvh items-center justify-center bg-sage-50 px-5 text-center" aria-busy="true">
      <form ref={formRef} method="get" action={authorizationEndpoint} className="space-y-4">
        {authorizationParameters.map(([name, value], index) => (
          <input key={`${name}-${index}`} type="hidden" name={name} value={value} />
        ))}
        <p className="text-sm font-semibold text-sage-700">正在继续授权流程…</p>
        <button type="submit" className="btn-primary px-5 py-3 text-sm font-bold">
          继续授权
        </button>
      </form>
    </main>
  );
}

function App() {
  const navigate = useNavigate();
  const location = useLocation();
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
  const [rememberMe, setRememberMe] = useState(false);
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
  const [loginStepUpChallenge, setLoginStepUpChallenge] = useState('');
  const [postRegisterPasskeyPromptOpen, setPostRegisterPasskeyPromptOpen] = useState(false);
  const [postRegisterPasskeySaving, setPostRegisterPasskeySaving] = useState(false);
  const [postRegisterPasskeyError, setPostRegisterPasskeyError] = useState('');
  const [postRegisterMethod, setPostRegisterMethod] = useState('email');
  const [pendingAuthRedirect, setPendingAuthRedirect] = useState('');
  const [postRegisterBindingPromptOpen, setPostRegisterBindingPromptOpen] = useState(false);
  const [postRegisterBindingPassword, setPostRegisterBindingPassword] = useState('');
  const [postRegisterPasskeyPending, setPostRegisterPasskeyPending] = useState(false);

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
    registration_handoff: '',
  });
  const [registerMethod, setRegisterMethod] = useState('email');
  const [systemForm, setSystemForm] = useState({});
  const [oidcForm, setOidcForm] = useState({
    client_id: '',
    display_name: '',
    is_official: false,
    enable_web: true,
    enable_app: false,
    web_redirect_uris: '',
    app_redirect_uri: '',
    redirect_uris: '',
    scopes: 'openid\nprofile\nemail\nphone',
    grant_types: 'authorization_code\nrefresh_token',
    client_secret: '',
    generate_client_secret: false,
    is_confidential: false,
    is_active: true,
  });

  const publicCaptchaRef = useRef(null);
  const publicCaptchaInstanceRef = useRef(null);
  const publicCaptchaTokenRef = useRef('');
  const publicCaptchaConfigRef = useRef('');
  const backgroundCaptchaContainerRef = useRef(null);
  const backgroundCaptchaButtonRef = useRef(null);
  const backgroundCaptchaInstanceRef = useRef(null);
  const backgroundCaptchaPromiseRef = useRef(null);
  const refreshFirstPartySession = useMemo(
    () => createSingleFlightRefresh(async () => {
      const response = await fetch(`${API_BASE}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        credentials: 'include',
        cache: 'no-store',
        body: '{}',
      });
      return response.ok;
    }),
    [],
  );

  const isLoggedIn = Boolean(session.user);
  const isAdmin = session.user?.roles?.includes('admin');
  const mustBindEmail = Boolean(session.security?.must_bind_email);
  const defaultAuthedPath = isAdmin ? '/admin/account' : '/account';
  const continuePostAuth = useCallback((target) => {
    const normalized = normalizeInternalRedirect(target);
    if (!normalized) {
      return false;
    }
    const parsed = new URL(normalized, window.location.origin);
    if (parsed.pathname !== '/oidc/continue') {
      return false;
    }
    try {
      window.sessionStorage.setItem(PENDING_OIDC_SEARCH_STORAGE_KEY, parsed.search);
    } catch (_) {
      return false;
    }
    navigate('/oidc/continue', { replace: true });
    return true;
  }, [navigate]);

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
      const pathname = location.pathname;
      if (pathname !== '/login' && pathname !== '/register' && pathname !== '/forgot-password') {
        return;
      }
      const params = new URLSearchParams(location.search);
      const next = normalizeInternalRedirect(params.get('next'));
      setPendingAuthRedirect(next);
    } catch (_) {
      // ignore malformed URL parsing
    }
  }, [location.pathname, location.search]);

  useEffect(() => {
    void ensurePublicCaptchaWidget();
  }, [publicConfig]);

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
    setToast({ message: type === 'error' ? getUserMessage(message) : message, type });
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
    const config = getCaptchaConfig();
    return Boolean(config.prefix && config.sceneId);
  }

  function isBootstrapLoginEmail(email) {
    return `${email || ''}`.trim().toLowerCase().endsWith('@rosm.local');
  }

  function getCaptchaConfig(override = {}) {
    return {
      prefix: `${override.prefix || publicConfig?.captcha?.prefix || ALIYUN_CAPTCHA_PREFIX}`.trim(),
      sceneId: `${override.sceneId || publicConfig?.captcha?.scene_id || ALIYUN_CAPTCHA_SCENE_ID}`.trim(),
      region: `${override.region || publicConfig?.captcha?.region || 'cn'}`.trim(),
    };
  }

  function validatedAliyunCaptchaSceneId(value, { required = false } = {}) {
    const sceneId = `${value || ''}`.trim();
    if (!sceneId && !required) {
      return '';
    }
    if (!sceneId || !/^[a-z0-9]+$/.test(sceneId)) {
      throw new Error('场景 ID 只能填写验证码 2.0 控制台显示的小写字母和数字，不要包含场景名称。');
    }
    return sceneId;
  }

  async function api(path, options = {}) {
    const { method = 'GET', body, auth = false } = options;
    const headers = {};
    if (body !== undefined) {
      headers['content-type'] = 'application/json';
    }
    let response;
    try {
      response = await requestWithSessionRefresh(
        () => fetch(`${API_BASE}${path}`, {
          method,
          headers,
          credentials: 'include',
          cache: method === 'GET' ? 'default' : 'no-store',
          body: body ? JSON.stringify(body) : undefined,
        }),
        { auth, refreshSession: refreshFirstPartySession },
      );
    } catch (_) {
      const error = new Error('当前无法连接到服务，请检查网络后重试。');
      error.code = 'network_error';
      error.status = 0;
      throw error;
    }
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error();
      error.code = data.error || data.code || 'request_failed';
      error.status = response.status;
      error.serverMessage = typeof data.message === 'string' ? data.message : '';
      error.details = data;
      error.message = getUserErrorMessage(error);
      throw error;
    }
    return data;
  }

  function getAuthErrorMessage(error, context) {
    const fallbackByContext = {
      password_factor_select: '无法读取当前账户可用的验证方式。',
      password_code_send: '邮箱验证码发送失败，请稍后重试。',
      password_login: '登录失败，请检查验证信息后重试。',
      email_code_send: '登录验证码发送失败，请稍后重试。',
      email_code_login: '登录失败，请检查验证码后重试。',
    };
    const fallback = fallbackByContext[context] || '请求失败，请稍后重试。';
    return getUserErrorMessage(error, fallback);
  }

  function getPasskeySetupErrorMessage(error) {
    const normalizedMessage = String(error?.message || '').toLowerCase();
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
    if (error?.name === 'UnknownError' || normalizedMessage.includes('credential manager')) {
      return '系统凭据管理器暂时无法创建通行密钥。你可以改用最新版 Chrome 重试，或先选择“稍后再说”，这不会影响刚刚注册的账户和登录状态。';
    }
    return getUserErrorMessage(error, '通行密钥添加失败，请稍后再试。');
  }

  const safely = useCallback(async (task, fallbackMessage) => {
    try {
      await task();
    } catch (error) {
      showToast(getUserErrorMessage(error, fallbackMessage), 'error');
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
      aliyun_captcha_prefix: security.aliyun_captcha_prefix || '',
      aliyun_captcha_scene_id: security.aliyun_captcha_scene_id || '',
      aliyun_captcha_access_key_id: security.aliyun_captcha_access_key_id || '',
      aliyun_captcha_access_key_secret: '',
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

  useEffect(() => {
    void loadDiscovery().catch(() => {
      setDiscovery(null);
    });
  }, [loadDiscovery]);

  function ensureAliyunCaptchaScript(config = getCaptchaConfig()) {
    return new Promise((resolve, reject) => {
      if (window.initAliyunCaptcha && window.__rosmAliyunCaptchaPrefix === config.prefix) {
        resolve();
        return;
      }
      let existing = document.querySelector('script[data-aliyun-captcha]');
      if (existing) {
        if (existing.dataset.prefix !== config.prefix) {
          existing.remove();
          delete window.initAliyunCaptcha;
          existing = null;
        } else if (existing.dataset.loaded === 'true') {
          resolve();
          return;
        }
      }

      const script = existing || document.createElement('script');
      let settled = false;
      const cleanup = () => {
        window.clearTimeout(loadTimer);
        script.removeEventListener('load', onLoad);
        script.removeEventListener('error', onError);
      };
      const fail = (message) => {
        if (settled) return;
        settled = true;
        cleanup();
        script.remove();
        delete window.initAliyunCaptcha;
        reject(new Error(message));
      };
      const onLoad = () => {
        if (settled) return;
        settled = true;
        cleanup();
        script.dataset.loaded = 'true';
        resolve();
      };
      const onError = () => fail('人机验证组件加载失败，请检查网络后重试。');
      const loadTimer = window.setTimeout(
        () => fail('人机验证组件加载超时，请刷新页面后重试。'),
        15000,
      );
      script.addEventListener('load', onLoad, { once: true });
      script.addEventListener('error', onError, { once: true });

      if (!existing) {
        window.AliyunCaptchaConfig = {
          region: config.region,
          prefix: config.prefix,
        };
        window.__rosmAliyunCaptchaPrefix = config.prefix;
        script.src = 'https://o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js';
        script.async = true;
        script.dataset.aliyunCaptcha = 'true';
        script.dataset.prefix = config.prefix;
        document.body.appendChild(script);
      }
    });
  }

  async function waitForAliyunCaptchaReady(config) {
    await ensureAliyunCaptchaScript(config);
    const deadline = Date.now() + 10000;
    while (typeof window.initAliyunCaptcha !== 'function') {
      if (Date.now() >= deadline) {
        throw new Error('人机验证组件初始化超时，请刷新页面后重试。');
      }
      await new Promise((resolve) => window.setTimeout(resolve, 100));
    }
  }

  function destroyCaptchaInstance(instanceRef) {
    try {
      instanceRef.current?.destroy?.();
    } catch (_) {
      // Ignore provider cleanup errors and rebuild the widget.
    }
    instanceRef.current = null;
  }

  async function ensurePublicCaptchaWidget() {
    const config = getCaptchaConfig();
    if (!config.prefix || !config.sceneId || !publicCaptchaRef.current) {
      return null;
    }
    const configKey = `${config.region}:${config.prefix}:${config.sceneId}`;
    if (publicCaptchaInstanceRef.current && publicCaptchaConfigRef.current === configKey) {
      return publicCaptchaInstanceRef.current;
    }

    await waitForAliyunCaptchaReady(config);
    destroyCaptchaInstance(publicCaptchaInstanceRef);
    publicCaptchaTokenRef.current = '';
    publicCaptchaRef.current.innerHTML = '';
    window.initAliyunCaptcha({
      SceneId: config.sceneId,
      mode: 'embed',
      element: '#aliyun-register-captcha',
      slideStyle: { width: 360, height: 40 },
      success: (captchaVerifyParam) => {
        publicCaptchaTokenRef.current = captchaVerifyParam;
      },
      fail: () => {
        publicCaptchaTokenRef.current = '';
      },
      getInstance: (instance) => {
        publicCaptchaInstanceRef.current = instance;
      },
    });
    publicCaptchaConfigRef.current = configKey;
    return publicCaptchaInstanceRef.current;
  }

  const mountPublicCaptcha = useCallback(() => {
    void ensurePublicCaptchaWidget();
  }, [publicConfig]);

  function getPublicCaptchaToken() {
    const token = publicCaptchaTokenRef.current;
    if (!token) {
      throw new Error('请先完成人机验证');
    }
    return token;
  }

  function resetPublicCaptcha() {
    destroyCaptchaInstance(publicCaptchaInstanceRef);
    publicCaptchaTokenRef.current = '';
    publicCaptchaConfigRef.current = '';
    if (publicCaptchaRef.current) {
      publicCaptchaRef.current.innerHTML = '';
    }
    window.setTimeout(() => void ensurePublicCaptchaWidget(), 0);
  }

  async function executeBackgroundCaptcha(configOverride = {}) {
    const config = getCaptchaConfig(configOverride);
    if (!config.prefix || !config.sceneId || !backgroundCaptchaContainerRef.current) {
      throw new Error('当前未配置阿里云验证码');
    }
    if (backgroundCaptchaPromiseRef.current) {
      throw new Error('人机验证正在处理中，请稍后再试。');
    }
    await waitForAliyunCaptchaReady(config);

    destroyCaptchaInstance(backgroundCaptchaInstanceRef);
    backgroundCaptchaContainerRef.current.innerHTML = '';
    return new Promise((resolve, reject) => {
      const timer = window.setTimeout(() => {
        backgroundCaptchaPromiseRef.current = null;
        reject(new Error('人机验证已超时，请重试。'));
      }, 120000);
      const finish = (callback, value) => {
        const pending = backgroundCaptchaPromiseRef.current;
        if (!pending) {
          return;
        }
        window.clearTimeout(pending.timer);
        if (pending.triggerTimer) {
          window.clearTimeout(pending.triggerTimer);
        }
        backgroundCaptchaPromiseRef.current = null;
        callback(value);
      };
      backgroundCaptchaPromiseRef.current = { resolve, reject, timer, triggerTimer: null };
      try {
        window.initAliyunCaptcha({
          SceneId: config.sceneId,
          mode: 'popup',
          element: '#aliyun-background-captcha',
          button: '#aliyun-background-captcha-trigger',
          slideStyle: { width: 360, height: 40 },
          success: (captchaVerifyParam) => {
            if (!captchaVerifyParam) {
              finish(reject, new Error('人机验证未生成有效凭据，请重试。'));
              return;
            }
            finish(resolve, captchaVerifyParam);
          },
          fail: () => finish(
            reject,
            new Error('人机验证未通过，请刷新验证后重试。'),
          ),
          close: () => finish(reject, new Error('人机验证已取消。')),
          getInstance: (instance) => {
            backgroundCaptchaInstanceRef.current = instance;
            const pending = backgroundCaptchaPromiseRef.current;
            if (!pending || pending.triggerTimer) {
              return;
            }
            pending.triggerTimer = window.setTimeout(() => {
              backgroundCaptchaButtonRef.current?.click();
            }, 2100);
          },
        });
      } catch (error) {
        finish(reject, error instanceof Error ? error : new Error('人机验证加载失败。'));
      }
    });
  }

  function resetBackgroundCaptcha() {
    destroyCaptchaInstance(backgroundCaptchaInstanceRef);
    if (backgroundCaptchaContainerRef.current) {
      backgroundCaptchaContainerRef.current.innerHTML = '';
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
      const email = loginForm.email.trim();
      // The backend only grants this bypass after validating both the password
      // and the one-time bootstrap state. Reserved local admins must be able to
      // reach that check before Captcha has been configured in the admin UI.
      const captchaToken = hasConfiguredCaptcha() && !isBootstrapLoginEmail(email)
        ? await executeBackgroundCaptcha()
        : undefined;
      const data = await api('/api/v1/auth/password-factors', {
        method: 'POST',
        body: {
          email,
          password: loginForm.password,
          ...(captchaToken ? { captcha_token: captchaToken } : {}),
        },
      });
      if (data.direct_login) {
        const payload = await api('/api/v1/auth/login', {
          method: 'POST',
          body: {
            email,
            password: loginForm.password,
            remember_me: rememberMe,
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
          remember_me: rememberMe,
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
      showToast('登录验证码已发送，请检查短信。', 'success');
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
          remember_me: rememberMe,
        },
      });
      onLoginSuccess(payload);
    } catch (error) {
      if (handleCodeLoginContinuation(error, 'phone', loginForm.phone_number.trim())) {
        return;
      }
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
          remember_me: rememberMe,
        },
      });
      onLoginSuccess(payload);
    } catch (error) {
      if (handleCodeLoginContinuation(error, 'email', loginForm.email.trim())) {
        return;
      }
      showToast(getAuthErrorMessage(error, 'email_code_login'), 'error');
    } finally {
      setLoading(false);
    }
  }

  function handleCodeLoginContinuation(error, method, identifier) {
    const details = error?.details || {};
    if (error?.code === 'registration_required' && details.registration_handoff) {
      const next = normalizeInternalRedirect(new URLSearchParams(location.search).get('next'));
      setRegisterMethod(method);
      setRegisterForm((current) => ({
        ...current,
        email: method === 'email' ? identifier : '',
        phone_number: method === 'phone' ? identifier : '',
        email_code: '',
        phone_code: '',
        registration_handoff: details.registration_handoff,
      }));
      setLoginStep('credentials');
      setLoginCodeCooldownRemaining(0);
      navigate(next ? `/register?next=${encodeURIComponent(next)}` : '/register');
      showToast('验证码已通过，请填写资料完成注册。', 'success');
      return true;
    }
    if (error?.code === 'mfa_required' && details.step_up_challenge) {
      setLoginStepUpChallenge(details.step_up_challenge);
      setPasswordLoginFactors(Array.isArray(details.factors) ? details.factors : ['password']);
      setSelectedPasswordFactor('');
      setLoginStep('step_up');
      showToast('请选择另一种方式完成二次验证。', 'success');
      return true;
    }
    return false;
  }

  async function selectDirectLoginStepUpFactor(factor) {
    setSelectedPasswordFactor(factor);
    if (!['email_code', 'phone_code'].includes(factor)) return;
    setLoginCodeSending(true);
    try {
      await api('/api/v1/auth/login-step-up-code', {
        method: 'POST',
        body: { step_up_challenge: loginStepUpChallenge, factor },
      });
      setLoginCodeCooldownRemaining(60);
      showToast('验证码已发送。', 'success');
    } catch (error) {
      setSelectedPasswordFactor('');
      showToast(getUserErrorMessage(error, '验证码发送失败，请稍后重试。'), 'error');
    } finally {
      setLoginCodeSending(false);
    }
  }

  async function completeDirectLoginStepUp(event, response) {
    event?.preventDefault?.();
    setLoading(true);
    try {
      const factor = selectedPasswordFactor;
      const payload = await api('/api/v1/auth/login-step-up', {
        method: 'POST',
        body: {
          step_up_challenge: loginStepUpChallenge,
          factor,
          password: factor === 'password' ? loginForm.password : undefined,
          code: factor === 'phone_code' ? loginForm.phone_code : loginForm.authenticator_code || loginForm.email_code,
          ...(response ? { response } : {}),
          remember_me: rememberMe,
        },
      });
      onLoginSuccess(payload);
    } catch (error) {
      showToast(getUserErrorMessage(error, '二次验证失败，请重试。'), 'error');
    } finally {
      setLoading(false);
    }
  }

  function beginDirectLoginStepUpPasskey() {
    return api('/api/v1/auth/login-step-up-passkey-options', {
      method: 'POST',
      body: { step_up_challenge: loginStepUpChallenge },
    });
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

  function onLoginSuccess(payload, { deferRedirect = false } = {}) {
    setSession({ user: payload.user, security: payload.security || {} });
    setStatus(`已登录：${payload.user?.email || ''}`);
    setLoginMethod('phone_code');
    setLoginStep('credentials');
    setPasswordLoginFactors([]);
    setSelectedPasswordFactor('phone_code');
    setRememberMe(false);
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
    if (!deferRedirect && payload.post_register_passkey_bootstrap !== true) {
      const redirected = continuePostAuth(pendingAuthRedirect);
      if (redirected) {
        return;
      }
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
              registration_handoff: registerForm.registration_handoff || undefined,
              nickname: registerForm.nickname.trim(),
              password: registerForm.password,
            },
          })
        : await api('/api/v1/auth/register', {
            method: 'POST',
            body: {
              email: registerForm.email.trim(),
              email_code: registerForm.email_code.trim(),
              registration_handoff: registerForm.registration_handoff || undefined,
              nickname: registerForm.nickname.trim(),
              password: registerForm.password,
            },
          });
      const registrationPassword = registerForm.password;
      onLoginSuccess(payload, { deferRedirect: true });
      setRegisterForm({
        email: '',
        email_code: '',
        phone_number: '',
        phone_code: '',
        nickname: '',
        password: '',
        registration_handoff: '',
      });
      setPostRegisterPasskeyError('');
      setPostRegisterMethod(registerMethod);
      setPostRegisterBindingPassword(registrationPassword);
      setPostRegisterPasskeyPending(payload.post_register_passkey_bootstrap === true);
      setPostRegisterPasskeyPromptOpen(false);
      setPostRegisterBindingPromptOpen(true);
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
      const redirected = continuePostAuth(pendingAuthRedirect);
      if (!redirected) {
        showToast('系统通行密钥已连接，后续可更快捷登录。', 'success');
      }
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

  async function bindEmailPostRegister(payload) {
    const result = await api('/api/v1/me/bind-email', {
      method: 'POST',
      auth: true,
      body: payload,
    });
    await tryLoadMe();
    return result;
  }

  async function bindPhonePostRegister(payload) {
    const result = await api('/api/v1/me/bind-phone', {
      method: 'POST',
      auth: true,
      body: payload,
    });
    await tryLoadMe();
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

  async function sendStepUpCode(method, excludedFactor) {
    return api('/api/v1/me/step-up/send-code', {
      method: 'POST',
      auth: true,
      body: { method, excluded_factor: excludedFactor },
    });
  }

  async function beginStepUpPasskey(excludedFactor) {
    return api('/api/v1/me/step-up/webauthn-options', {
      method: 'POST',
      auth: true,
      body: { excluded_factor: excludedFactor },
    });
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

  async function deleteWebAuthnCredential(credentialId, verification) {
    const result = await api(
      `/api/v1/me/webauthn/credentials/${encodeURIComponent(credentialId)}`,
      {
        method: 'DELETE',
        auth: true,
        body: { verification },
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
    showToast('密码已重置，旧会话已失效。', 'success');
    return result;
  }

  async function beginWebAuthnLogin(email = '') {
    return api('/api/v1/auth/webauthn/options', {
      method: 'POST',
      body: email ? { email } : {},
    });
  }

  async function completeWebAuthnLogin(email, response, remember = rememberMe) {
    const payload = await api('/api/v1/auth/webauthn/verify', {
      method: 'POST',
      body: email ? { email, response, remember_me: remember } : { response, remember_me: remember },
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
      const captchaSceneId = validatedAliyunCaptchaSceneId(
        systemForm.aliyun_captcha_scene_id,
      );
      await api('/api/v1/admin/settings', {
        method: 'PUT',
        auth: true,
        body: {
          security: {
            aliyun_captcha_prefix: systemForm.aliyun_captcha_prefix || '',
            aliyun_captcha_scene_id: captchaSceneId,
            aliyun_captcha_access_key_id: systemForm.aliyun_captcha_access_key_id || '',
            aliyun_captcha_access_key_secret: systemForm.aliyun_captcha_access_key_secret || '',
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
      const captchaSceneId = validatedAliyunCaptchaSceneId(
        systemForm.aliyun_captcha_scene_id,
      );
      await api('/api/v1/admin/settings', {
        method: 'PUT',
        auth: true,
        body: {
          security: {
            aliyun_captcha_prefix: systemForm.aliyun_captcha_prefix || '',
            aliyun_captcha_scene_id: captchaSceneId,
            aliyun_captcha_access_key_id: systemForm.aliyun_captcha_access_key_id || '',
            aliyun_captcha_access_key_secret: systemForm.aliyun_captcha_access_key_secret || '',
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

  async function testAliyunCaptchaConnection() {
    try {
      const sceneId = validatedAliyunCaptchaSceneId(
        systemForm.aliyun_captcha_scene_id,
        { required: true },
      );
      await api('/api/v1/admin/settings', {
        method: 'PUT',
        auth: true,
        body: {
          security: {
            aliyun_captcha_prefix: systemForm.aliyun_captcha_prefix || '',
            aliyun_captcha_scene_id: sceneId,
            aliyun_captcha_access_key_id: systemForm.aliyun_captcha_access_key_id || '',
            aliyun_captcha_access_key_secret: systemForm.aliyun_captcha_access_key_secret || '',
          },
          registration: {
            require_email_verification: Boolean(systemForm.registration_email_verify),
          },
        },
      });
      const captchaToken = await executeBackgroundCaptcha({
        prefix: systemForm.aliyun_captcha_prefix,
        sceneId,
      });
      const result = await api('/api/v1/admin/settings/aliyun-captcha-test', {
        method: 'POST',
        auth: true,
        body: { captcha_token: captchaToken },
      });
      showToast(result.message || '阿里云验证码连接验证成功。', 'success');
      await loadSystemConfig();
      await loadPublicConfig();
    } catch (error) {
      showToast(error.message || '阿里云验证码连接验证失败。', 'error');
    } finally {
      resetBackgroundCaptcha();
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
    const combinedRedirectUris = [
      ...(oidcForm.enable_web ? parseLines(oidcForm.web_redirect_uris || oidcForm.redirect_uris) : []),
      ...(oidcForm.enable_app ? parseLines(oidcForm.app_redirect_uri) : []),
    ].reduce((items, item) => (items.includes(item) ? items : [...items, item]), []);
    try {
      const result = await api(`/api/v1/admin/oidc/clients/${encodeURIComponent(oidcForm.client_id.trim())}`, {
        method: 'PUT',
        auth: true,
        body: {
          client_id: oidcForm.client_id.trim(),
          display_name: oidcForm.display_name.trim(),
          is_official: Boolean(oidcForm.is_official),
          redirect_uris: combinedRedirectUris,
          scopes: parseLines(oidcForm.scopes, ['openid', 'profile', 'email', 'phone']),
          grant_types: parseLines(oidcForm.grant_types, ['authorization_code', 'refresh_token']),
          generate_client_secret: Boolean(oidcForm.generate_client_secret),
          is_confidential: Boolean(oidcForm.is_confidential),
          is_active: Boolean(oidcForm.is_active),
        },
      });
      setOidcForm((current) => ({ ...current, client_secret: '' }));
      showToast('OIDC 客户端已保存', 'success');
      try {
        await loadOidcClients();
      } catch (error) {
        showToast(error.message || '客户端列表刷新失败，请稍后手动刷新', 'error');
      }
      return result;
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
        ref={backgroundCaptchaContainerRef}
        id="aliyun-background-captcha"
        aria-hidden="true"
      />
      <button
        ref={backgroundCaptchaButtonRef}
        id="aliyun-background-captcha-trigger"
        type="button"
        tabIndex={-1}
        aria-hidden="true"
        style={{ position: 'fixed', left: '-9999px', top: 0, width: 1, height: 1, opacity: 0 }}
      />
      {toast && (
        <div className={`fixed right-5 top-5 z-50 rounded-2xl px-4 py-3 text-sm font-medium shadow-lg ${toast.type === 'error' ? 'bg-red-50 text-red-700' : 'bg-sage-900 text-white'}`}>
          {toast.message}
        </div>
      )}
        <PostRegisterBindingPrompt
          open={postRegisterBindingPromptOpen}
          registrationMethod={postRegisterMethod}
          onSendCode={async (account) => {
            try {
              const captchaToken = hasConfiguredCaptcha() ? await executeBackgroundCaptcha() : undefined;
              const bindingPhone = postRegisterMethod === 'email';
              const result = await api(
                bindingPhone ? '/api/v1/me/send-bind-phone-code' : '/api/v1/me/send-bind-email-code',
                {
                  method: 'POST',
                  auth: true,
                  body: {
                    ...(bindingPhone ? { phone_number: account } : { email: account }),
                    current_password: postRegisterBindingPassword,
                    ...(captchaToken ? { captcha_token: captchaToken } : {}),
                  },
                },
              );
              showToast(bindingPhone ? '验证码已发送，请注意查收短信。' : '验证码已发送，请注意查收邮箱。', 'success');
              return result;
            } finally {
              resetBackgroundCaptcha();
            }
          }}
          onConfirm={async (account, code) => {
            const bindingPhone = postRegisterMethod === 'email';
            if (bindingPhone) {
              await bindPhonePostRegister({
                phone_number: account,
                current_password: postRegisterBindingPassword,
                verify_code: code,
              });
            } else {
              await bindEmailPostRegister({
                email: account,
                current_password: postRegisterBindingPassword,
                email_code: code,
              });
            }
            setPostRegisterBindingPromptOpen(false);
            setPostRegisterBindingPassword('');
            if (postRegisterPasskeyPending) {
              setPostRegisterPasskeyPromptOpen(true);
            } else {
              continuePostAuth(pendingAuthRedirect);
            }
            showToast(bindingPhone ? '手机号绑定成功' : '邮箱绑定成功', 'success');
          }}
          onSkip={() => {
            setPostRegisterBindingPromptOpen(false);
            setPostRegisterBindingPassword('');
            if (postRegisterPasskeyPending) {
              setPostRegisterPasskeyPromptOpen(true);
            } else {
              continuePostAuth(pendingAuthRedirect);
            }
          }}
        />
        <PostRegisterPasskeyPrompt
          open={postRegisterPasskeyPromptOpen}
          registrationMethod={postRegisterMethod}
          saving={postRegisterPasskeySaving}
          error={postRegisterPasskeyError}
          onConfirm={() => void completePostRegisterPasskeySetup()}
          onSkip={() => {
            setPostRegisterPasskeyError('');
            setPostRegisterPasskeyPromptOpen(false);
            continuePostAuth(pendingAuthRedirect);
          }}
        />
        <AppRoutes
        isLoggedIn={isLoggedIn}
        defaultAuthedPath={defaultAuthedPath}
        loginForm={loginForm}
        setLoginForm={setLoginForm}
        loginMethod={loginMethod}
        setLoginMethod={setLoginMethod}
        rememberMe={rememberMe}
        setRememberMe={setRememberMe}
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
        selectDirectLoginStepUpFactor={selectDirectLoginStepUpFactor}
        completeDirectLoginStepUp={completeDirectLoginStepUp}
        beginDirectLoginStepUpPasskey={beginDirectLoginStepUpPasskey}
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
        publicCaptchaRef={publicCaptchaRef}
        publicConfig={publicConfig}
        captchaConfigured={hasConfiguredCaptcha()}
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
        sendStepUpCode={sendStepUpCode}
        beginStepUpPasskey={beginStepUpPasskey}
        systemForm={systemForm}
        setSystemForm={setSystemForm}
        saveServiceConfig={saveServiceConfig}
        testSmtpConnection={testSmtpConnection}
        testAliyunCaptchaConnection={testAliyunCaptchaConnection}
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
    </>
  );
}

export default App;
