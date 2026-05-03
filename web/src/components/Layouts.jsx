import { useMemo, useState } from 'react';
import {
  Bell,
  Fingerprint,
  Key,
  LogOut,
  Mail,
  Menu,
  ShieldCheck,
  ScrollText,
  Shield,
  Users,
  X,
} from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { Link, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { cn } from '../lib/utils';
import { cleanDisplayName, getInitial } from '../utils';
import { ThemeToggle } from '../theme';

function SidebarItem({ icon: Icon, label, to, active }) {
  return (
    <Link to={to}>
      <motion.div
        whileHover={{ x: 4 }}
        className={cn(
          'flex items-center gap-3 rounded-xl px-4 py-3 transition-all duration-300 group',
          active ? 'bg-sage-600 text-white shadow-md shadow-sage-600/20' : 'text-sage-600 hover:bg-sage-100',
        )}
      >
        <Icon size={20} className={cn(active ? 'text-white' : 'text-sage-400 group-hover:text-sage-600')} />
        <span className="font-medium">{label}</span>
        {active && <motion.div layoutId="sidebar-active" className="ml-auto h-1.5 w-1.5 rounded-full bg-white" />}
      </motion.div>
    </Link>
  );
}

export function AdminLayout({ session, logout, mustBindEmail }) {
  const location = useLocation();
  const navigate = useNavigate();
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const menuItems = useMemo(
    () =>
      [
        { icon: ShieldCheck, label: '账户安全', to: '/admin/account' },
        { icon: Mail, label: '服务配置', to: '/admin/service' },
        { icon: Users, label: '用户管理', to: '/admin/users' },
        { icon: Key, label: 'OCID', to: '/admin/oidc' },
        { icon: ScrollText, label: '安全策略', to: '/admin/security' },
      ],
    [],
  );

  const displayName = cleanDisplayName(session.user?.nickname, session.user?.email || 'Admin');

  const sidebar = (
    <>
      <div className="mb-10 flex items-center gap-3 px-2">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-sage-600 text-white shadow-lg shadow-sage-600/20">
          <Shield size={24} />
        </div>
        <div>
          <h1 className="text-lg font-bold tracking-tight text-sage-900">ROSM Admin</h1>
          <p className="text-xs font-medium text-sage-500">身份与接入控制台</p>
        </div>
      </div>

      <nav className="flex-1 space-y-1">
        {menuItems.map((item) => (
          <SidebarItem key={item.to} {...item} active={location.pathname === item.to || location.pathname.startsWith(`${item.to}/`)} />
        ))}
      </nav>

      <div className="mt-auto border-t border-sage-100 pt-6">
        <button
          onClick={() => {
            logout();
            navigate('/login');
          }}
          className="flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sage-500 transition-all duration-300 hover:bg-red-50 hover:text-red-500"
          type="button"
        >
          <LogOut size={20} />
          <span className="font-medium">退出登录</span>
        </button>
      </div>
    </>
  );

  return (
    <div className="flex min-h-screen bg-sage-50">
      <aside className="sticky top-0 hidden h-screen w-64 flex-col border-r border-sage-200 bg-white/50 p-6 backdrop-blur-xl lg:flex">
        {sidebar}
      </aside>

      <main className="flex min-w-0 flex-1 flex-col overflow-hidden">
        <header className="sticky top-0 z-10 flex h-16 items-center justify-between border-b border-sage-200 bg-white/50 px-6 backdrop-blur-md">
          <div className="flex items-center gap-4 lg:hidden">
            <button onClick={() => setIsMobileMenuOpen(true)} className="p-2 text-sage-600" type="button">
              <Menu size={24} />
            </button>
            <span className="font-bold text-sage-900">ROSM</span>
          </div>

          <div className="hidden items-center rounded-full border border-sage-200 bg-sage-100/50 px-4 py-1.5 md:flex">
            <span className="text-sm text-sage-500">
              {mustBindEmail ? '当前账号需先完成邮箱绑定后再继续高级管理。' : '身份、接入、安全与审计统一管理。'}
            </span>
          </div>

          <div className="flex items-center gap-4">
            <ThemeToggle className="hidden md:inline-flex" />
            <button className="relative rounded-full p-2 text-sage-500 transition-colors hover:bg-sage-100" type="button">
              <Bell size={20} />
              {mustBindEmail && <span className="absolute right-2 top-2 h-2 w-2 rounded-full border-2 border-white bg-amber-500" />}
            </button>
            <div className="mx-1 h-8 w-px bg-sage-200" />
            <Link to="/admin/account" className="group flex items-center gap-3 pl-2">
              <div className="hidden text-right sm:block">
                <p className="text-sm font-semibold leading-none text-sage-900">{displayName}</p>
                <p className="mt-1 text-xs text-sage-500">{(session.user?.roles || []).join(', ') || '成员'}</p>
              </div>
              <div className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full border-2 border-white bg-sage-200 text-sm font-bold text-sage-700 shadow-sm transition-all group-hover:border-sage-300">
                {getInitial(session.user?.email)}
              </div>
            </Link>
          </div>
        </header>

        <div className="mx-auto w-full max-w-7xl p-6 lg:p-10">
          <Outlet />
        </div>
      </main>

      <AnimatePresence>
        {isMobileMenuOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setIsMobileMenuOpen(false)}
              className="fixed inset-0 z-40 bg-sage-900/20 backdrop-blur-sm lg:hidden"
            />
            <motion.aside
              initial={{ x: '-100%' }}
              animate={{ x: 0 }}
              exit={{ x: '-100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="fixed inset-y-0 left-0 z-50 w-72 bg-white p-6 shadow-2xl lg:hidden"
            >
              <div className="mb-10 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-sage-600 text-white">
                    <Shield size={24} />
                  </div>
                  <span className="text-lg font-bold text-sage-900">ROSM Admin</span>
                </div>
                <button onClick={() => setIsMobileMenuOpen(false)} className="p-2 text-sage-400" type="button">
                  <X size={24} />
                </button>
              </div>
              <div className="flex h-full flex-col">
                <div className="mb-4">
                  <ThemeToggle className="w-full justify-center" />
                </div>
                <div className="flex-1 space-y-1" onClick={() => setIsMobileMenuOpen(false)}>
                  {menuItems.map((item) => (
                    <SidebarItem key={item.to} {...item} active={location.pathname === item.to || location.pathname.startsWith(`${item.to}/`)} />
                  ))}
                </div>
                <button
                  onClick={() => {
                    logout();
                    navigate('/login');
                  }}
                  className="mt-6 flex items-center gap-3 rounded-xl px-4 py-3 text-sage-500 hover:bg-red-50 hover:text-red-500"
                  type="button"
                >
                  <LogOut size={20} />
                  <span className="font-medium">退出登录</span>
                </button>
              </div>
            </motion.aside>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}

export function UserLayout({ session, logout }) {
  const navigate = useNavigate();
  const displayName = cleanDisplayName(session.user?.nickname, session.user?.email || 'User');

  return (
    <div className="flex min-h-screen flex-col bg-sage-50">
      <header className="sticky top-0 z-10 flex h-16 items-center justify-between border-b border-sage-200 bg-white/70 px-6 backdrop-blur-md">
        <div className="flex cursor-pointer items-center gap-2" onClick={() => navigate('/account')}>
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-sage-600 text-white">
            <Fingerprint size={18} />
          </div>
          <span className="font-bold tracking-tight text-sage-900">ROSM Pass</span>
        </div>
        <div className="flex items-center gap-4">
          <ThemeToggle className="hidden md:inline-flex" />
          <span className="hidden text-sm font-medium text-sage-600 sm:block">{displayName}</span>
          <button
            onClick={() => {
              logout();
              navigate('/login');
            }}
            className="rounded-xl px-3 py-2 text-sm font-medium text-sage-600 transition-colors hover:bg-sage-100 hover:text-sage-900"
            type="button"
          >
            退出
          </button>
          <div className="flex h-8 w-8 items-center justify-center rounded-full border border-white bg-sage-200 text-xs font-bold text-sage-700 shadow-sm">
            {getInitial(session.user?.email)}
          </div>
        </div>
      </header>
      <main className="mx-auto w-full max-w-5xl flex-1 p-6 lg:p-10">
        <Outlet />
      </main>
      <footer className="border-t border-sage-200 bg-white/30 py-8 text-center text-sm text-sage-400">
        <p>© 2026 ROSM 通行证 · 单点登录系统</p>
      </footer>
    </div>
  );
}
