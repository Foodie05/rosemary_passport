import React from 'react';
import { motion } from 'motion/react';
import { 
  Users, 
  Mail, 
  ShieldCheck, 
  Shield,
  Key, 
  ArrowUpRight, 
  ArrowDownRight,
  Activity,
  Clock,
  MoreHorizontal,
  Plus,
  Search,
  Filter,
  Trash2,
  Edit,
  CheckCircle2,
  XCircle,
  Globe,
  Lock,
  Server
} from 'lucide-react';
import { cn } from '@/src/lib/utils';

// --- Dashboard Overview ---

const StatCard = ({ title, value, change, trend, icon: Icon }: any) => (
  <motion.div 
    whileHover={{ y: -4 }}
    className="glass-card p-6 rounded-2xl"
  >
    <div className="flex justify-between items-start mb-4">
      <div className="p-3 bg-sage-100 text-sage-600 rounded-xl">
        <Icon size={24} />
      </div>
      <div className={cn(
        "flex items-center gap-1 text-xs font-bold px-2 py-1 rounded-full",
        trend === 'up' ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700"
      )}>
        {trend === 'up' ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
        {change}
      </div>
    </div>
    <h3 className="text-sage-500 text-sm font-medium">{title}</h3>
    <p className="text-2xl font-bold text-sage-900 mt-1">{value}</p>
  </motion.div>
);

export const AdminOverview = () => {
  return (
    <div className="space-y-8">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-sage-900">系统概览</h2>
          <p className="text-sage-500 mt-1">欢迎回来，这是您今天的系统运行状况。</p>
        </div>
        <div className="flex gap-3">
          <button className="btn-secondary flex items-center gap-2">
            <Clock size={18} />
            查看日志
          </button>
          <button className="btn-primary flex items-center gap-2">
            <Plus size={18} />
            添加应用
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard title="总用户数" value="12,842" change="+12.5%" trend="up" icon={Users} />
        <StatCard title="活跃会话" value="1,204" change="+5.2%" trend="up" icon={Activity} />
        <StatCard title="认证请求" value="45.2k" change="-2.1%" trend="down" icon={ShieldCheck} />
        <StatCard title="系统负载" value="24%" change="稳定" trend="up" icon={Server} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-6">
          <div className="glass-card rounded-2xl overflow-hidden">
            <div className="p-6 border-b border-sage-100 flex justify-between items-center">
              <h3 className="font-bold text-sage-900">最近用户活动</h3>
              <button className="text-sage-500 hover:text-sage-700"><MoreHorizontal size={20} /></button>
            </div>
            <div className="divide-y divide-sage-50">
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="p-4 flex items-center justify-between hover:bg-sage-50/50 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-sage-200 overflow-hidden">
                      <img src={`https://api.dicebear.com/7.x/avataaars/svg?seed=user${i}`} alt="avatar" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-sage-900">用户_{i * 123}</p>
                      <p className="text-xs text-sage-500">登录了应用: ROSM Blog</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-sage-400">2 分钟前</p>
                    <p className="text-xs font-medium text-green-600">成功</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="space-y-6">
          <div className="glass-card p-6 rounded-2xl">
            <h3 className="font-bold text-sage-900 mb-4">系统状态</h3>
            <div className="space-y-4">
              {[
                { name: '认证网关', status: '正常', color: 'text-green-600' },
                { name: '数据库集群', status: '正常', color: 'text-green-600' },
                { name: '邮件服务器', status: '延迟', color: 'text-amber-600' },
                { name: 'hCaptcha API', status: '正常', color: 'text-green-600' },
              ].map((item) => (
                <div key={item.name} className="flex items-center justify-between">
                  <span className="text-sm text-sage-600">{item.name}</span>
                  <div className="flex items-center gap-2">
                    <div className={cn("w-2 h-2 rounded-full", item.color.replace('text', 'bg'))}></div>
                    <span className={cn("text-xs font-bold", item.color)}>{item.status}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-sage-900 text-white p-6 rounded-2xl shadow-xl shadow-sage-900/20 relative overflow-hidden">
            <div className="relative z-10">
              <h3 className="font-bold mb-2">安全提醒</h3>
              <p className="text-sage-300 text-sm leading-relaxed">
                系统检测到 3 个未配置双因素认证的管理账号，建议立即处理以增强安全性。
              </p>
              <button className="mt-4 text-xs font-bold bg-white/10 hover:bg-white/20 px-4 py-2 rounded-lg transition-all">
                立即处理
              </button>
            </div>
            <Shield className="absolute -right-4 -bottom-4 text-white/5 w-32 h-32" />
          </div>
        </div>
      </div>
    </div>
  );
};

// --- User Management ---

export const AdminUsers = () => {
  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <h2 className="text-2xl font-bold text-sage-900">用户管理</h2>
        <button className="btn-primary flex items-center gap-2">
          <Plus size={18} />
          邀请新用户
        </button>
      </div>

      <div className="glass-card rounded-2xl p-4 flex flex-wrap gap-4 items-center">
        <div className="flex-1 min-w-[240px] relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-sage-400" size={18} />
          <input 
            type="text" 
            placeholder="搜索用户名、邮箱或UID..." 
            className="input-field pl-10 py-2"
          />
        </div>
        <button className="btn-secondary py-2 flex items-center gap-2">
          <Filter size={18} />
          筛选
        </button>
      </div>

      <div className="glass-card rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-sage-50/50 border-b border-sage-100">
                <th className="px-6 py-4 text-xs font-bold text-sage-500 uppercase tracking-wider">用户</th>
                <th className="px-6 py-4 text-xs font-bold text-sage-500 uppercase tracking-wider">状态</th>
                <th className="px-6 py-4 text-xs font-bold text-sage-500 uppercase tracking-wider">角色</th>
                <th className="px-6 py-4 text-xs font-bold text-sage-500 uppercase tracking-wider">最后登录</th>
                <th className="px-6 py-4 text-xs font-bold text-sage-500 uppercase tracking-wider text-right">操作</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-sage-50">
              {[
                { name: '迷迭香草', email: 'rosemary@example.com', status: '活跃', role: '管理员', last: '10分钟前' },
                { name: '薄荷苏打', email: 'mint@example.com', status: '活跃', role: '用户', last: '2小时前' },
                { name: '薰衣草田', email: 'lavender@example.com', status: '待验证', role: '用户', last: '-' },
                { name: '百里香', email: 'thyme@example.com', status: '已禁用', role: '用户', last: '3天前' },
              ].map((user, i) => (
                <tr key={i} className="hover:bg-sage-50/30 transition-colors group">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-sage-200 overflow-hidden">
                        <img src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${user.name}`} alt="avatar" />
                      </div>
                      <div>
                        <p className="text-sm font-semibold text-sage-900">{user.name}</p>
                        <p className="text-xs text-sage-400">{user.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={cn(
                      "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide",
                      user.status === '活跃' ? "bg-green-100 text-green-700" : 
                      user.status === '待验证' ? "bg-amber-100 text-amber-700" : "bg-red-100 text-red-700"
                    )}>
                      {user.status}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <span className="text-sm text-sage-600">{user.role}</span>
                  </td>
                  <td className="px-6 py-4">
                    <span className="text-sm text-sage-400">{user.last}</span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <div className="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button className="p-2 text-sage-400 hover:text-sage-600 hover:bg-sage-100 rounded-lg transition-all">
                        <Edit size={16} />
                      </button>
                      <button className="p-2 text-sage-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all">
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="p-4 border-t border-sage-100 flex items-center justify-between text-sm text-sage-500">
          <p>显示 1-4 / 1,284 位用户</p>
          <div className="flex gap-2">
            <button className="px-3 py-1 border border-sage-200 rounded-lg hover:bg-sage-50 disabled:opacity-50" disabled>上一页</button>
            <button className="px-3 py-1 border border-sage-200 rounded-lg hover:bg-sage-50">下一页</button>
          </div>
        </div>
      </div>
    </div>
  );
};

// --- Configuration Pages ---

export const AdminConfigPage = ({ title, description, icon: Icon, children }: any) => (
  <div className="space-y-8 max-w-4xl">
    <div className="flex items-center gap-4">
      <div className="p-4 bg-sage-600 text-white rounded-2xl shadow-lg shadow-sage-600/20">
        <Icon size={32} />
      </div>
      <div>
        <h2 className="text-2xl font-bold text-sage-900">{title}</h2>
        <p className="text-sage-500 mt-1">{description}</p>
      </div>
    </div>

    <div className="glass-card rounded-3xl p-8 space-y-8">
      {children}
      
      <div className="pt-6 border-t border-sage-100 flex justify-end gap-4">
        <button className="btn-secondary">重置</button>
        <button className="btn-primary">保存配置</button>
      </div>
    </div>
  </div>
);

export const AdminEmailConfig = () => (
  <AdminConfigPage 
    title="邮件系统配置" 
    description="配置用于发送验证邮件、重置密码和系统通知的 SMTP 服务。"
    icon={Mail}
  >
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">SMTP 服务器</label>
        <input type="text" className="input-field" placeholder="smtp.example.com" />
      </div>
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">端口</label>
        <input type="number" className="input-field" placeholder="465" />
      </div>
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">发件人邮箱</label>
        <input type="email" className="input-field" placeholder="noreply@rosm.pass" />
      </div>
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">发件人名称</label>
        <input type="text" className="input-field" placeholder="ROSM Pass" />
      </div>
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">用户名</label>
        <input type="text" className="input-field" />
      </div>
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">密码</label>
        <input type="password" className="input-field" placeholder="••••••••••••" />
      </div>
    </div>
    <div className="flex items-center gap-3 p-4 bg-sage-50 rounded-2xl border border-sage-100">
      <div className="p-2 bg-white rounded-lg text-sage-400">
        <Lock size={18} />
      </div>
      <p className="text-xs text-sage-500 leading-relaxed">
        建议使用 SSL/TLS 加密连接。如果您的服务商支持，请优先使用专用 App Password 而非主账号密码。
      </p>
    </div>
  </AdminConfigPage>
);

export const AdminHCaptchaConfig = () => (
  <AdminConfigPage 
    title="hCaptcha 配置" 
    description="通过人机验证保护您的登录和注册页面免受机器人攻击。"
    icon={ShieldCheck}
  >
    <div className="space-y-6">
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">Site Key</label>
        <input type="text" className="input-field" placeholder="10000000-ffff-ffff-ffff-000000000001" />
      </div>
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">Secret Key</label>
        <input type="password" className="input-field" placeholder="0x0000000000000000000000000000000000000000" />
      </div>
      <div className="flex items-center gap-4 py-2">
        <div className="flex items-center gap-2">
          <input type="checkbox" id="enable-login" className="w-4 h-4 rounded text-sage-600 focus:ring-sage-400" defaultChecked />
          <label htmlFor="enable-login" className="text-sm text-sage-600">在登录页启用</label>
        </div>
        <div className="flex items-center gap-2">
          <input type="checkbox" id="enable-reg" className="w-4 h-4 rounded text-sage-600 focus:ring-sage-400" defaultChecked />
          <label htmlFor="enable-reg" className="text-sm text-sage-600">在注册页启用</label>
        </div>
      </div>
    </div>
  </AdminConfigPage>
);

export const AdminOIDCConfig = () => (
  <AdminConfigPage 
    title="OIDC 配置" 
    description="配置 OpenID Connect 服务端参数，允许第三方应用接入认证。"
    icon={Key}
  >
    <div className="space-y-6">
      <div className="space-y-2">
        <label className="text-sm font-bold text-sage-700">Issuer URL</label>
        <div className="flex gap-2">
          <input type="text" className="input-field bg-sage-50" value="https://auth.rosm.pass" readOnly />
          <button className="p-2.5 bg-sage-100 text-sage-600 rounded-xl hover:bg-sage-200 transition-all">
            <Globe size={20} />
          </button>
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-2">
          <label className="text-sm font-bold text-sage-700">JWKS Endpoint</label>
          <input type="text" className="input-field" value="/.well-known/jwks.json" readOnly />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-bold text-sage-700">Token Expiration (秒)</label>
          <input type="number" className="input-field" defaultValue={3600} />
        </div>
      </div>
      <div className="space-y-4">
        <h4 className="text-sm font-bold text-sage-900 border-b border-sage-100 pb-2">支持的 Scopes</h4>
        <div className="flex flex-wrap gap-2">
          {['openid', 'profile', 'email', 'phone', 'address'].map(scope => (
            <span key={scope} className="px-3 py-1 bg-sage-100 text-sage-600 rounded-full text-xs font-bold">
              {scope}
            </span>
          ))}
          <button className="px-3 py-1 border border-dashed border-sage-300 text-sage-400 rounded-full text-xs hover:border-sage-500 hover:text-sage-500 transition-all">
            + 添加
          </button>
        </div>
      </div>
    </div>
  </AdminConfigPage>
);

const providerPattern = /^@[a-z0-9.-]+\.[a-z]{2,}$/i;

const normalizeProvider = (value: string) => {
  const trimmed = value.trim().toLowerCase();
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
};

const RegistrationProviderSection = ({
  title,
  description,
  value,
  inputValue,
  onInputChange,
  onAdd,
  onRemove,
}: any) => (
  <div className="space-y-4 rounded-2xl border border-sage-200 bg-white/70 p-5">
    <div>
      <h3 className="text-base font-bold text-sage-900">{title}</h3>
      <p className="mt-1 text-sm text-sage-500">{description}</p>
    </div>

    <div className="flex flex-col gap-3 sm:flex-row">
      <input
        type="text"
        className="input-field"
        placeholder="@example.com"
        value={inputValue}
        onChange={(event) => onInputChange(event.target.value)}
      />
      <button type="button" className="btn-secondary whitespace-nowrap" onClick={onAdd}>
        添加提供商
      </button>
    </div>

    <div className="flex flex-wrap gap-2">
      {value.length > 0 ? value.map((provider: string) => (
        <span
          key={provider}
          className="inline-flex items-center gap-2 rounded-full border border-sage-200 bg-sage-50 px-3 py-1.5 text-sm font-medium text-sage-700"
        >
          {provider}
          <button
            type="button"
            className="rounded-full text-sage-400 transition-colors hover:text-red-500"
            onClick={() => onRemove(provider)}
            aria-label={`移除 ${provider}`}
          >
            <Trash2 size={14} />
          </button>
        </span>
      )) : (
        <p className="text-sm text-sage-400">当前没有配置任何邮箱提供商。</p>
      )}
    </div>
  </div>
);

export const AdminSecuritySettings = () => {
  const [mode, setMode] = React.useState<'blacklist' | 'whitelist'>('blacklist');
  const [blacklist, setBlacklist] = React.useState<string[]>([]);
  const [whitelist, setWhitelist] = React.useState<string[]>([]);
  const [blacklistInput, setBlacklistInput] = React.useState('');
  const [whitelistInput, setWhitelistInput] = React.useState('');
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [message, setMessage] = React.useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [initialState, setInitialState] = React.useState({
    mode: 'blacklist' as 'blacklist' | 'whitelist',
    blacklist: [] as string[],
    whitelist: [] as string[],
  });

  const loadSettings = React.useCallback(async () => {
    setLoading(true);
    setMessage(null);
    try {
      const response = await fetch('/api/v1/admin/settings');
      if (!response.ok) {
        throw new Error('加载失败');
      }

      const data = await response.json();
      const security = data?.settings?.security ?? {};
      const nextMode =
        security.registration_email_provider_mode === 'whitelist'
          ? 'whitelist'
          : 'blacklist';
      const nextBlacklist = Array.isArray(security.registration_email_provider_blacklist)
        ? security.registration_email_provider_blacklist.map((item: string) => normalizeProvider(String(item))).filter(Boolean)
        : [];
      const nextWhitelist = Array.isArray(security.registration_email_provider_whitelist)
        ? security.registration_email_provider_whitelist.map((item: string) => normalizeProvider(String(item))).filter(Boolean)
        : [];

      setMode(nextMode);
      setBlacklist(nextBlacklist);
      setWhitelist(nextWhitelist);
      setInitialState({
        mode: nextMode,
        blacklist: nextBlacklist,
        whitelist: nextWhitelist,
      });
    } catch {
      setMessage({ type: 'error', text: '安全策略加载失败，请稍后重试。' });
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    void loadSettings();
  }, [loadSettings]);

  const addProvider = (
    rawValue: string,
    currentList: string[],
    setList: React.Dispatch<React.SetStateAction<string[]>>,
    resetInput: () => void,
  ) => {
    const provider = normalizeProvider(rawValue);
    if (!providerPattern.test(provider)) {
      setMessage({ type: 'error', text: '请输入合法的邮箱提供商，例如 @gmail.com。' });
      return;
    }
    if (currentList.includes(provider)) {
      setMessage({ type: 'error', text: `${provider} 已存在于当前名单中。` });
      return;
    }
    setList([...currentList, provider]);
    resetInput();
    setMessage(null);
  };

  const resetToInitial = () => {
    setMode(initialState.mode);
    setBlacklist(initialState.blacklist);
    setWhitelist(initialState.whitelist);
    setBlacklistInput('');
    setWhitelistInput('');
    setMessage(null);
  };

  const saveSettings = async () => {
    setSaving(true);
    setMessage(null);
    try {
      const response = await fetch('/api/v1/admin/settings', {
        method: 'PUT',
        headers: {
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          security: {
            registration_email_provider_mode: mode,
            registration_email_provider_blacklist: blacklist,
            registration_email_provider_whitelist: whitelist,
          },
        }),
      });
      const payload = await response.json().catch(() => null);
      if (!response.ok) {
        throw new Error(payload?.message || '保存失败');
      }

      setInitialState({ mode, blacklist, whitelist });
      setMessage({ type: 'success', text: '注册邮箱管理已保存。' });
    } catch (error: any) {
      setMessage({
        type: 'error',
        text: error?.message || '保存失败，请稍后重试。',
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-8 max-w-5xl">
      <div className="flex items-center gap-4">
        <div className="p-4 bg-sage-600 text-white rounded-2xl shadow-lg shadow-sage-600/20">
          <Shield size={32} />
        </div>
        <div>
          <h2 className="text-2xl font-bold text-sage-900">安全策略</h2>
          <p className="text-sage-500 mt-1">管理注册邮箱提供商黑白名单，并在两种策略间自由切换。</p>
        </div>
      </div>

      <div className="glass-card rounded-3xl p-8 space-y-8">
        <div className="rounded-2xl border border-sage-200 bg-sage-50/80 p-5">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div className="space-y-2">
              <h3 className="text-lg font-bold text-sage-900">注册邮箱管理</h3>
              <p className="text-sm leading-relaxed text-sage-500">
                白名单模式下，仅允许名单中的邮箱提供商注册。黑名单模式下，仅拦截黑名单中的邮箱提供商，白名单数据会被保留，方便随时切换。
              </p>
            </div>
            <div className="inline-flex rounded-2xl border border-sage-200 bg-white p-1">
              <button
                type="button"
                className={cn(
                  'rounded-xl px-4 py-2 text-sm font-bold transition-all',
                  mode === 'blacklist' ? 'bg-sage-600 text-white shadow-sm' : 'text-sage-500 hover:text-sage-700',
                )}
                onClick={() => setMode('blacklist')}
              >
                黑名单模式
              </button>
              <button
                type="button"
                className={cn(
                  'rounded-xl px-4 py-2 text-sm font-bold transition-all',
                  mode === 'whitelist' ? 'bg-sage-600 text-white shadow-sm' : 'text-sage-500 hover:text-sage-700',
                )}
                onClick={() => setMode('whitelist')}
              >
                白名单模式
              </button>
            </div>
          </div>
        </div>

        {message && (
          <div
            className={cn(
              'rounded-2xl border px-4 py-3 text-sm font-medium',
              message.type === 'success'
                ? 'border-green-200 bg-green-50 text-green-700'
                : 'border-red-200 bg-red-50 text-red-700',
            )}
          >
            {message.text}
          </div>
        )}

        {loading ? (
          <div className="rounded-2xl border border-dashed border-sage-200 bg-white/60 p-8 text-center text-sage-400">
            正在加载安全策略...
          </div>
        ) : (
          <>
            <RegistrationProviderSection
              title="黑名单"
              description="这些邮箱提供商在黑名单模式下会被拒绝注册。"
              value={blacklist}
              inputValue={blacklistInput}
              onInputChange={setBlacklistInput}
              onAdd={() => addProvider(blacklistInput, blacklist, setBlacklist, () => setBlacklistInput(''))}
              onRemove={(provider: string) => setBlacklist(blacklist.filter((item) => item !== provider))}
            />

            <RegistrationProviderSection
              title="白名单"
              description="这些邮箱提供商在白名单模式下会被允许注册。"
              value={whitelist}
              inputValue={whitelistInput}
              onInputChange={setWhitelistInput}
              onAdd={() => addProvider(whitelistInput, whitelist, setWhitelist, () => setWhitelistInput(''))}
              onRemove={(provider: string) => setWhitelist(whitelist.filter((item) => item !== provider))}
            />
          </>
        )}
        
        <div className="pt-6 border-t border-sage-100 flex justify-end gap-4">
          <button className="btn-secondary" type="button" onClick={resetToInitial} disabled={loading || saving}>
            重置
          </button>
          <button className="btn-primary" type="button" onClick={saveSettings} disabled={loading || saving}>
            {saving ? '保存中...' : '保存配置'}
          </button>
        </div>
      </div>
    </div>
  );
};
