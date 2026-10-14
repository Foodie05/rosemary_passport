import { FormaButton } from './Forma';
import { Link, useNavigate } from '../design/NavigationMotion';
import { AnimatePresence } from 'motion/react';
import { useState } from 'react';
import { Activity, BookOpen, FileText, Key, LayoutDashboard, LogOut, Menu, ShieldCheck, ScrollText, Users, Mail } from '../design/Icons';
import { Outlet, useLocation } from 'react-router-dom';
import { cleanDisplayName, getInitial } from '../utils';
import { ThemeToggle } from '../theme';
import { Brand, SiteFooter } from './Brand';
import { Dialog } from './Dialog';

const menuItems = [
  { icon: LayoutDashboard, label: '运营看板', to: '/admin/dashboard', group: '管理' },
  { icon: Users, label: '用户管理', to: '/admin/users' },
  { icon: Key, label: '应用接入', to: '/admin/oidc' },
  { icon: Activity, label: '状态管理', to: '/admin/status' },
  { icon: Mail, label: '服务配置', to: '/admin/service', group: '设置' },
  { icon: ScrollText, label: '安全策略', to: '/admin/security' },
  { icon: FileText, label: '协议管理', to: '/admin/legal' },
  { icon: ShieldCheck, label: '账户安全', to: '/admin/account' },
];

function Navigation({ close }) {
  const { pathname } = useLocation();
  return <nav aria-label="管理控制台">{menuItems.map(({ icon: Icon, label, to, group }) => <div key={to}>
    {group && <p className="epass-nav-group">{group}</p>}
    <Link to={to} className="epass-nav-item" aria-current={pathname === to || pathname.startsWith(`${to}/`) ? 'page' : undefined} onClick={close}><Icon size={20} aria-hidden="true" /><span>{label}</span></Link>
  </div>)}</nav>;
}

export function AdminLayout({ session, logout, mustBindEmail }) {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);
  const displayName = cleanDisplayName(session.user?.nickname, session.user?.email || '管理员');
  const pageName = menuItems.find((item) => pathname === item.to || pathname.startsWith(`${item.to}/`))?.label || '管理控制台';
  const exit = () => { logout(); navigate('/login'); };
  return <div className="epass-shell">
    <a href="#main-content" className="epass-skip">跳到主要内容</a>
    <aside className="epass-sidebar">
      <Brand compact subtitle="管理控制台" to="/admin/dashboard" />
      <Navigation />
      <div className="border-t border-line pt-4"><Link className="epass-nav-item" to="/docs"><BookOpen size={20} />接入文档</Link><FormaButton className="epass-nav-item w-full" type="button" onClick={exit}><LogOut size={20} />退出登录</FormaButton></div>
    </aside>
    <div className="flex min-w-0 flex-col">
      <header className="epass-topbar">
        <div className="flex min-w-0 items-center gap-3"><FormaButton type="button" className="inline-flex h-11 w-11 items-center justify-center lg:hidden" aria-label="打开导航" aria-expanded={menuOpen} onClick={() => setMenuOpen(true)}><Menu size={20} /></FormaButton><p className="text-sm text-muted"><span className="hidden sm:inline">管理控制台 <span className="mx-3">/</span></span><span className="text-ink">{pageName}</span></p></div>
        <div className="flex items-center gap-4"><ThemeToggle /><Link to="/admin/account" className="flex items-center gap-3" aria-label={`账户安全：${displayName}`}><span className="hidden text-sm sm:block">{displayName}</span><span className="flex h-9 w-9 items-center justify-center rounded-full bg-accent-subtle text-sm text-accent">{getInitial(session.user?.email)}</span></Link></div>
      </header>
      <main id="main-content" tabIndex={-1} className="epass-workspace flex-1">
        {mustBindEmail && <div className="mb-6 rounded-control border border-warning bg-warning-subtle p-4 text-sm text-warning">请先<Link to="/admin/account" className="underline underline-offset-4">绑定邮箱</Link>，再使用高级管理功能。</div>}
        <Outlet />
      </main>
      <SiteFooter />
    </div>
    <AnimatePresence>{menuOpen && <Dialog key="navigation" className="epass-dialog-navigation" title="管理控制台" onClose={() => setMenuOpen(false)}><Brand compact /><Navigation close={() => setMenuOpen(false)} /><Link to="/docs" className="epass-nav-item" onClick={() => setMenuOpen(false)}><BookOpen size={20} />接入文档</Link><FormaButton type="button" className="epass-nav-item" onClick={exit}><LogOut size={20} />退出登录</FormaButton></Dialog>}</AnimatePresence>
  </div>;
}

export function UserLayout({ session, logout }) {
  const navigate = useNavigate();
  return <div className="flex min-h-dvh flex-col">
    <a href="#main-content" className="epass-skip">跳到主要内容</a>
    <header className="epass-topbar"><Brand compact to="/account" /><div className="flex items-center gap-3"><ThemeToggle /><FormaButton type="button" className="hidden min-h-11 px-3 text-sm text-muted sm:block" onClick={() => { logout(); navigate('/login'); }}>退出登录</FormaButton></div></header>
    <main id="main-content" tabIndex={-1} className="epass-user-main"><Outlet /><FormaButton type="button" className="btn-secondary mt-8 sm:hidden" onClick={() => { logout(); navigate('/login'); }}>退出登录</FormaButton></main>
    <SiteFooter />
  </div>;
}
