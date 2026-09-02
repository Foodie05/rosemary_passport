import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Ban, BookOpen, Check, CircleHelp, Copy, FileText, Globe, Key, Mail, Pencil, Search, Settings2, Smartphone, Trash2, UserCheck, UserPlus, Users, X } from 'lucide-react';
import { cn } from '../lib/utils';
import { SECURITY_FIELDS, SECURITY_FIELD_DEFAULTS, SECURITY_FIELD_HINTS, SECURITY_TOGGLE_DEFAULTS } from '../constants';
import { cleanDisplayName } from '../utils';
import { RosemaryCheckbox, useRosemaryDialog } from '../components/ui';

const SECURITY_GROUPS = [
  {
    title: '基础开关',
    description: '控制系统是否启用账户维度和 IP 维度限流。',
    fields: [],
  },
  {
    title: '验证码基础',
    description: '统一管理验证码错误次数和各类发码冷却时间。',
    fields: [
      'email_code_max_attempts',
      'register_code_cooldown_seconds',
      'login_code_cooldown_seconds',
      'bind_email_code_cooldown_seconds',
      'password_reset_code_cooldown_seconds',
    ],
  },
  {
    title: '注册风控',
    description: '限制注册验证码发送频率和封禁周期。',
    fields: [
      'register_code_email_limit',
      'register_code_ip_limit',
      'register_code_window_seconds',
      'register_code_block_seconds',
    ],
  },
  {
    title: '登录风控',
    description: '限制登录验证码和密码登录的尝试次数。',
    fields: [
      'admin_login_code_email_limit',
      'admin_login_code_ip_limit',
      'admin_login_code_window_seconds',
      'admin_login_code_block_seconds',
      'login_email_limit',
      'login_ip_limit',
      'login_window_seconds',
      'login_block_seconds',
    ],
  },
  {
    title: '令牌接口风控',
    description: '限制刷新令牌和 OIDC 端点的高频请求。',
    fields: [
      'refresh_ip_limit',
      'refresh_window_seconds',
      'refresh_block_seconds',
      'oidc_token_ip_limit',
      'oidc_token_window_seconds',
      'oidc_token_block_seconds',
      'oidc_introspect_ip_limit',
      'oidc_introspect_window_seconds',
      'oidc_introspect_block_seconds',
    ],
  },
];

const SECURITY_FIELD_MAP = Object.fromEntries(SECURITY_FIELDS);
const OIDC_SCOPE_OPTIONS = [
  { value: 'openid', label: 'openid', description: '启用 OIDC 身份识别基础能力（含 nonce 要求）。' },
  { value: 'profile', label: 'profile', description: '允许应用读取昵称等基础资料。' },
  { value: 'email', label: 'email', description: '允许应用读取邮箱与邮箱验证状态。' },
  { value: 'phone', label: 'phone', description: '允许应用读取手机号与手机号验证状态。' },
  { value: 'accountRule', label: 'accountRule', description: '允许应用读取账户角色（如 admin/user）。' },
];
const FLUTTER_SDK_GITHUB_URL = 'https://github.com/Foodie05/rosemary_passport/tree/master/packages/rosm_passport_flutter';
const DASHBOARD_PERIODS = [
  { days: 7, label: '7 天' },
  { days: 30, label: '30 天' },
  { days: 90, label: '90 天' },
  { days: 180, label: '180 天' },
];

function formatBeijingDate(value, includeYear = false) {
  const matched = `${value || ''}`.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!matched) return '-';
  const [, year, month, day] = matched;
  const readable = `${Number(month)}月${Number(day)}日`;
  return includeYear ? `${year}年${readable}` : readable;
}

function parseUniqueLines(value) {
  return `${value || ''}`
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean)
    .reduce((items, item) => (items.includes(item) ? items : [...items, item]), []);
}

function isMobileCustomRedirectUri(value) {
  const raw = `${value || ''}`.trim();
  if (!raw) {
    return false;
  }
  try {
    const uri = new URL(raw);
    return !['http:', 'https:'].includes(uri.protocol);
  } catch {
    return /^[a-z][a-z0-9+.-]*:\//i.test(raw);
  }
}

function SectionHeader({ title, description, actions }) {
  return (
    <div className="flex flex-col justify-between gap-4 md:flex-row md:items-center">
      <div>
        <h2 className="text-2xl font-bold text-sage-900">{title}</h2>
        <p className="mt-1 text-sage-500">{description}</p>
      </div>
      {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
    </div>
  );
}

function SettingsShell({ icon: Icon, title, description, children, onSubmit, actions }) {
  return (
    <div className="max-w-6xl space-y-8">
      <div className="flex items-center gap-4">
        <div className="rounded-2xl bg-sage-600 p-4 text-white shadow-lg shadow-sage-600/20">
          <Icon size={32} />
        </div>
        <div>
          <h2 className="text-2xl font-bold text-sage-900">{title}</h2>
          <p className="mt-1 text-sage-500">{description}</p>
        </div>
      </div>
      <form onSubmit={onSubmit} className="glass-card space-y-8 rounded-3xl p-5 sm:p-8">
        {children}
        {actions ? <div className="flex flex-wrap justify-end gap-3 border-t border-sage-100 pt-6">{actions}</div> : null}
      </form>
    </div>
  );
}

function ConfigField({ label, hint, defaultValue, children }) {
  return (
    <div className="space-y-2">
      <label className="flex flex-wrap items-center gap-1.5 text-sm font-bold text-sage-700">
        <span className="min-w-0 break-words">{label}</span>
        {defaultValue !== undefined ? (
          <span className="rounded-full bg-sage-100 px-2 py-0.5 text-[11px] font-semibold text-sage-500">
            默认 {String(defaultValue)}
          </span>
        ) : null}
        {hint ? <HelpHint hint={hint} /> : null}
      </label>
      {children}
    </div>
  );
}

function HelpHint({ hint }) {
  return (
    <span className="group relative inline-flex">
      <span className="inline-flex cursor-help text-sage-400 transition-colors hover:text-sage-600">
        <CircleHelp size={14} />
      </span>
      <span className="policy-tooltip" role="tooltip">
        {hint}
      </span>
    </span>
  );
}

const PROVIDER_PATTERN = /^@[a-z0-9.-]+\.[a-z]{2,}$/i;

function normalizeProvider(value) {
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
}

function ProviderListSection({
  title,
  description,
  providers,
  inputValue,
  onInputChange,
  onAdd,
  onImport,
  onRemove,
}) {
  return (
    <div className="space-y-4 rounded-3xl border border-sage-100 bg-white p-5">
      <div>
        <h3 className="text-base font-bold text-sage-900">{title}</h3>
        <p className="mt-1 text-sm text-sage-500">{description}</p>
      </div>
      <div className="rounded-2xl border border-dashed border-sage-200 bg-sage-50 px-4 py-3 text-sm text-sage-500">
        支持上传 `txt` 文件批量导入，一行一个邮箱提供商。若未填写 `@`，系统会自动补成 `@xxx.com`。
      </div>
      <div className="flex flex-col gap-3 md:flex-row">
        <input
          className="input-field"
          value={inputValue}
          onChange={(event) => onInputChange(event.target.value)}
          placeholder="@gmail.com"
        />
        <button className="btn-secondary whitespace-nowrap" type="button" onClick={onAdd}>
          添加提供商
        </button>
      </div>
      <div>
        <label className="inline-flex cursor-pointer items-center rounded-xl border border-sage-200 bg-white px-4 py-2 text-sm font-medium text-sage-700 transition-colors hover:bg-sage-50">
          导入 txt 文件
          <input
            type="file"
            accept=".txt,text/plain"
            className="hidden"
            onChange={(event) => onImport(event.target.files?.[0] || null)}
          />
        </label>
      </div>
      <div className="flex flex-wrap gap-2">
        {providers.length ? (
          providers.map((provider) => (
            <span key={provider} className="inline-flex max-w-full items-center gap-2 rounded-full border border-sage-200 bg-sage-50 px-3 py-1.5 text-sm font-medium text-sage-700">
              <span className="min-w-0 break-all">{provider}</span>
              <button
                type="button"
                className="shrink-0 rounded-full text-sage-400 transition-colors hover:text-red-500"
                onClick={() => onRemove(provider)}
                aria-label={`移除 ${provider}`}
              >
                <Trash2 size={14} />
              </button>
            </span>
          ))
        ) : (
          <p className="text-sm text-sage-400">当前没有配置任何邮箱提供商。</p>
        )}
      </div>
    </div>
  );
}

function ToggleCard({ title, defaultEnabled, hint, checked, onChange }) {
  return (
    <div className="flex items-start justify-between gap-4 rounded-2xl border border-sage-100 bg-white p-5 text-sm text-sage-700">
      <span className="min-w-0 space-y-2">
        <span className="flex flex-wrap items-center gap-1.5">
          <span className="min-w-0 break-words font-bold text-sage-900">{title}</span>
          <span className="rounded-full bg-sage-100 px-2 py-0.5 text-[11px] font-semibold text-sage-500">
            默认 {defaultEnabled ? '开启' : '关闭'}
          </span>
          <HelpHint hint={hint} />
        </span>
      </span>
      <RosemaryCheckbox
        checked={checked}
        onCheckedChange={onChange}
        ariaLabel={title}
        className="shrink-0"
      />
    </div>
  );
}

function Modal({ title, children, onClose, actions }) {
  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-sage-900/20 p-3 backdrop-blur-sm sm:items-center sm:p-6">
      <div className="my-auto flex max-h-[calc(100dvh-1.5rem)] w-full max-w-5xl flex-col overflow-hidden rounded-3xl border border-white/60 bg-white shadow-2xl sm:max-h-[calc(100dvh-3rem)]">
        <div className="flex items-center justify-between border-b border-sage-100 px-4 py-4 sm:px-6">
          <h3 className="text-xl font-bold text-sage-900">{title}</h3>
          <button type="button" className="rounded-xl p-2 text-sage-400 hover:bg-sage-50 hover:text-sage-700" onClick={onClose}>
            <X size={18} />
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-4 py-5 sm:px-6">
          <div className="space-y-5">{children}</div>
        </div>
        <div className="flex flex-col-reverse gap-3 border-t border-sage-100 bg-white px-4 py-4 [&>*]:w-full sm:flex-row sm:justify-end sm:px-6 sm:[&>*]:w-auto">{actions}</div>
      </div>
    </div>
  );
}

function InlineCode({ children }) {
  return <code className="rounded bg-sage-100 px-1.5 py-0.5 text-[13px] text-sage-700">{children}</code>;
}

function CodeBlock({ children }) {
  return (
    <pre className="overflow-x-auto rounded-2xl border border-sage-700 bg-sage-900 p-4 text-sm leading-6 text-sage-100 shadow-inner">
      <code>{children}</code>
    </pre>
  );
}

function InfoRow({ label, value }) {
  return (
    <div className="rounded-2xl border border-sage-100 bg-white p-4">
      <p className="text-xs font-bold uppercase tracking-wider text-sage-400">{label}</p>
      <p className="mt-2 break-all text-sm font-medium text-sage-800">{value || '未提供'}</p>
    </div>
  );
}

export function AdminServiceConfig({
  systemForm,
  setSystemForm,
  saveServiceConfig,
  testSmtpConnection,
  testAliyunCaptchaConnection,
  testPhoneSmsConnection,
}) {
  return (
    <SettingsShell
      icon={Mail}
      title="服务配置"
      description="集中管理 SMTP 邮箱、阿里云验证码和短信服务参数。"
      onSubmit={saveServiceConfig}
      actions={(
        <div className="flex flex-wrap gap-3">
          <button className="btn-secondary" type="button" onClick={testSmtpConnection}>验证 SMTP 连接</button>
          <button className="btn-secondary" type="button" onClick={testAliyunCaptchaConnection}>验证阿里云验证码</button>
          <button className="btn-secondary" type="button" onClick={testPhoneSmsConnection}>验证短信配置</button>
          <button className="btn-primary" type="submit">保存服务配置</button>
        </div>
      )}
    >
      <div className="space-y-8">
        <div className="space-y-5">
          <div>
            <h3 className="text-lg font-bold text-sage-900">SMTP 邮箱配置</h3>
            <p className="mt-1 text-sm text-sage-500">使用账号密码方式配置发信服务，用于登录验证码、注册验证和密码重置。</p>
          </div>
          <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
            <ConfigField label="SMTP Host">
              <input className="input-field" value={systemForm.smtp_host || ''} onChange={(event) => setSystemForm((current) => ({ ...current, smtp_host: event.target.value }))} />
            </ConfigField>
            <ConfigField label="SMTP Port">
              <input type="number" className="input-field" value={systemForm.smtp_port || ''} onChange={(event) => setSystemForm((current) => ({ ...current, smtp_port: event.target.value }))} />
            </ConfigField>
            <ConfigField label="SMTP Username">
              <input className="input-field" value={systemForm.smtp_username || ''} onChange={(event) => setSystemForm((current) => ({ ...current, smtp_username: event.target.value }))} />
            </ConfigField>
            <ConfigField label="SMTP Password">
              <input type="password" className="input-field" value={systemForm.smtp_password || ''} onChange={(event) => setSystemForm((current) => ({ ...current, smtp_password: event.target.value }))} />
            </ConfigField>
            <ConfigField label="SMTP From">
              <input className="input-field" value={systemForm.smtp_from || ''} onChange={(event) => setSystemForm((current) => ({ ...current, smtp_from: event.target.value }))} />
            </ConfigField>
            <ConfigField label="确认 SMTP Password">
              <input type="password" className="input-field" value={systemForm.smtp_password_confirm || ''} onChange={(event) => setSystemForm((current) => ({ ...current, smtp_password_confirm: event.target.value }))} />
            </ConfigField>
          </div>
          <RosemaryCheckbox checked={Boolean(systemForm.smtp_secure)} onCheckedChange={(checked) => setSystemForm((current) => ({ ...current, smtp_secure: checked }))}>
            启用安全连接
          </RosemaryCheckbox>
        </div>

        <div className="border-t border-sage-100 pt-8">
          <div className="space-y-5">
            <div>
              <h3 className="text-lg font-bold text-sage-900">阿里云验证码 2.0</h3>
              <p className="mt-1 text-sm text-sage-500">Prefix 与场景 ID 来自验证码 2.0 控制台；AccessKey 来自 RAM 用户，需授予 AliyunYundunAFSFullAccess。</p>
            </div>
            <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
              <ConfigField label="Prefix">
                <input className="input-field" value={systemForm.aliyun_captcha_prefix || ''} onChange={(event) => setSystemForm((current) => ({ ...current, aliyun_captcha_prefix: event.target.value }))} />
              </ConfigField>
              <ConfigField label="场景 ID" hint="只填写场景管理中显示的 ID，不要包含场景名称或空格。">
                <input className="input-field" autoComplete="off" value={systemForm.aliyun_captcha_scene_id || ''} onChange={(event) => setSystemForm((current) => ({ ...current, aliyun_captcha_scene_id: event.target.value }))} />
              </ConfigField>
              <ConfigField label="AccessKey ID" hint="填写 RAM 用户的 AccessKey ID。">
                <input className="input-field" autoComplete="off" placeholder={systemForm.aliyun_captcha_access_key_id_configured ? '已配置，留空则保持不变' : 'RAM AccessKey ID'} value={systemForm.aliyun_captcha_access_key_id || ''} onChange={(event) => setSystemForm((current) => ({ ...current, aliyun_captcha_access_key_id: event.target.value }))} />
              </ConfigField>
              <ConfigField label="AccessKey Secret" hint="AccessKey 创建时仅展示一次；只保存在服务端，不会下发到客户端。">
                <input type="password" className="input-field" autoComplete="new-password" placeholder={systemForm.aliyun_captcha_access_key_secret_configured ? '已配置，留空则保持不变' : 'RAM AccessKey Secret'} value={systemForm.aliyun_captcha_access_key_secret || ''} onChange={(event) => setSystemForm((current) => ({ ...current, aliyun_captcha_access_key_secret: event.target.value }))} />
              </ConfigField>
            </div>
            <RosemaryCheckbox checked={Boolean(systemForm.registration_email_verify)} onCheckedChange={(checked) => setSystemForm((current) => ({ ...current, registration_email_verify: checked }))}>
              注册必须验证邮箱
            </RosemaryCheckbox>
          </div>
        </div>

        <div className="border-t border-sage-100 pt-8">
          <div className="space-y-5">
            <div>
              <h3 className="text-lg font-bold text-sage-900">手机号验证（阿里云）</h3>
              <p className="mt-1 text-sm text-sage-500">将验证码发送与校验所需参数集中管理，供手机号登录、MFA 与手机号绑定使用。</p>
            </div>
            <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
              <ConfigField label="AccessKey ID">
                <input className="input-field" placeholder={systemForm.phone_sms_access_key_id_configured ? '已配置，留空则保持不变' : 'RAM AccessKey ID'} value={systemForm.phone_sms_access_key_id || ''} onChange={(event) => setSystemForm((current) => ({ ...current, phone_sms_access_key_id: event.target.value }))} />
              </ConfigField>
              <ConfigField label="AccessKey Secret">
                <input type="password" className="input-field" placeholder={systemForm.phone_sms_access_key_secret_configured ? '已配置，留空则保持不变' : 'RAM AccessKey Secret'} value={systemForm.phone_sms_access_key_secret || ''} onChange={(event) => setSystemForm((current) => ({ ...current, phone_sms_access_key_secret: event.target.value }))} />
              </ConfigField>
              <ConfigField label="短信签名 SignName">
                <input className="input-field" value={systemForm.phone_sms_sign_name || ''} onChange={(event) => setSystemForm((current) => ({ ...current, phone_sms_sign_name: event.target.value }))} />
              </ConfigField>
              <ConfigField label="短信模板 TemplateCode">
                <input className="input-field" value={systemForm.phone_sms_template_code || ''} onChange={(event) => setSystemForm((current) => ({ ...current, phone_sms_template_code: event.target.value }))} />
              </ConfigField>
              <ConfigField label="方案名 SchemeName（可选）">
                <input className="input-field" value={systemForm.phone_sms_scheme_name || ''} onChange={(event) => setSystemForm((current) => ({ ...current, phone_sms_scheme_name: event.target.value }))} />
              </ConfigField>
            </div>
            <RosemaryCheckbox checked={Boolean(systemForm.phone_verification_enabled ?? true)} onCheckedChange={(checked) => setSystemForm((current) => ({ ...current, phone_verification_enabled: checked }))}>
              启用手机号验证码能力（登录 / MFA / 绑定）
            </RosemaryCheckbox>
          </div>
        </div>
      </div>
    </SettingsShell>
  );
}

export function AdminSecurityPolicy({
  systemForm,
  setSystemForm,
  saveSecurityPolicy,
  addRegistrationProvider,
  importRegistrationProviders,
  removeRegistrationProvider,
}) {
  const providerMode = systemForm.registration_email_provider_mode === 'whitelist' ? 'whitelist' : 'blacklist';
  const activeProviderListKey =
    providerMode === 'whitelist'
      ? 'registration_email_provider_whitelist'
      : 'registration_email_provider_blacklist';
  const activeProviderInputKey =
    providerMode === 'whitelist'
      ? 'registration_email_provider_whitelist_input'
      : 'registration_email_provider_blacklist_input';
  const activeProviderTitle = providerMode === 'whitelist' ? '白名单' : '黑名单';
  const activeProviderDescription =
    providerMode === 'whitelist'
      ? '白名单模式下，仅以下邮箱提供商允许注册。'
      : '黑名单模式下，以下邮箱提供商将被拒绝注册。';

  return (
    <SettingsShell
      icon={Settings2}
      title="安全策略"
      description="控制限流策略、验证码尝试次数以及注册邮箱提供商管理。"
      onSubmit={saveSecurityPolicy}
      actions={<button className="btn-primary" type="submit">保存安全策略</button>}
    >
      <div className="space-y-8">
        <div className="space-y-5 rounded-3xl border border-sage-100 bg-sage-50/70 p-6">
          <div>
            <h3 className="text-lg font-bold text-sage-900">策略开关</h3>
            <p className="mt-1 text-sm text-sage-500">这里只保留最关键的两个总开关，避免它们单独占据整列空间。</p>
          </div>
          <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
            <ToggleCard
              title="启用账户维度限流"
              defaultEnabled={SECURITY_TOGGLE_DEFAULTS.email_rate_limit_enabled}
              hint={SECURITY_FIELD_HINTS.email_rate_limit_enabled}
              checked={Boolean(systemForm.email_rate_limit_enabled ?? true)}
              onChange={(checked) => setSystemForm((current) => ({ ...current, email_rate_limit_enabled: checked }))}
            />
            <ToggleCard
              title="启用 IP 维度限流"
              defaultEnabled={SECURITY_TOGGLE_DEFAULTS.ip_rate_limit_enabled}
              hint={SECURITY_FIELD_HINTS.ip_rate_limit_enabled}
              checked={Boolean(systemForm.ip_rate_limit_enabled ?? true)}
              onChange={(checked) => setSystemForm((current) => ({ ...current, ip_rate_limit_enabled: checked }))}
            />
          </div>
        </div>

        {SECURITY_GROUPS.filter((group) => group.fields.length > 0).map((group) => (
          <div key={group.title} className="space-y-5 rounded-3xl border border-sage-100 bg-sage-50/70 p-6">
            <div>
              <h3 className="text-lg font-bold text-sage-900">{group.title}</h3>
              <p className="mt-1 text-sm text-sage-500">{group.description}</p>
            </div>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              {group.fields.map((key) => (
                <ConfigField
                  key={key}
                  label={SECURITY_FIELD_MAP[key]}
                  hint={SECURITY_FIELD_HINTS[key]}
                  defaultValue={SECURITY_FIELD_DEFAULTS[key]}
                >
                  <input
                    type="number"
                    className="input-field"
                    value={systemForm[key] ?? ''}
                    placeholder={String(SECURITY_FIELD_DEFAULTS[key] ?? '')}
                    onChange={(event) => setSystemForm((current) => ({ ...current, [key]: event.target.value }))}
                  />
                </ConfigField>
              ))}
            </div>
          </div>
        ))}

        <div className="space-y-5 rounded-3xl border border-sage-100 bg-sage-50/70 p-6">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <h3 className="text-lg font-bold text-sage-900">注册邮箱管理</h3>
              <p className="mt-1 text-sm text-sage-500">
                白名单模式下仅允许名单中的邮箱提供商注册；黑名单模式下仅拦截黑名单中的邮箱提供商。两套名单独立保存，可随时切换。
              </p>
            </div>
            <div className="inline-flex rounded-2xl border border-sage-200 bg-white p-1">
              <button
                type="button"
                className={cn(
                  'rounded-xl px-4 py-2 text-sm font-bold transition-all',
                  (systemForm.registration_email_provider_mode || 'blacklist') === 'blacklist'
                    ? 'bg-sage-600 text-white shadow-sm'
                    : 'text-sage-500 hover:text-sage-700',
                )}
                onClick={() => setSystemForm((current) => ({ ...current, registration_email_provider_mode: 'blacklist' }))}
              >
                黑名单模式
              </button>
              <button
                type="button"
                className={cn(
                  'rounded-xl px-4 py-2 text-sm font-bold transition-all',
                  systemForm.registration_email_provider_mode === 'whitelist'
                    ? 'bg-sage-600 text-white shadow-sm'
                    : 'text-sage-500 hover:text-sage-700',
                )}
                onClick={() => setSystemForm((current) => ({ ...current, registration_email_provider_mode: 'whitelist' }))}
              >
                白名单模式
              </button>
            </div>
          </div>

          <ProviderListSection
            title={activeProviderTitle}
            description={activeProviderDescription}
            providers={systemForm[activeProviderListKey] || []}
            inputValue={systemForm[activeProviderInputKey] || ''}
            onInputChange={(value) => setSystemForm((current) => ({ ...current, [activeProviderInputKey]: value }))}
            onAdd={() => addRegistrationProvider(activeProviderListKey, activeProviderInputKey)}
            onImport={(file) => importRegistrationProviders(activeProviderListKey, file)}
            onRemove={(provider) => removeRegistrationProvider(activeProviderListKey, provider)}
          />
        </div>
      </div>
    </SettingsShell>
  );
}

function MiniLineChart({ data, series }) {
  const [hoveredIndex, setHoveredIndex] = useState(null);
  const geometry = useMemo(() => {
    const width = 720;
    const height = 220;
    const values = data.flatMap((row) => series.map((item) => Number(row[item.key] || 0)));
    const max = Math.max(1, ...values);
    const paths = series.map((item) => {
      const points = data.map((row, index) => {
        const x = data.length <= 1 ? width / 2 : (index / (data.length - 1)) * width;
        const y = height - (Number(row[item.key] || 0) / max) * (height - 20) - 10;
        return { x, y };
      });
      return {
        ...item,
        points,
        polyline: points.map((point) => `${point.x},${point.y}`).join(' '),
      };
    });
    return { width, height, paths };
  }, [data, series]);
  const hoveredRow = hoveredIndex == null ? null : data[hoveredIndex];
  const hoveredX = hoveredIndex == null || data.length <= 1
    ? geometry.width / 2
    : (hoveredIndex / (data.length - 1)) * geometry.width;

  function selectPointerPosition(event) {
    if (!data.length) return;
    const bounds = event.currentTarget.getBoundingClientRect();
    const ratio = Math.min(1, Math.max(0, (event.clientX - bounds.left) / bounds.width));
    setHoveredIndex(data.length <= 1 ? 0 : Math.round(ratio * (data.length - 1)));
  }

  function moveKeyboardPosition(event) {
    if (!data.length || !['ArrowLeft', 'ArrowRight'].includes(event.key)) return;
    event.preventDefault();
    const direction = event.key === 'ArrowLeft' ? -1 : 1;
    setHoveredIndex((current) => Math.min(data.length - 1, Math.max(0, (current ?? data.length - 1) + direction)));
  }

  return (
    <div className="relative">
      <div className="mb-3 flex flex-wrap gap-4 text-xs font-bold text-sage-600">
        {series.map((item) => <span key={item.key} className="flex items-center gap-2"><span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: item.color }} />{item.label}</span>)}
      </div>
      {hoveredRow ? (
        <div
          className="pointer-events-none absolute top-9 z-10 min-w-44 rounded-xl border border-sage-700/20 bg-sage-900/95 px-4 py-3 text-xs text-white shadow-xl backdrop-blur"
          style={{
            left: `${data.length <= 1 ? 50 : (hoveredIndex / (data.length - 1)) * 100}%`,
            transform: hoveredIndex <= (data.length - 1) * 0.25
              ? 'translateX(0)'
              : hoveredIndex >= (data.length - 1) * 0.75
                ? 'translateX(-100%)'
                : 'translateX(-50%)',
          }}
        >
          <p className="mb-2 font-bold">北京时间 · {formatBeijingDate(hoveredRow.date, true)}</p>
          <div className="space-y-1.5">
            {series.map((item) => (
              <div key={item.key} className="flex items-center justify-between gap-6">
                <span className="flex items-center gap-2 text-white/80"><span className="h-2 w-2 rounded-full" style={{ backgroundColor: item.color }} />{item.label}</span>
                <span className="font-bold tabular-nums">{Number(hoveredRow[item.key] || 0).toLocaleString('zh-CN')}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}
      <svg
        viewBox={`0 0 ${geometry.width} ${geometry.height}`}
        className="h-56 w-full cursor-crosshair outline-none focus-visible:ring-2 focus-visible:ring-sage-400 focus-visible:ring-offset-2"
        role="img"
        aria-label={`${series.map((item) => item.label).join('、')}，按北京时间统计`}
        tabIndex="0"
        onPointerDown={selectPointerPosition}
        onPointerMove={selectPointerPosition}
        onPointerLeave={() => setHoveredIndex(null)}
        onFocus={() => { if (data.length) setHoveredIndex(data.length - 1); }}
        onBlur={() => setHoveredIndex(null)}
        onKeyDown={moveKeyboardPosition}
      >
        {[0, 1, 2, 3, 4].map((row) => <line key={row} x1="0" x2={geometry.width} y1={(row / 4) * geometry.height} y2={(row / 4) * geometry.height} stroke="currentColor" className="text-sage-100" />)}
        {geometry.paths.map((item) => <polyline key={item.key} points={item.polyline} fill="none" stroke={item.color} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />)}
        {hoveredRow ? <line x1={hoveredX} x2={hoveredX} y1="0" y2={geometry.height} stroke="currentColor" strokeWidth="1.5" strokeDasharray="5 5" className="text-sage-400" /> : null}
        {hoveredRow ? geometry.paths.map((item) => {
          const point = item.points[hoveredIndex];
          return <circle key={item.key} cx={point.x} cy={point.y} r="6" fill="white" stroke={item.color} strokeWidth="4" />;
        }) : null}
      </svg>
      <div className="mt-2 flex justify-between text-xs text-sage-400"><span>{formatBeijingDate(data[0]?.date)}</span><span>{formatBeijingDate(data.at(-1)?.date)}</span></div>
    </div>
  );
}

export function AdminDashboard({ data, loadDashboard, safely }) {
  const [days, setDays] = useState(30);
  useEffect(() => { void safely(() => loadDashboard(days), '看板数据加载失败'); }, [days, loadDashboard, safely]);
  const summary = data?.summary || {};
  return (
    <div className="space-y-6">
      <SectionHeader
        title="运营与安全看板"
        description="基于系统数据库与审计记录生成；全部日期与自然日边界均按北京时间（UTC+8）统计。"
        actions={(
          <div className="flex flex-col items-start gap-2 md:items-end">
            <span className="text-xs font-bold text-sage-500">选择统计时间范围</span>
            <div className="inline-flex rounded-2xl border border-sage-200 bg-white p-1 shadow-sm" role="group" aria-label="统计时间范围">
              {DASHBOARD_PERIODS.map((period) => (
                <button
                  key={period.days}
                  type="button"
                  className={cn(
                    'rounded-xl px-3 py-2 text-sm font-bold transition-colors',
                    days === period.days ? 'bg-sage-600 text-white' : 'text-sage-500 hover:bg-sage-50 hover:text-sage-700',
                  )}
                  aria-pressed={days === period.days}
                  onClick={() => setDays(period.days)}
                >
                  {period.label}
                </button>
              ))}
            </div>
          </div>
        )}
      />
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[['当前用户', summary.total_users ?? '-'], ['封禁账户', summary.banned_users ?? '-'], ['接入 OIDC 平台', summary.active_third_party_oidc_clients ?? '-'], ['全部活跃客户端', summary.active_oidc_clients ?? '-']].map(([label, value]) => <div key={label} className="glass-card rounded-2xl p-6"><p className="text-sm font-bold text-sage-500">{label}</p><p className="mt-3 text-3xl font-bold text-sage-900">{value}</p></div>)}
      </div>
      <div className="grid gap-6 xl:grid-cols-2">
        <div className="glass-card rounded-2xl p-6"><h2 className="mb-5 text-lg font-bold">用户数量变化</h2><MiniLineChart data={data?.user_growth || []} series={[{ key: 'total_users', label: '累计用户', color: '#587c5d' }, { key: 'new_users', label: '当日新增', color: '#a7c58b' }]} /></div>
        <div className="glass-card rounded-2xl p-6"><h2 className="mb-5 text-lg font-bold">登录与 OIDC 授权</h2><MiniLineChart data={data?.authentication_activity || []} series={[{ key: 'logins', label: '登录', color: '#587c5d' }, { key: 'authorizations', label: '授权码', color: '#d59b52' }]} /></div>
        <div className="glass-card rounded-2xl p-6 xl:col-span-2"><h2 className="mb-5 text-lg font-bold">邮箱与短信验证码发送</h2><MiniLineChart data={data?.verification_activity || []} series={[{ key: 'email_codes', label: '邮箱发放尝试', color: '#587c5d' }, { key: 'sms_codes', label: '短信成功响应', color: '#6689b8' }]} /></div>
      </div>
      <div className="rounded-2xl border border-sage-200 bg-sage-50 p-5 text-xs leading-6 text-sage-600">{Object.values(data?.definitions || {}).map((definition) => <p key={definition}>• {definition}</p>)}</div>
    </div>
  );
}

export function AdminLegalDocuments({ documents, loadDocuments, saveDraft, publishDocument, safely }) {
  const { confirm } = useRosemaryDialog();
  const [type, setType] = useState('terms');
  const [form, setForm] = useState({ title: '', content: '' });
  useEffect(() => { void safely(loadDocuments, '协议记录加载失败'); }, [loadDocuments, safely]);
  const selected = documents.filter((item) => item.type === type);
  const draft = selected.find((item) => item.status === 'draft');
  useEffect(() => {
    const source = draft || selected.find((item) => item.status === 'published');
    setForm({ title: source?.title || (type === 'terms' ? 'ROSM Pass 使用条款' : 'ROSM Pass 隐私政策'), content: source?.content || '' });
  }, [type, draft?.id, documents]);
  return (
    <div className="space-y-6">
      <SectionHeader title="使用条款与隐私政策" description="保存形成下一版本草稿；发布后立即成为当前版本，并要求用户在后续登录时重新明确同意。" />
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_320px]">
        <div className="glass-card rounded-2xl p-6">
          <div className="mb-5 flex gap-2">{[['terms', '使用条款'], ['privacy', '隐私政策']].map(([value, label]) => <button key={value} type="button" onClick={() => setType(value)} className={cn('rounded-xl px-4 py-2 text-sm font-bold', type === value ? 'bg-sage-600 text-white' : 'bg-sage-100 text-sage-600')}>{label}</button>)}</div>
          <div className="space-y-4"><input className="input-field" value={form.title} onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))} /><textarea className="input-field min-h-[520px] font-mono text-sm leading-6" value={form.content} onChange={(event) => setForm((current) => ({ ...current, content: event.target.value }))} /></div>
          <div className="mt-5 flex flex-wrap justify-end gap-3"><button type="button" className="btn-secondary" onClick={() => window.open(`/legal/${type}`, '_blank', 'noopener,noreferrer')}>预览当前发布版</button><button type="button" className="btn-primary" onClick={() => void safely(() => saveDraft({ type, ...form }), '草稿保存失败')}>保存下一版草稿</button>{draft ? <button type="button" className="rounded-xl bg-sage-900 px-5 py-3 font-bold text-white" onClick={() => void safely(async () => { const approved = await confirm({ title: `发布协议版本 ${draft.version}`, message: '发布后将立即成为当前版本，历史版本不可覆盖，所有用户下次登录时需要重新明确同意。', confirmLabel: '确认发布', tone: 'warning' }); if (!approved) return; await publishDocument(draft.id); }, '协议发布失败')}>发布版本 {draft.version}</button> : null}</div>
        </div>
        <aside className="glass-card h-fit rounded-2xl p-5"><h2 className="flex items-center gap-2 font-bold"><FileText size={18} />版本历史</h2><div className="mt-4 space-y-3">{selected.map((item) => <button key={item.id} type="button" onClick={() => setForm({ title: item.title, content: item.content })} className="w-full rounded-xl border border-sage-100 p-3 text-left"><div className="flex justify-between"><span className="font-bold">版本 {item.version}</span><span className={cn('text-xs font-bold', item.status === 'published' ? 'text-green-600' : 'text-amber-600')}>{item.status === 'published' ? '已发布' : '草稿'}</span></div><p className="mt-1 text-xs text-sage-400">{item.updated_at ? new Date(item.updated_at).toLocaleString('zh-CN') : '-'}</p></button>)}</div></aside>
      </div>
    </div>
  );
}

export function AdminUsers({ users, pagination, loadUsers, loadUser, updateUserStatus, safely, createUser, updateUserRoles, deleteUser }) {
  const { confirm } = useRosemaryDialog();
  const [search, setSearch] = useState('');
  const [createForm, setCreateForm] = useState({
    email: '',
    nickname: '',
    password: '',
    roles: 'user',
  });
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [editingRoles, setEditingRoles] = useState('user');
  const [viewingUser, setViewingUser] = useState(null);
  const [banReason, setBanReason] = useState('');

  useEffect(() => {
    void safely(() => loadUsers({ page: 1, search: '' }), '用户数据加载失败');
  }, [loadUsers, safely]);

  return (
    <div className="space-y-6">
      <SectionHeader
        title="用户管理"
        description="查看当前所有已注册用户，并通过分页方式检索账户。"
        actions={(
          <button type="button" className="btn-primary flex items-center gap-2" onClick={() => setCreateModalOpen(true)}>
            <UserPlus size={18} />
            添加新用户
          </button>
        )}
      />

      <div className="glass-card rounded-2xl p-4">
        <div className="flex flex-col gap-4 md:flex-row">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-sage-400" size={18} />
            <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="搜索昵称或邮箱..." className="input-field pl-10" />
          </div>
          <button type="button" className="btn-secondary" onClick={() => void safely(() => loadUsers({ page: 1, search }), '用户数据加载失败')}>
            查询
          </button>
        </div>
      </div>

      <div className="glass-card overflow-hidden rounded-2xl">
        <div className="overflow-x-auto">
          <table className="min-w-[760px] w-full border-collapse text-left">
            <thead>
              <tr className="border-b border-sage-100 bg-sage-50/50">
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-wider text-sage-500">用户</th>
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-wider text-sage-500">状态</th>
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-wider text-sage-500">角色</th>
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-wider text-sage-500">用户 ID</th>
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-wider text-sage-500">操作</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-sage-50">
              {users.map((user, index) => (
                <tr key={user.id || `${user.email}-${index}`} className="cursor-pointer transition-colors hover:bg-sage-50/60" onClick={() => void safely(async () => { setViewingUser(await loadUser(user.id)); setBanReason(''); }, '用户详情加载失败')}>
                  <td className="px-6 py-4">
                    <p className="text-sm font-semibold text-sage-900">{cleanDisplayName(user.nickname, user.email || '-')}</p>
                    <p className="text-xs text-sage-400">{user.email || '-'}</p>
                  </td>
                  <td className="px-6 py-4">
                    <span className={cn('inline-flex rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide', user.account_status === 'banned' ? 'bg-red-100 text-red-700' : user.is_email_verified ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700')}>
                      {user.account_status === 'banned' ? '已封禁' : user.is_email_verified ? '已验证' : '待验证'}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex flex-wrap gap-2">
                      {(user.roles || []).map((role) => (
                        <span key={role} className="rounded-full bg-sage-100 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-sage-700">
                          {role}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-sm text-sage-400">{user.id || '-'}</td>
                  <td className="px-6 py-4">
                    <div className="flex gap-2">
                      <button
                        type="button"
                        className="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-sage-200 bg-white text-sage-600 transition-colors hover:bg-sage-50"
                        aria-label={`编辑 ${cleanDisplayName(user.nickname, user.email || '-')}`}
                        onClick={(event) => {
                          event.stopPropagation();
                          setEditingUser(user);
                          setEditingRoles((user.roles || []).join(', '));
                        }}
                      >
                        <Pencil size={16} />
                      </button>
                      <button
                        type="button"
                        className="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-red-200 bg-white text-red-600 transition-colors hover:bg-red-50"
                        aria-label={`删除 ${cleanDisplayName(user.nickname, user.email || '-')}`}
                        onClick={(event) => {
                          event.stopPropagation();
                          void safely(async () => {
                            const confirmed = await confirm({
                              title: '删除用户',
                              message: `确定删除用户“${cleanDisplayName(user.nickname, user.email || '未命名用户')}”吗？此操作不可撤销。`,
                              confirmLabel: '删除用户',
                              tone: 'danger',
                            });
                            if (!confirmed) {
                              return;
                            }
                            await deleteUser(user.id);
                            await loadUsers({ page: pagination.page || 1, search });
                          }, '删除用户失败');
                        }}
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!users.length && (
                <tr>
                  <td colSpan="5" className="px-6 py-10 text-center text-sm text-sage-400">暂无用户数据</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        <div className="flex flex-col gap-3 border-t border-sage-100 p-4 text-sm text-sage-500 sm:flex-row sm:items-center sm:justify-between">
          <p>第 {pagination.page} 页 / 共 {pagination.total_pages || 1} 页，累计 {pagination.total} 位用户</p>
          <div className="flex gap-2">
            <button type="button" className="btn-secondary px-4 py-2" disabled={pagination.page <= 1} onClick={() => void safely(() => loadUsers({ page: pagination.page - 1, search }), '用户数据加载失败')}>
              上一页
            </button>
            <button type="button" className="btn-secondary px-4 py-2" disabled={pagination.total_pages === 0 || pagination.page >= pagination.total_pages} onClick={() => void safely(() => loadUsers({ page: pagination.page + 1, search }), '用户数据加载失败')}>
              下一页
            </button>
          </div>
        </div>
      </div>

      {createModalOpen && (
        <Modal
          title="添加新用户"
          onClose={() => setCreateModalOpen(false)}
          actions={(
            <>
              <button type="button" className="btn-secondary" onClick={() => setCreateModalOpen(false)}>
                取消
              </button>
              <button
                type="button"
                className="btn-primary"
                onClick={() =>
                  void safely(async () => {
                    await createUser(createForm);
                    setCreateForm({
                      email: '',
                      nickname: '',
                      password: '',
                      roles: 'user',
                    });
                    setCreateModalOpen(false);
                    await loadUsers({ page: 1, search });
                  }, '新增用户失败')
                }
              >
                创建用户
              </button>
            </>
          )}
        >
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <input
              className="input-field"
              placeholder="邮箱"
              value={createForm.email}
              onChange={(event) => setCreateForm((current) => ({ ...current, email: event.target.value }))}
            />
            <input
              className="input-field"
              placeholder="昵称"
              value={createForm.nickname}
              onChange={(event) => setCreateForm((current) => ({ ...current, nickname: event.target.value }))}
            />
            <input
              className="input-field md:col-span-2"
              placeholder="初始密码"
              value={createForm.password}
              onChange={(event) => setCreateForm((current) => ({ ...current, password: event.target.value }))}
            />
            <input
              className="input-field md:col-span-2"
              placeholder="角色，用逗号分隔"
              value={createForm.roles}
              onChange={(event) => setCreateForm((current) => ({ ...current, roles: event.target.value }))}
            />
          </div>
        </Modal>
      )}

      {editingUser && (
        <Modal
          title={`编辑权限 · ${cleanDisplayName(editingUser.nickname, editingUser.email || '-')}`}
          onClose={() => setEditingUser(null)}
          actions={(
            <>
              <button type="button" className="btn-secondary" onClick={() => setEditingUser(null)}>
                取消
              </button>
              <button
                type="button"
                className="btn-primary"
                onClick={() =>
                  void safely(async () => {
                    await updateUserRoles(editingUser.id, editingRoles);
                    setEditingUser(null);
                    await loadUsers({ page: pagination.page || 1, search });
                  }, '更新用户权限失败')
                }
              >
                保存
              </button>
            </>
          )}
        >
          <div className="space-y-3">
            <div className="flex flex-wrap gap-2">
              {(editingUser.roles || []).map((role) => (
                <span key={role} className="rounded-full bg-sage-100 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-sage-700">
                  {role}
                </span>
              ))}
            </div>
            <input
              className="input-field"
              placeholder="角色，用逗号分隔"
              value={editingRoles}
              onChange={(event) => setEditingRoles(event.target.value)}
            />
          </div>
        </Modal>
      )}

      {viewingUser && (
        <Modal title={`用户详情 · ${cleanDisplayName(viewingUser.nickname, viewingUser.email || '-')}`} onClose={() => setViewingUser(null)} actions={<button type="button" className="btn-secondary" onClick={() => setViewingUser(null)}>关闭</button>}>
          <div className="grid gap-3 text-sm sm:grid-cols-2">
            {[
              ['用户 ID', viewingUser.id], ['注册时间', viewingUser.created_at ? new Date(viewingUser.created_at).toLocaleString('zh-CN') : '-'],
              ['邮箱', viewingUser.email || '-'], ['邮箱验证', viewingUser.is_email_verified ? '已验证' : '未验证'],
              ['手机号', viewingUser.phone_number || '-'], ['手机验证', viewingUser.is_phone_verified ? '已验证' : '未验证'],
              ['通行密钥', `${viewingUser.passkey_count || 0} 个`], ['近期 OIDC 授权', `${viewingUser.oidc_authorization_count || 0} 次`],
              ['最近登录', viewingUser.last_login_at ? new Date(viewingUser.last_login_at).toLocaleString('zh-CN') : '-'], ['账户状态', viewingUser.account_status === 'banned' ? '已封禁' : '正常'],
            ].map(([label, value]) => <div key={label} className="rounded-xl bg-sage-50 p-3"><p className="text-xs font-bold text-sage-400">{label}</p><p className="mt-1 break-all font-semibold text-sage-800">{value}</p></div>)}
          </div>
          {viewingUser.account_status === 'banned' ? (
            <div className="mt-5 rounded-2xl border border-red-100 bg-red-50 p-4"><p className="text-sm text-red-700">封禁原因：{viewingUser.banned_reason || '-'}</p><button type="button" className="mt-4 inline-flex items-center gap-2 rounded-xl bg-green-700 px-4 py-2 font-bold text-white" onClick={() => void safely(async () => { await updateUserStatus(viewingUser.id, 'active'); setViewingUser(await loadUser(viewingUser.id)); await loadUsers({ page: pagination.page || 1, search }); }, '解封失败')}><UserCheck size={17} />解封账户</button></div>
          ) : (
            <div className="mt-5 rounded-2xl border border-red-100 bg-red-50/60 p-4"><label className="text-sm font-bold text-red-700">封禁原因</label><textarea value={banReason} onChange={(event) => setBanReason(event.target.value)} className="input-field mt-2 min-h-24" placeholder="请记录可审计的封禁原因（至少 3 个字）" /><button type="button" disabled={banReason.trim().length < 3} className="mt-3 inline-flex items-center gap-2 rounded-xl bg-red-600 px-4 py-2 font-bold text-white disabled:opacity-40" onClick={() => void safely(async () => { const approved = await confirm({ title: '封禁账户并撤销会话', message: '封禁将立即撤销该用户的全部 Access Token 和 Refresh Token，用户会立即失去访问权限。', confirmLabel: '确认封禁', tone: 'danger' }); if (!approved) return; await updateUserStatus(viewingUser.id, 'banned', banReason.trim()); setViewingUser(await loadUser(viewingUser.id)); await loadUsers({ page: pagination.page || 1, search }); }, '封禁失败')}><Ban size={17} />封禁并撤销会话</button></div>
          )}
        </Modal>
      )}
    </div>
  );
}

export function AdminOIDCConfig({ discovery, oidcSettings, loadDiscovery, oidcClients, loadOidcClients, safely, oidcForm, setOidcForm, saveOidcClient, deleteOidcClient }) {
  const { alert, confirm } = useRosemaryDialog();
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingClientId, setEditingClientId] = useState('');
  const [oneTimeSecret, setOneTimeSecret] = useState(null);
  const [copyingSecret, setCopyingSecret] = useState(false);

  useEffect(() => {
    if (!discovery) {
      void safely(loadDiscovery, '协议配置加载失败');
    }
    if (!oidcClients.length) {
      void safely(loadOidcClients, 'OIDC 客户端加载失败');
    }
  }, [discovery, loadDiscovery, loadOidcClients, oidcClients.length, safely]);

  function openCreateModal() {
    setOidcForm({
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
    setEditingClientId('');
    setEditorOpen(true);
  }

  function openEditModal(client) {
    const redirectUris = client.redirect_uris || [];
    const appRedirectUris = redirectUris.filter(isMobileCustomRedirectUri);
    const webRedirectUris = redirectUris.filter((uri) => !isMobileCustomRedirectUri(uri));
    setOidcForm({
      client_id: client.client_id || '',
      display_name: client.display_name || '',
      is_official: Boolean(client.is_official),
      enable_web: webRedirectUris.length > 0,
      enable_app: appRedirectUris.length > 0,
      web_redirect_uris: webRedirectUris.join('\n'),
      app_redirect_uri: appRedirectUris[0] || '',
      redirect_uris: redirectUris.join('\n'),
      scopes: (client.scopes || []).join('\n'),
      grant_types: (client.grant_types || []).join('\n'),
      client_secret: '',
      generate_client_secret: false,
      is_confidential: Boolean(client.is_confidential),
      is_active: client.is_active !== false,
    });
    setEditingClientId(client.client_id || '');
    setEditorOpen(true);
  }

  const selectedScopes = parseUniqueLines(oidcForm.scopes);
  const scopeSet = new Set(selectedScopes);

  function toggleScope(scope, checked) {
    const nextScopes = checked
      ? (scopeSet.has(scope) ? selectedScopes : [...selectedScopes, scope])
      : selectedScopes.filter((item) => item !== scope);
    setOidcForm((current) => ({ ...current, scopes: nextScopes.join('\n') }));
  }

  function applyMobilePublicTemplate() {
    setOidcForm((current) => {
      const rawClientId = current.client_id.trim() || 'com.example.app';
      const scheme = rawClientId
        .toLowerCase()
        .replace(/\.mobile$/, '')
        .replace(/[^a-z0-9+.-]/g, '.')
        .replace(/^[^a-z]+/, 'app.');
      return {
        ...current,
        client_id: rawClientId,
        enable_app: true,
        app_redirect_uri: `${scheme}:/oidc/callback`,
        redirect_uris: [
          ...(current.enable_web ? parseUniqueLines(current.web_redirect_uris || current.redirect_uris) : []),
          `${scheme}:/oidc/callback`,
        ].join('\n'),
        scopes: 'openid\nprofile\nemail\nphone\naccountRule',
        grant_types: 'authorization_code\nrefresh_token',
        client_secret: '',
        generate_client_secret: false,
        is_confidential: false,
        is_active: true,
      };
    });
  }

  function discardOneTimeSecret() {
    setOneTimeSecret(null);
    setCopyingSecret(false);
  }

  async function copyOneTimeSecret() {
    if (!oneTimeSecret?.value || copyingSecret) return;
    setCopyingSecret(true);
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(oneTimeSecret.value);
      } else {
        const textarea = document.createElement('textarea');
        textarea.value = oneTimeSecret.value;
        textarea.setAttribute('readonly', 'true');
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        const copied = document.execCommand('copy');
        document.body.removeChild(textarea);
        if (!copied) throw new Error('copy_failed');
      }
      discardOneTimeSecret();
    } catch {
      setCopyingSecret(false);
      await alert({ title: '复制失败', message: '无法自动写入剪贴板，请手动复制密钥后再关闭窗口。', tone: 'warning' });
    }
  }

  return (
    <SettingsShell
      icon={Key}
      title="OIDC 接入"
      description="集中查看协议运行参数，并通过弹窗新增或编辑客户端配置。"
      onSubmit={(event) => event.preventDefault()}
      actions={
        <>
          <Link to="/admin/oidc/docs" className="btn-secondary flex items-center gap-2">
            <BookOpen size={18} />
            接入文档
          </Link>
          <button className="btn-primary" type="button" onClick={openCreateModal}>添加应用</button>
        </>
      }
    >
      <div className="grid grid-cols-1 gap-8 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="space-y-6">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <InfoRow label="Issuer" value={oidcSettings?.issuer || discovery?.issuer} />
            <InfoRow label="授权端点" value={oidcSettings?.authorization_endpoint || discovery?.authorization_endpoint} />
            <InfoRow label="Token 端点" value={oidcSettings?.token_endpoint || discovery?.token_endpoint} />
            <InfoRow label="UserInfo 端点" value={oidcSettings?.userinfo_endpoint || discovery?.userinfo_endpoint} />
            <InfoRow label="JWKS" value={oidcSettings?.jwks_uri || discovery?.jwks_uri} />
            <InfoRow label="PKCE" value={oidcSettings?.pkce_required ? '强制 S256' : '可选'} />
          </div>
          <div className="rounded-3xl border border-sage-100 bg-white p-5">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h3 className="text-base font-bold text-sage-900">协议发现</h3>
                <p className="mt-1 text-sm text-sage-500">用于确认当前对外发布的协议地址和基础能力。</p>
              </div>
              <button type="button" className="rounded-xl bg-sage-100 p-2.5 text-sage-600 hover:bg-sage-200" onClick={() => void safely(loadDiscovery, '协议配置加载失败')}>
                <Globe size={20} />
              </button>
            </div>
          </div>
        </div>
        <div className="space-y-3">
          <p className="text-xs font-bold uppercase tracking-widest text-sage-400">已接入应用</p>
          <div className="max-h-[560px] space-y-2 overflow-auto pr-1">
            {oidcClients.map((client) => (
              <div
                key={client.client_id}
                className="rounded-2xl border border-sage-200 bg-white px-4 py-3 transition-all hover:bg-sage-50"
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-sage-900">{client.display_name || client.client_id}</p>
                    {client.display_name ? <p className="mt-0.5 text-[11px] text-sage-400">{client.client_id}</p> : null}
                    <p className="mt-1 text-[11px] text-sage-400">{client.is_official ? '官方应用' : '第三方应用'}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={cn('rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide', client.is_active === false ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700')}>
                      {client.is_active === false ? '停用' : '启用'}
                    </span>
                    <button
                      type="button"
                      className="inline-flex h-8 w-8 items-center justify-center rounded-lg border border-sage-200 bg-white text-sage-600 hover:bg-sage-50"
                      aria-label={`编辑 ${client.client_id}`}
                      onClick={() => openEditModal(client)}
                    >
                      <Pencil size={14} />
                    </button>
                    <button
                      type="button"
                      className="inline-flex h-8 w-8 items-center justify-center rounded-lg border border-red-200 bg-white text-red-600 hover:bg-red-50"
                      aria-label={`删除 ${client.client_id}`}
                      onClick={(event) => {
                        event.stopPropagation();
                        void safely(async () => {
                          const confirmed = await confirm({
                            title: '删除 OIDC 应用',
                            message: `确定删除 OIDC 应用“${client.client_id}”吗？现有授权流程将立即失效。`,
                            confirmLabel: '删除应用',
                            tone: 'danger',
                          });
                          if (!confirmed) {
                            return;
                          }
                          await deleteOidcClient(client.client_id);
                          if (editingClientId === client.client_id) {
                            setEditorOpen(false);
                          }
                        }, '删除 OIDC 应用失败');
                      }}
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
                <p className="mt-2 line-clamp-2 text-xs text-sage-400">{(client.redirect_uris || []).join(', ') || '未配置 redirect URI'}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {editorOpen && (
        <Modal
          title={editingClientId ? `编辑应用 · ${editingClientId}` : '添加应用'}
          onClose={() => setEditorOpen(false)}
          actions={(
            <>
              <button type="button" className="btn-secondary" onClick={() => setEditorOpen(false)}>
                取消
              </button>
              <button
                type="button"
                className="btn-primary"
                onClick={() =>
                  void safely(async () => {
                    const result = await saveOidcClient({ preventDefault() {} });
                    if (!result) return;
                    setEditorOpen(false);
                    if (result?.client_secret) {
                      setOneTimeSecret({
                        clientId: oidcForm.client_id.trim(),
                        value: result.client_secret,
                      });
                    }
                  }, editingClientId ? '更新应用失败' : '添加应用失败')
                }
              >
                保存应用
              </button>
            </>
          )}
        >
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <ConfigField label="Client ID">
              <input className="input-field" placeholder="例如 com.rosm.donut" value={oidcForm.client_id} onChange={(event) => setOidcForm((current) => ({ ...current, client_id: event.target.value }))} required />
            </ConfigField>
            <ConfigField label="展示名称">
              <input className="input-field" placeholder="例如 Donut App" value={oidcForm.display_name} onChange={(event) => setOidcForm((current) => ({ ...current, display_name: event.target.value }))} />
            </ConfigField>
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4">
              <div className="flex items-center justify-between gap-3 text-sm font-bold text-sage-800">
                <span>启用 Web</span>
                <RosemaryCheckbox checked={Boolean(oidcForm.enable_web)} onCheckedChange={(checked) => setOidcForm((current) => ({ ...current, enable_web: checked }))} ariaLabel="启用 Web" />
              </div>
              <p className="mt-2 text-xs leading-5 text-sage-500">Web 使用 HTTPS 或 loopback 回调。仅 Web 启用时可选择机密客户端。</p>
              <textarea rows="3" className="input-field mt-3" disabled={!oidcForm.enable_web} placeholder="https://app.example.com/auth/callback" value={oidcForm.web_redirect_uris || ''} onChange={(event) => setOidcForm((current) => ({ ...current, web_redirect_uris: event.target.value }))} />
            </div>

            <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4">
              <div className="flex items-center justify-between gap-3 text-sm font-bold text-sage-800">
                <span>启用 App</span>
                <RosemaryCheckbox checked={Boolean(oidcForm.enable_app)} onCheckedChange={(checked) => setOidcForm((current) => ({ ...current, enable_app: checked }))} ariaLabel="启用 App" />
              </div>
              <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
                <p className="text-xs leading-5 text-sage-500">Public 直连使用自定义 scheme；服务端交接使用上方 HTTPS 回调并可保持机密客户端。</p>
                <button type="button" className="btn-secondary inline-flex items-center gap-2 px-3 py-2 text-xs" onClick={applyMobilePublicTemplate}>
                  <Smartphone size={14} />
                  生成
                </button>
              </div>
              <input className="input-field mt-3" disabled={!oidcForm.enable_app} placeholder="com.example.app:/oidc/callback" value={oidcForm.app_redirect_uri || ''} onChange={(event) => setOidcForm((current) => ({ ...current, app_redirect_uri: event.target.value }))} />
            </div>
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-[minmax(0,1fr)_280px]">
            <ConfigField label="Scopes">
              <div className="grid max-h-44 grid-cols-1 gap-2 overflow-y-auto rounded-2xl border border-sage-100 bg-sage-50/70 p-3 sm:grid-cols-2">
                {OIDC_SCOPE_OPTIONS.map((scope) => (
                  <RosemaryCheckbox
                      key={scope.value}
                      checked={scopeSet.has(scope.value)}
                      onCheckedChange={(checked) => toggleScope(scope.value, checked)}
                      className="rounded-xl bg-white px-3 py-2"
                    >
                    <span>
                      <span className="block text-sm font-semibold text-sage-800">{scope.label}</span>
                      <span className="block text-xs leading-4 text-sage-500">{scope.description}</span>
                    </span>
                  </RosemaryCheckbox>
                ))}
              </div>
            </ConfigField>
            <div className="space-y-4">
              <ConfigField label="Grant Types">
                <textarea rows="3" className="input-field" value={oidcForm.grant_types} onChange={(event) => setOidcForm((current) => ({ ...current, grant_types: event.target.value }))} />
              </ConfigField>
              <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-4">
                <p className="text-sm font-bold text-sage-800">Client Secret</p>
                <p className="mt-2 text-xs leading-5 text-sage-500">
                  {editingClientId
                    ? '现有密钥不会显示。需要更换时勾选轮换，保存后仅展示一次新密钥。'
                    : '机密客户端由服务端自动生成 256 位随机密钥，保存后仅展示一次。'}
                </p>
                {editingClientId && oidcForm.is_confidential ? (
                  <RosemaryCheckbox className="mt-3 text-sage-700" checked={Boolean(oidcForm.generate_client_secret)} onCheckedChange={(checked) => setOidcForm((current) => ({ ...current, generate_client_secret: checked }))}>
                    保存时安全轮换密钥
                  </RosemaryCheckbox>
                ) : null}
              </div>
            </div>
          </div>

          <div className="flex flex-wrap gap-5 rounded-2xl border border-sage-100 bg-sage-50/80 p-4">
            <RosemaryCheckbox checked={oidcForm.is_official} onCheckedChange={(checked) => setOidcForm((current) => ({ ...current, is_official: checked }))}>
              官方应用
            </RosemaryCheckbox>
            <RosemaryCheckbox
                checked={Boolean(oidcForm.is_confidential)}
                onCheckedChange={(checked) => setOidcForm((current) => ({
                  ...current,
                  is_confidential: checked,
                  generate_client_secret: checked && !current.is_confidential
                    ? true
                    : current.generate_client_secret,
                }))}
              >
              机密客户端
            </RosemaryCheckbox>
            <RosemaryCheckbox checked={oidcForm.is_active} onCheckedChange={(checked) => setOidcForm((current) => ({ ...current, is_active: checked }))}>
              启用应用
            </RosemaryCheckbox>
            <p className="basis-full text-xs leading-5 text-sage-500">
              同一个包名可以同时启用 Web/App。服务端交接模式可使用机密客户端和 HTTPS 回调；Public 直连模式必须关闭机密客户端并使用自定义 scheme。
            </p>
          </div>
        </Modal>
      )}

      {oneTimeSecret && (
        <Modal
          title="复制 Client Secret"
          onClose={discardOneTimeSecret}
          actions={(
            <button type="button" className="btn-primary inline-flex items-center gap-2" onClick={() => void copyOneTimeSecret()} disabled={copyingSecret}>
              {copyingSecret ? <Check size={18} /> : <Copy size={18} />}
              {copyingSecret ? '正在复制' : '复制一次并关闭'}
            </button>
          )}
        >
          <div className="space-y-4">
            <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm leading-6 text-amber-900">
              这是应用 <strong>{oneTimeSecret.clientId}</strong> 的新密钥。服务端只保存哈希，关闭后无法再次查看；请立即复制到接入方服务器的密钥管理系统。
            </div>
            <code className="block break-all rounded-2xl border border-sage-200 bg-sage-950 p-4 font-mono text-sm leading-6 text-white" data-sensitive="true">
              {oneTimeSecret.value}
            </code>
            <p className="text-xs leading-5 text-sage-500">生产环境请仅通过 HTTPS 管理页面操作。复制成功后，此页面中的明文会立即销毁。</p>
          </div>
        </Modal>
      )}
    </SettingsShell>
  );
}

export function AdminOidcDocsPage({ discovery, oidcSettings }) {
  const issuer = oidcSettings?.issuer || discovery?.issuer || '';
  const authorizationEndpoint = oidcSettings?.authorization_endpoint || discovery?.authorization_endpoint || '';
  const tokenEndpoint = oidcSettings?.token_endpoint || discovery?.token_endpoint || '';
  const userinfoEndpoint = oidcSettings?.userinfo_endpoint || discovery?.userinfo_endpoint || '';
  const jwksUri = oidcSettings?.jwks_uri || discovery?.jwks_uri || '';
  const introspectionEndpoint = oidcSettings?.introspection_endpoint || discovery?.introspection_endpoint || '';
  const revocationEndpoint = oidcSettings?.revocation_endpoint || discovery?.revocation_endpoint || '';
  const accessTokenTtl = oidcSettings?.access_token_ttl_seconds || '';
  const refreshTokenTtl = oidcSettings?.refresh_token_ttl_seconds || '';
  const [copying, setCopying] = useState(false);

  const docsMarkdown = [
    '# OIDC 接入文档',
    '',
    '面向接入方的完整中文说明，包含协议概念、当前实现、典型配置与最佳实践。管理员登录后即可直接查看生效参数，无需再翻服务器文件。',
    '',
    '## 当前生效参数',
    '',
    '以下内容来自当前后台已鉴权读取到的运行配置，可直接提供给接入方使用。',
    '',
    `- Issuer：${issuer}`,
    `- 授权端点：${authorizationEndpoint}`,
    `- Token 端点：${tokenEndpoint}`,
    `- UserInfo 端点：${userinfoEndpoint}`,
    `- JWKS：${jwksUri}`,
    `- Introspect：${introspectionEndpoint}`,
    `- Revoke：${revocationEndpoint}`,
    `- PKCE 要求：${oidcSettings?.pkce_required ? '必须使用 S256' : '当前未强制'}`,
    `- Access Token TTL：${accessTokenTtl ? `${accessTokenTtl} 秒` : ''}`,
    `- Refresh Token TTL：${refreshTokenTtl ? `${refreshTokenTtl} 秒` : ''}`,
    `- JWT Issuer：${oidcSettings?.jwt_issuer || ''}`,
    `- JWT Audience：${oidcSettings?.jwt_audience || ''}`,
    '',
    '## 1. 什么是 OIDC',
    '',
    'OIDC 是建立在 OAuth 2.0 之上的身份层协议。OAuth 2.0 解决“授权访问资源”，OIDC 进一步解决“确认用户是谁”。典型流程是应用把用户带到身份提供方登录，身份提供方确认身份后返回授权码，应用再用授权码换取令牌并读取用户资料。',
    '',
    '在接入实践里，最常见的是授权码模式配合 PKCE。这样前端负责引导用户跳转和回调，后端负责用授权码换令牌、验证令牌并建立本地会话。',
    '',
    '## 2. 当前服务支持范围',
    '',
    '- 已支持：Discovery、authorization_code、refresh_token、userinfo、jwks、introspect、revoke、PKCE S256、RS256',
    '- 已支持 id_token：当 scope 包含 openid 时，token 端点会返回 id_token。',
    '- 当前差异：token/introspect/revoke 目前使用 JSON body。',
    '',
    '## 3. 典型客户端配置',
    '',
    '推荐优先使用机密客户端，后端持有 `client_secret`，前端不要直接暴露。默认 scope 建议使用 `openid profile email phone`，grant type 建议启用 `authorization_code` 和 `refresh_token`。',
    '',
    '- `Client ID`：应用唯一标识，例如 `my-web-app`',
    '- `Redirect URI`：必须精确登记回调地址，不能只配域名',
    '- `Scopes`：建议至少包含 `openid`，如需邮箱、手机号和昵称则补 `email`、`phone`、`profile`',
    '- 可用 Scopes：`openid`、`profile`、`email`、`phone`、`accountRule`',
    '- `Nonce`：当 `scope` 包含 `openid` 时必须传 `nonce`，否则授权请求会被拒绝（400）',
    '- `Grant Types`：常规 Web 应用建议开启授权码与刷新令牌',
    '- `Confidential`：服务端应用建议开启；纯前端公共客户端才考虑关闭',
    '',
    '## 4. Flutter SDK 原生接入',
    '',
    `SDK 地址：${FLUTTER_SDK_GITHUB_URL}`,
    '',
    '移动端 Flutter 应用建议使用 ROSM Passport Flutter SDK，以原生 Rosemary 风格页面完成登录和授权确认，不需要跳转到 Web 登录页。生产业务应用推荐使用服务端交接模式：SDK 只取得授权码并交给接入方服务器，接入方服务器作为机密客户端换 token 并创建业务会话。',
    '',
    '管理端配置建议：',
    '',
    '- `Client ID`：例如 `my-flutter-app`',
    '- `Display Name`：填写展示给用户看的应用名',
    '- `Redirect URI`：服务端交接模式使用接入方服务器 HTTPS 回调，例如 `https://api.example.com/auth/rosm/callback`；Public 直连模式才使用自定义 scheme，例如 `com.example.app:/oidc/callback`',
    '- `Scopes`：至少包含 `openid profile`，按需增加 `email`、`phone`、`accountRule`',
    '- `Grant Types`：启用 `authorization_code` 和 `refresh_token`',
    '- `Confidential`：服务端交接模式开启，secret 只放接入方服务器；Public 直连模式关闭',
    '- `Active`：开启',
    '',
    'Flutter 侧依赖：',
    '',
    '```yaml',
    'dependencies:',
    '  rosm_passport_flutter:',
    `    git: ${FLUTTER_SDK_GITHUB_URL}`,
    '```',
    '',
    'Flutter 侧示例：',
    '',
    '```dart',
    `final passport = RosmPassportClient(
  issuer: Uri.parse('${issuer || 'https://auth.example.com'}'),
  clientId: 'my-flutter-app',
  redirectUri: Uri.parse('https://api.example.com/auth/rosm/callback'),
  scopes: const {'openid', 'profile', 'email', 'phone'},
);

final result = await showRosmPassportSignIn(
  context,
  client: passport,
  config: RosmPassportSignInConfig(
    serverHandoffEndpoint: Uri.parse(
      'https://api.example.com/auth/rosm/sdk/complete',
    ),
    enableRegistration: true,
  ),
);
final appSession = result?.serverPayload;`,
    '```',
    '',
    'SDK 内置 UI 支持验证码登录、手机号登录、密码登录、密码二次验证、忘记密码、通行密钥登录、邮箱注册和最终授权确认。注册默认开启；如果某个应用不允许新用户注册，可以设置 `enableRegistration: false`。',
    '',
    'SDK 对应用侧暴露 Dart 类型和方法，例如 `RosmPassportSignInConfig`、`RosmPassportUiResult`、`RosmAuthorizationStart`、`RosmAuthResult`、`RosmUserInfo`、`RosmTokenSet`。JSON 请求和响应只在 SDK 内部处理。',
    '',
    '接入方服务器必须实现的 SDK handoff 契约：',
    '',
    '- `serverHandoffEndpoint` 不是传统浏览器 OIDC callback。传统 callback 接收 query 里的 `code/state`；SDK complete endpoint 接收 App 发来的 JSON POST。',
    '- 建议提供 `POST /auth/rosm/sdk/start` 创建登录 challenge，返回 `state`、`nonce`、`client_id`、`redirect_uri`、`scope` 和 complete endpoint。',
    '- `POST /auth/rosm/sdk/complete` 必须校验 challenge 未过期、未消费、与当前设备/会话绑定，并校验 `issuer`、`client_id`、`redirect_uri`、`scope`、`state`、`nonce` 都匹配。',
    '- 服务器用 `code`、`code_verifier`、`client_secret` 调用 ROSM token 端点；随后用 JWKS 校验 ID Token 签名和 `iss`、`aud`、`exp`、`iat`、`nonce`。',
    '- 授权码和 challenge 都按一次性使用处理。完成后由接入方服务器签发自己的 App session；不要把 `client_secret` 返回给 App，通常也不要把 ROSM refresh token 下发到 App。',
    '',
    '```json',
    `{
  "client_id": "com.cruos.zion",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "scope": "openid profile email phone accountRule",
  "state": "SERVER_GENERATED_STATE",
  "nonce": "SERVER_GENERATED_NONCE",
  "handoff_endpoint": "https://api.example.com/auth/rosm/sdk/complete"
}`,
    '```',
    '',
    '## 5. Web / 服务端接入步骤',
    '',
    '步骤一：读取 Discovery',
    '```',
    `GET ${issuer}/.well-known/openid-configuration`,
    '```',
    '',
    '步骤二：浏览器跳转到授权端点',
    '```',
    `${authorizationEndpoint}?response_type=code&client_id=my-web-app&redirect_uri=${encodeURIComponent('https://app.example.com/callback')}&scope=openid%20profile%20email%20phone&state=random_state&nonce=random_nonce&code_challenge=BASE64URL_SHA256&code_challenge_method=S256`,
    '```',
    '',
    '步骤三：后端交换令牌',
    '```',
    `POST ${tokenEndpoint}
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "AUTH_CODE",
  "client_id": "my-web-app",
  "client_secret": "YOUR_CLIENT_SECRET",
  "redirect_uri": "https://app.example.com/callback",
  "code_verifier": "ORIGINAL_CODE_VERIFIER"
}`,
    '```',
    '',
    '步骤四：读取用户信息',
    '```',
    `GET ${userinfoEndpoint}
Authorization: Bearer ACCESS_TOKEN`,
    '```',
    '',
    '## 6. 最佳实践',
    '',
    '- 始终启用 PKCE，且使用 `S256`。',
    '- 当 `scope` 包含 `openid` 时务必携带 `nonce`，避免授权端点直接拒绝请求。',
    '- 若申请 `accountRule`，应用可从 UserInfo 读取账户角色（如 admin/user）。',
    '- 机密客户端只把 `client_secret` 放在服务端，前端不要持有。',
    '- 回调地址要精确登记到完整路径，避免使用宽泛匹配。',
    '- 把 `state` 当成必填项，防止回调串改。',
    '- 生产环境固定使用 HTTPS，并确认 `issuer`、JWKS 与回调域名都对外可访问。',
    '- 应用侧最好在服务端完成授权码换令牌，不要让浏览器直接持久化长生命周期 refresh token。',
    '- 如果使用 Flutter SDK，推荐配置为服务端交接模式：机密客户端使用 HTTPS 回调，secret 只放接入方服务器；只有 Public 直连模式才使用自定义 scheme。',
    '',
    '## 7. 管理员检查清单',
    '',
    '- 确认上方展示的 `Issuer` 与实际公网域名一致。',
    '- 确认 `JWT Issuer` 与 `Issuer` 保持一致，避免第三方校验失败。',
    '- 确认客户端登记的 `Redirect URI` 没有拼写错误。',
    '- 确认接入方知道当前 `token` 端点使用 JSON body。',
    '- 确认接入方已按当前 TTL 设计自己的会话续期逻辑。',
    '',
  ].join('\n');

  async function copyDocsAsMarkdown() {
    if (copying) return;
    setCopying(true);
    try {
      await navigator.clipboard.writeText(docsMarkdown);
    } catch {
      const textarea = document.createElement('textarea');
      textarea.value = docsMarkdown;
      textarea.setAttribute('readonly', 'true');
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
    } finally {
      setCopying(false);
    }
  }

  return (
    <div className="min-h-dvh bg-sage-50 p-4 sm:p-6 lg:p-10">
      <div className="mx-auto max-w-5xl space-y-8">
      <SectionHeader
        title="OIDC 接入文档"
        description="面向接入方的完整中文说明，包含协议概念、当前实现、典型配置与最佳实践。管理员登录后即可直接查看生效参数，无需再翻服务器文件。"
        actions={(
          <>
            <button type="button" className="btn-secondary" onClick={() => void copyDocsAsMarkdown()} disabled={copying}>
              {copying ? '复制中...' : '复制为 MD'}
            </button>
            <Link to="/admin/oidc/docs/flutter-sdk" className="btn-primary">
              Flutter SDK 接入
            </Link>
          </>
        )}
      />

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">当前生效参数</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">以下内容来自当前后台已鉴权读取到的运行配置，可直接提供给接入方使用。</p>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <InfoRow label="Issuer" value={issuer} />
          <InfoRow label="授权端点" value={authorizationEndpoint} />
          <InfoRow label="Token 端点" value={tokenEndpoint} />
          <InfoRow label="UserInfo 端点" value={userinfoEndpoint} />
          <InfoRow label="JWKS" value={jwksUri} />
          <InfoRow label="Introspect" value={introspectionEndpoint} />
          <InfoRow label="Revoke" value={revocationEndpoint} />
          <InfoRow label="PKCE 要求" value={oidcSettings?.pkce_required ? '必须使用 S256' : '当前未强制'} />
          <InfoRow label="Access Token TTL" value={accessTokenTtl ? `${accessTokenTtl} 秒` : ''} />
          <InfoRow label="Refresh Token TTL" value={refreshTokenTtl ? `${refreshTokenTtl} 秒` : ''} />
          <InfoRow label="JWT Issuer" value={oidcSettings?.jwt_issuer || ''} />
          <InfoRow label="JWT Audience" value={oidcSettings?.jwt_audience || ''} />
        </div>
      </div>

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">1. 什么是 OIDC</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">OIDC 是建立在 OAuth 2.0 之上的身份层协议。OAuth 2.0 解决“授权访问资源”，OIDC 进一步解决“确认用户是谁”。典型流程是应用把用户带到身份提供方登录，身份提供方确认身份后返回授权码，应用再用授权码换取令牌并读取用户资料。</p>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">在接入实践里，最常见的是授权码模式配合 PKCE。这样前端负责引导用户跳转和回调，后端负责用授权码换令牌、验证令牌并建立本地会话。</p>
        </div>

        <div>
          <h3 className="text-lg font-bold text-sage-900">2. 当前服务支持范围</h3>
          <div className="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2">
            <InfoRow label="已支持" value="Discovery、authorization_code、refresh_token、userinfo、jwks、introspect、revoke、PKCE S256、RS256" />
            <InfoRow label="id_token" value="当 scope 包含 openid 时，token 端点会返回 id_token。" />
            <InfoRow label="当前差异" value="token/introspect/revoke 目前使用 JSON body。" />
          </div>
        </div>

        <div>
          <h3 className="text-lg font-bold text-sage-900">3. 典型客户端配置</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">推荐优先使用机密客户端，后端持有 <InlineCode>client_secret</InlineCode>，前端不要直接暴露。默认 scope 建议使用 <InlineCode>openid profile email phone</InlineCode>，grant type 建议启用 <InlineCode>authorization_code</InlineCode> 和 <InlineCode>refresh_token</InlineCode>。</p>
          <div className="mt-3 space-y-3 text-sm leading-7 text-sage-600">
            <p><InlineCode>Client ID</InlineCode>：应用唯一标识，例如 <InlineCode>my-web-app</InlineCode></p>
            <p><InlineCode>Redirect URI</InlineCode>：必须精确登记回调地址，不能只配域名</p>
            <p><InlineCode>Scopes</InlineCode>：建议至少包含 <InlineCode>openid</InlineCode>，如需邮箱、手机号和昵称则补 <InlineCode>email</InlineCode>、<InlineCode>phone</InlineCode>、<InlineCode>profile</InlineCode></p>
            <p><InlineCode>可用 Scopes</InlineCode>：<InlineCode>openid</InlineCode>、<InlineCode>profile</InlineCode>、<InlineCode>email</InlineCode>、<InlineCode>phone</InlineCode>、<InlineCode>accountRule</InlineCode></p>
            <p><InlineCode>Nonce</InlineCode>：当 scope 包含 <InlineCode>openid</InlineCode> 时必须传，否则授权端点会拒绝请求（400）</p>
            <p><InlineCode>Grant Types</InlineCode>：常规 Web 应用建议开启授权码与刷新令牌</p>
            <p><InlineCode>Confidential</InlineCode>：服务端应用建议开启；纯前端公共客户端才考虑关闭</p>
          </div>
        </div>

        <div>
          <h3 className="text-lg font-bold text-sage-900">4. Flutter SDK 原生接入</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">Flutter 应用建议使用 ROSM Passport Flutter SDK，以原生页面完成登录、授权确认、token 交换、刷新和登出，不需要跳转到 Web 登录页。</p>
          <div className="mt-4 flex flex-wrap gap-3">
            <a className="btn-secondary" href={FLUTTER_SDK_GITHUB_URL} target="_blank" rel="noreferrer">
              查看 SDK
            </a>
            <Link to="/admin/oidc/docs/flutter-sdk" className="btn-primary">
              打开 Flutter SDK 接入页面
            </Link>
          </div>
        </div>

        <div>
          <h3 className="text-lg font-bold text-sage-900">5. Web / 服务端接入步骤</h3>
          <div className="mt-3 space-y-5 text-sm leading-7 text-sage-600">
            <div>
              <p className="font-bold text-sage-800">步骤一：读取 Discovery</p>
              <CodeBlock>{`GET ${issuer}/.well-known/openid-configuration`}</CodeBlock>
            </div>
            <div>
              <p className="font-bold text-sage-800">步骤二：浏览器跳转到授权端点</p>
              <CodeBlock>{`${authorizationEndpoint}?response_type=code&client_id=my-web-app&redirect_uri=${encodeURIComponent('https://app.example.com/callback')}&scope=openid%20profile%20email%20phone&state=random_state&nonce=random_nonce&code_challenge=BASE64URL_SHA256&code_challenge_method=S256`}</CodeBlock>
            </div>
            <div>
              <p className="font-bold text-sage-800">步骤三：后端交换令牌</p>
              <CodeBlock>{`POST ${tokenEndpoint}
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "AUTH_CODE",
  "client_id": "my-web-app",
  "client_secret": "YOUR_CLIENT_SECRET",
  "redirect_uri": "https://app.example.com/callback",
  "code_verifier": "ORIGINAL_CODE_VERIFIER"
}`}</CodeBlock>
            </div>
            <div>
              <p className="font-bold text-sage-800">步骤四：读取用户信息</p>
              <CodeBlock>{`GET ${userinfoEndpoint}
Authorization: Bearer ACCESS_TOKEN`}</CodeBlock>
            </div>
          </div>
        </div>

        <div>
          <h3 className="text-lg font-bold text-sage-900">6. 最佳实践</h3>
          <div className="mt-3 space-y-2 text-sm leading-7 text-sage-600">
            <p>始终启用 PKCE，且使用 <InlineCode>S256</InlineCode>。</p>
            <p>当 <InlineCode>scope</InlineCode> 包含 <InlineCode>openid</InlineCode> 时务必携带 <InlineCode>nonce</InlineCode>，否则授权端点会拒绝请求。</p>
            <p>如果应用需要识别账号角色（例如 <InlineCode>admin</InlineCode>/<InlineCode>user</InlineCode>），请申请 <InlineCode>accountRule</InlineCode> scope。</p>
            <p>机密客户端只把 <InlineCode>client_secret</InlineCode> 放在服务端，前端不要持有。</p>
            <p>回调地址要精确登记到完整路径，避免使用宽泛匹配。</p>
            <p>把 <InlineCode>state</InlineCode> 当成必填项，防止回调串改。</p>
            <p>生产环境固定使用 HTTPS，并确认 <InlineCode>issuer</InlineCode>、JWKS 与回调域名都对外可访问。</p>
            <p>应用侧最好在服务端完成授权码换令牌，不要让浏览器直接持久化长生命周期 refresh token。</p>
            <p>如果使用 Flutter SDK，推荐使用服务端交接模式：机密客户端使用 HTTPS 回调，<InlineCode>client_secret</InlineCode> 只放接入方服务器；只有 Public 直连模式才使用自定义 scheme。</p>
          </div>
        </div>

        <div>
          <h3 className="text-lg font-bold text-sage-900">7. 管理员检查清单</h3>
          <div className="mt-3 space-y-2 text-sm leading-7 text-sage-600">
            <p>确认上方展示的 <InlineCode>Issuer</InlineCode> 与实际公网域名一致。</p>
            <p>确认 <InlineCode>JWT Issuer</InlineCode> 与 <InlineCode>Issuer</InlineCode> 保持一致，避免第三方校验失败。</p>
            <p>确认客户端登记的 <InlineCode>Redirect URI</InlineCode> 没有拼写错误。</p>
            <p>确认接入方知道当前 <InlineCode>token</InlineCode> 端点使用 JSON body。</p>
            <p>确认接入方已按当前 TTL 设计自己的会话续期逻辑。</p>
          </div>
        </div>
      </div>
    </div>
    </div>
  );
}

export function AdminFlutterSdkDocsPage({ discovery, oidcSettings }) {
  const issuer = oidcSettings?.issuer || discovery?.issuer || 'https://auth.example.com';
  const webAuthnOrigin = typeof window === 'undefined' ? 'https://auth.example.com' : window.location.origin;
  const tokenEndpoint = oidcSettings?.token_endpoint || discovery?.token_endpoint || `${issuer}/oidc/token`;
  const userinfoEndpoint = oidcSettings?.userinfo_endpoint || discovery?.userinfo_endpoint || `${issuer}/oidc/userinfo`;
  const revocationEndpoint = oidcSettings?.revocation_endpoint || discovery?.revocation_endpoint || `${issuer}/oidc/revoke`;
  const nativeStartEndpoint = `${issuer}/api/v1/oidc/native/start`;
  const nativeApproveEndpoint = `${issuer}/api/v1/oidc/native/approve`;

  return (
    <div className="min-h-dvh bg-sage-50 p-4 sm:p-6 lg:p-10">
      <div className="mx-auto max-w-5xl space-y-8">
      <SectionHeader
        title="Flutter SDK 接入"
        description="面向移动端应用的原生接入说明。SDK 内置 Rosemary 风格登录 UI，应用侧使用 Dart 类和方法完成登录授权，JSON 请求由 SDK 内部处理。"
        actions={(
          <>
            <Link to="/admin/oidc/docs" className="btn-secondary">
              返回 OIDC 文档
            </Link>
            <a className="btn-primary" href={FLUTTER_SDK_GITHUB_URL} target="_blank" rel="noreferrer">
              GitHub SDK
            </a>
          </>
        )}
      />

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">1. 选择客户端模式</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">推荐生产应用使用“服务端交接”模式：Flutter SDK 在 App 内完成 Rosemary 风格登录 UI 和授权确认，但 <InlineCode>client_secret</InlineCode> 仍只放在接入方自己的服务器。SDK 获取一次性授权码后，把授权码和 PKCE verifier 交给接入方服务器，由服务器作为机密客户端换取 token 并创建业务会话。</p>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <InfoRow label="Client ID" value="com.cruos.zion" />
          <InfoRow label="Display Name" value="展示给用户看的应用名" />
          <InfoRow label="推荐 Redirect URI" value="https://api.example.com/auth/rosm/callback" />
          <InfoRow label="备用 App URI" value="com.cruos.zion:/oidc/callback" />
          <InfoRow label="Scopes" value="openid profile email phone accountRule" />
          <InfoRow label="Grant Types" value="authorization_code, refresh_token" />
          <InfoRow label="Confidential" value="服务端交接模式开启；Public 直连模式关闭" />
        </div>
        <CodeBlock>{`推荐：服务端交接 / Confidential
Client ID: com.cruos.zion
Redirect URI: https://api.example.com/auth/rosm/callback
Confidential: true
Client Secret: 只保存在 api.example.com 服务器
SDK serverHandoff: true

备用：Public 直连
Client ID: com.cruos.zion
Redirect URI: com.cruos.zion:/oidc/callback
Confidential: false
Client Secret: 留空
Grant Types:
  authorization_code
  refresh_token
Scopes:
  openid
  profile
  email
  phone
  accountRule`}</CodeBlock>
      </div>

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">2. 添加 SDK 依赖</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">SDK 放在当前 GitHub 仓库中，应用可以直接通过 git 依赖接入。</p>
        </div>
        <CodeBlock>{`dependencies:
  rosm_passport_flutter:
    git:
      url: https://github.com/Foodie05/rosemary_passport.git
      path: packages/rosm_passport_flutter`}</CodeBlock>
      </div>

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">3. 使用 SDK 内置 UI</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">SDK 内置 Rosemary 风格登录页。应用侧只配置 Dart 类和回调；验证码、手机、密码、密码二次验证、注册、忘记密码、通行密钥登录、授权确认、native approve 和服务端交接都由 SDK 串起来。</p>
        </div>
        <CodeBlock>{`final passport = RosmPassportClient(
  issuer: Uri.parse('${issuer}'),
  clientId: 'com.cruos.zion',
  redirectUri: Uri.parse('https://api.example.com/auth/rosm/callback'),
  scopes: const {'openid', 'profile', 'email', 'phone', 'accountRule'},
  webAuthnOrigin: Uri.parse('${webAuthnOrigin}'),
);

final result = await showRosmPassportSignIn(
  context,
  client: passport,
  config: RosmPassportSignInConfig(
    serverHandoffEndpoint: Uri.parse(
      'https://api.example.com/auth/rosm/sdk/complete',
    ),
    requestCaptchaToken: () => yourCaptchaProvider(),
    enableRegistration: true,
    authenticatePasskey: (options) async {
      final response = await passkeyPlugin.authenticate(options.options);
      return RosmWebAuthnCredential(response);
    },
  ),
);

final appSession = result?.serverPayload;`}</CodeBlock>
        <p className="text-sm leading-relaxed text-sage-600">
          注册功能默认开启，用户可在内置 UI 中使用邮箱验证码创建 ROSM 账号，然后进入同一套授权确认和服务端交接流程。注册发码需要
          <InlineCode>requestCaptchaToken</InlineCode>
          返回有效人机验证 token；不希望开放注册的应用可以设置
          <InlineCode>enableRegistration: false</InlineCode>
          。
        </p>
      </div>

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">4. 接入方服务器完成换票</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">服务端交接接口由接入方实现。SDK 会把授权码、PKCE verifier、state、nonce 和 redirect URI 发给该接口；接入方服务器再带自己的 <InlineCode>client_secret</InlineCode> 调用 ROSM token 端点，校验 ID Token 后创建自己的 App 会话。</p>
        </div>
        <CodeBlock>{`POST https://api.example.com/auth/rosm/sdk/complete
Content-Type: application/json

{
  "issuer": "${issuer}",
  "client_id": "com.cruos.zion",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "code": "AUTHORIZATION_CODE",
  "state": "STATE",
  "code_verifier": "ORIGINAL_PKCE_VERIFIER",
  "scope": "openid profile email phone accountRule",
  "nonce": "NONCE"
}

// 接入方服务器随后调用：
POST ${tokenEndpoint}
{
  "grant_type": "authorization_code",
  "code": "AUTHORIZATION_CODE",
  "client_id": "com.cruos.zion",
  "client_secret": "SERVER_ONLY_SECRET",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "code_verifier": "ORIGINAL_PKCE_VERIFIER"
}`}</CodeBlock>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <InfoRow label="SDK 返回" value="RosmPassportUiResult.serverPayload，内容由接入方服务器决定" />
          <InfoRow label="ROSM Token" value="只在接入方服务器换取和校验" />
          <InfoRow label="安全校验" value="校验 state、nonce、issuer、aud、过期时间与回调 URI" />
          <InfoRow label="业务会话" value="由接入方服务器签发自己的 App session" />
        </div>
        <div className="rounded-2xl border border-sage-100 bg-sage-50/70 p-5">
          <p className="text-sm font-bold text-sage-900">接入方服务器必须实现的契约</p>
          <div className="mt-3 space-y-2 text-sm leading-7 text-sage-600">
            <p><InlineCode>serverHandoffEndpoint</InlineCode> 不是传统浏览器 OIDC callback。传统 callback 接收 query 里的 <InlineCode>code/state</InlineCode>；SDK complete endpoint 接收 App 发来的 JSON POST。</p>
            <p>建议提供 <InlineCode>POST /auth/rosm/sdk/start</InlineCode> 创建登录 challenge，返回 <InlineCode>state</InlineCode>、<InlineCode>nonce</InlineCode>、<InlineCode>client_id</InlineCode>、<InlineCode>redirect_uri</InlineCode>、<InlineCode>scope</InlineCode> 和 complete endpoint。</p>
            <p><InlineCode>POST /auth/rosm/sdk/complete</InlineCode> 必须校验 challenge 未过期、未消费、与当前设备/会话绑定，并校验 <InlineCode>issuer</InlineCode>、<InlineCode>client_id</InlineCode>、<InlineCode>redirect_uri</InlineCode>、<InlineCode>scope</InlineCode>、<InlineCode>state</InlineCode>、<InlineCode>nonce</InlineCode> 都匹配。</p>
            <p>服务器用 <InlineCode>code</InlineCode>、<InlineCode>code_verifier</InlineCode>、<InlineCode>client_secret</InlineCode> 调用 ROSM token 端点；随后用 JWKS 校验 ID Token 签名和 <InlineCode>iss</InlineCode>、<InlineCode>aud</InlineCode>、<InlineCode>exp</InlineCode>、<InlineCode>iat</InlineCode>、<InlineCode>nonce</InlineCode>。</p>
            <p>授权码和 challenge 都按一次性使用处理。完成后由接入方服务器签发自己的 App session；不要把 <InlineCode>client_secret</InlineCode> 返回给 App，通常也不要把 ROSM refresh token 下发到 App。</p>
          </div>
        </div>
        <CodeBlock>{`// 建议的 start 响应，由接入方服务器生成并保存 challenge
{
  "client_id": "com.cruos.zion",
  "redirect_uri": "https://api.example.com/auth/rosm/callback",
  "scope": "openid profile email phone accountRule",
  "state": "SERVER_GENERATED_STATE",
  "nonce": "SERVER_GENERATED_NONCE",
  "handoff_endpoint": "https://api.example.com/auth/rosm/sdk/complete"
}

// complete 成功后返回给 SDK 的业务会话示例
{
  "session_token": "APP_SESSION_TOKEN",
  "user": {
    "id": "app-user-id",
    "nickname": "Rosemary"
  }
}`}</CodeBlock>
      </div>

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">5. 忘记密码</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">应用侧先完成人机验证，再调用 SDK 发送找回验证码。邮箱找回和手机找回都使用同一组 Dart 方法，通过 RosmPasswordRecoveryMethod 区分。</p>
        </div>
        <CodeBlock>{`await passport.sendPasswordRecoveryCode(
  account: 'user@example.com',
  method: RosmPasswordRecoveryMethod.email,
  captchaToken: captchaToken,
);

await passport.resetPasswordByCode(
  account: 'user@example.com',
  method: RosmPasswordRecoveryMethod.email,
  code: '123456',
  newPassword: newPassword,
);`}</CodeBlock>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <InfoRow label="邮箱找回" value="account 填邮箱，method 使用 email" />
          <InfoRow label="手机找回" value="account 填手机号，method 使用 phone" />
        </div>
      </div>

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">6. 通行密钥登录与添加</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">SDK 默认内置原生通行密钥适配，会获取 WebAuthn options、调起系统通行密钥弹窗，并把 credential response 交回 ROSM 验证。接入方通常不需要手写 WebAuthn JSON 或额外接 passkey 插件。</p>
        </div>
        <CodeBlock>{`final loginOptions = await passport.beginWebAuthnLogin(
  email: 'user@example.com',
);

final loginCredential = await authenticateRosmPasskey(loginOptions);

final session = await passport.completeWebAuthnLogin(
  email: 'user@example.com',
  credential: loginCredential,
);

final registerOptions = await passport.beginPasskeyRegistration(
  currentPassword: currentPassword,
);

final registerCredential = await registerRosmPasskey(registerOptions);

await passport.completePasskeyRegistration(
  credential: registerCredential,
);`}</CodeBlock>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <InfoRow label="登录" value="beginWebAuthnLogin + completeWebAuthnLogin" />
          <InfoRow label="添加" value="beginPasskeyRegistration + completePasskeyRegistration" />
          <InfoRow label="注册后引导" value="postRegisterPasskeyBootstrap 为 true 时可免当前密码添加" />
          <InfoRow label="管理" value="listPasskeys 与 deletePasskey" />
        </div>
      </div>

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">7. 通行密钥平台配置</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">Passkey 必须绑定 HTTPS relying party 域名。移动端需要完成系统级域名关联，并让 SDK 请求 options 时携带同一个 Origin。iOS 报 “Application with identifier ... is not associated with domain ...” 时，优先检查 App ID、entitlement 与 AASA 是否完全一致并已部署生效。</p>
        </div>
        <CodeBlock>{`const passkeyConfig = RosmPasskeyPlatformConfig(
  rpDomain: 'auth.cruty.cn',
  appleTeamId: 'Y6AYA4F7T3',
  appleBundleId: 'com.cruos.zion',
  androidPackageName: 'com.cruos.zion',
  androidSha256CertFingerprints: ['AA:BB:CC:...'],
);

final iosEntitlement = passkeyConfig.appleAssociatedDomain;
final aasa = passkeyConfig.appleAppSiteAssociation(
  includeUniversalLinks: true,
);
final assetLinks = passkeyConfig.androidAssetLinks();
final assetStatement = passkeyConfig.androidAssetStatementsInclude();`}</CodeBlock>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <InfoRow label="iOS/macOS" value="配置 Associated Domains，例如 webcredentials:auth.cruty.cn；AASA 的 webcredentials.apps 必须包含 TeamID.BundleID" />
          <InfoRow label="Android" value="assetlinks.json 必须 200、无跳转、application/json，并声明包名与所有 SHA-256 签名证书指纹" />
          <InfoRow label="SDK Origin" value={`webAuthnOrigin 使用服务端 WebAuthn RP 对应的 HTTPS origin，例如 ${webAuthnOrigin}`} />
          <InfoRow label="服务端域名" value="issuer、RP ID、平台关联文件必须指向同一登录域名边界" />
        </div>
      </div>

      <div className="glass-card space-y-6 rounded-3xl p-5 sm:p-8">
        <div>
          <h3 className="text-lg font-bold text-sage-900">8. Public 直连模式与端点</h3>
          <p className="mt-2 text-sm leading-relaxed text-sage-600">如果应用明确不经过自己的服务器，可以把 OIDC client 配成 Public，并使用自定义 scheme redirect URI。此时 SDK 会在设备上换取和保存 ROSM token；生产业务 App 更推荐上面的服务端交接模式。</p>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <InfoRow label="Native Start" value={nativeStartEndpoint} />
          <InfoRow label="Native Approve" value={nativeApproveEndpoint} />
          <InfoRow label="Token" value={tokenEndpoint} />
          <InfoRow label="UserInfo" value={userinfoEndpoint} />
          <InfoRow label="Revoke" value={revocationEndpoint} />
          <InfoRow label="SDK" value={FLUTTER_SDK_GITHUB_URL} />
        </div>
        <CodeBlock>{`final passport = RosmPassportClient(
  issuer: Uri.parse('${issuer}'),
  clientId: 'com.cruos.zion',
  redirectUri: Uri.parse('com.cruos.zion:/oidc/callback'),
);

final result = await showRosmPassportSignIn(context, client: passport);
final tokens = result?.tokens;

final refreshed = await passport.refresh();
final userInfo = await passport.userInfo();
await passport.signOut();`}</CodeBlock>
      </div>

      <div className="glass-card space-y-4 rounded-3xl p-5 sm:p-8">
        <h3 className="text-lg font-bold text-sage-900">9. 检查清单</h3>
        <div className="space-y-2 text-sm leading-7 text-sage-600">
          <p>生产推荐使用服务端交接：Flutter SDK 设置 <InlineCode>serverHandoff</InlineCode>，接入方服务器保存 <InlineCode>client_secret</InlineCode> 并完成 token exchange。</p>
          <p>机密客户端的 <InlineCode>Redirect URI</InlineCode> 必须是接入方服务器 HTTPS 回调，不能是移动端自定义 scheme。</p>
          <p>只有 Public 直连模式才使用自定义 scheme，例如 <InlineCode>com.cruos.zion:/oidc/callback</InlineCode>。</p>
          <p>接入方服务器必须校验 <InlineCode>state</InlineCode>、<InlineCode>nonce</InlineCode>、<InlineCode>issuer</InlineCode>、<InlineCode>aud</InlineCode>、过期时间和 redirect URI。</p>
          <p><InlineCode>scope</InlineCode> 包含 <InlineCode>openid</InlineCode> 时 SDK 会携带 <InlineCode>nonce</InlineCode>。</p>
          <p>使用通行密钥时，iOS Associated Domains、Android Digital Asset Links 与 <InlineCode>webAuthnOrigin</InlineCode> 必须指向同一个 HTTPS 登录域名边界。</p>
          <p>忘记密码需要应用侧先完成人机验证，并把 captcha token 交给 <InlineCode>sendPasswordRecoveryCode</InlineCode>。</p>
          <p>生产环境确认 <InlineCode>issuer</InlineCode> 是 HTTPS 公网地址，并且 native bridge、token、userinfo 端点都能访问。</p>
          <p>应用升级或更换 bundle id / package name 时，同步检查自定义 scheme 与回调配置。</p>
        </div>
      </div>
    </div>
    </div>
  );
}
