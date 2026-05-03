import React from 'react';
import { 
  Users, 
  Mail, 
  ShieldCheck, 
  Key, 
  LayoutDashboard, 
  Settings, 
  LogOut,
  UserCircle,
  Bell,
  Search,
  Menu,
  X,
  ChevronRight,
  Plus,
  MoreVertical,
  ExternalLink,
  Shield,
  Fingerprint,
  Globe
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { Link, useLocation, useNavigate, Outlet } from 'react-router-dom';
import { cn } from '@/src/lib/utils';

// --- Components ---

const SidebarItem = ({ icon: Icon, label, to, active }: { icon: any, label: string, to: string, active: boolean }) => (
  <Link to={to}>
    <motion.div
      whileHover={{ x: 4 }}
      className={cn(
        "flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-300 group",
        active 
          ? "bg-sage-600 text-white shadow-md shadow-sage-600/20" 
          : "text-sage-600 hover:bg-sage-100"
      )}
    >
      <Icon size={20} className={cn(active ? "text-white" : "text-sage-400 group-hover:text-sage-600")} />
      <span className="font-medium">{label}</span>
      {active && (
        <motion.div 
          layoutId="sidebar-active"
          className="ml-auto w-1.5 h-1.5 rounded-full bg-white"
        />
      )}
    </motion.div>
  </Link>
);

export const AdminLayout = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const [isMobileMenuOpen, setIsMobileMenuOpen] = React.useState(false);

  const menuItems = [
    { icon: LayoutDashboard, label: '概览', to: '/admin' },
    { icon: Users, label: '用户管理', to: '/admin/users' },
    { icon: Mail, label: '邮件系统', to: '/admin/email' },
    { icon: ShieldCheck, label: 'hCaptcha', to: '/admin/hcaptcha' },
    { icon: Key, label: 'OIDC配置', to: '/admin/oidc' },
    { icon: Settings, label: '系统设置', to: '/admin/settings' },
  ];

  return (
    <div className="flex min-h-screen bg-sage-50">
      {/* Desktop Sidebar */}
      <aside className="hidden lg:flex flex-col w-64 p-6 border-r border-sage-200 bg-white/50 backdrop-blur-xl sticky top-0 h-screen">
        <div className="flex items-center gap-3 mb-10 px-2">
          <div className="w-10 h-10 bg-sage-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-sage-600/20">
            <Shield size={24} />
          </div>
          <div>
            <h1 className="font-bold text-lg tracking-tight text-sage-900">ROSM Admin</h1>
            <p className="text-xs text-sage-500 font-medium">管理控制台</p>
          </div>
        </div>

        <nav className="flex-1 space-y-1">
          {menuItems.map((item) => (
            <SidebarItem 
              key={item.to} 
              {...item} 
              active={location.pathname === item.to} 
            />
          ))}
        </nav>

        <div className="mt-auto pt-6 border-t border-sage-100">
          <button 
            onClick={() => navigate('/login')}
            className="flex items-center gap-3 px-4 py-3 w-full text-sage-500 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all duration-300"
          >
            <LogOut size={20} />
            <span className="font-medium">退出登录</span>
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Header */}
        <header className="h-16 border-b border-sage-200 bg-white/50 backdrop-blur-md flex items-center justify-between px-6 sticky top-0 z-10">
          <div className="flex items-center gap-4 lg:hidden">
            <button onClick={() => setIsMobileMenuOpen(true)} className="p-2 text-sage-600">
              <Menu size={24} />
            </button>
            <span className="font-bold text-sage-900">ROSM</span>
          </div>

          <div className="hidden md:flex items-center bg-sage-100/50 rounded-full px-4 py-1.5 border border-sage-200 w-96 group focus-within:ring-2 focus-within:ring-sage-400/20 transition-all">
            <Search size={18} className="text-sage-400 group-focus-within:text-sage-600" />
            <input 
              type="text" 
              placeholder="搜索用户、配置或日志..." 
              className="bg-transparent border-none focus:ring-0 text-sm w-full ml-2 text-sage-700 placeholder:text-sage-400"
            />
          </div>

          <div className="flex items-center gap-4">
            <button className="p-2 text-sage-500 hover:bg-sage-100 rounded-full transition-colors relative">
              <Bell size={20} />
              <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>
            </button>
            <div className="h-8 w-px bg-sage-200 mx-1"></div>
            <div className="flex items-center gap-3 pl-2 cursor-pointer group">
              <div className="text-right hidden sm:block">
                <p className="text-sm font-semibold text-sage-900 leading-none">Admin User</p>
                <p className="text-xs text-sage-500 mt-1">超级管理员</p>
              </div>
              <div className="w-10 h-10 rounded-full bg-sage-200 border-2 border-white shadow-sm overflow-hidden group-hover:border-sage-300 transition-all">
                <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=admin" alt="avatar" />
              </div>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <div className="p-6 lg:p-10 max-w-7xl mx-auto w-full">
          <AnimatePresence mode="wait">
            <motion.div
              key={location.pathname}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.3, ease: "easeOut" }}
            >
              <Outlet />
            </motion.div>
          </AnimatePresence>
        </div>
      </main>

      {/* Mobile Menu Overlay */}
      <AnimatePresence>
        {isMobileMenuOpen && (
          <>
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setIsMobileMenuOpen(false)}
              className="fixed inset-0 bg-sage-900/20 backdrop-blur-sm z-40 lg:hidden"
            />
            <motion.aside
              initial={{ x: '-100%' }}
              animate={{ x: 0 }}
              exit={{ x: '-100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="fixed inset-y-0 left-0 w-72 bg-white z-50 p-6 lg:hidden shadow-2xl"
            >
              <div className="flex items-center justify-between mb-10">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-sage-600 rounded-xl flex items-center justify-center text-white">
                    <Shield size={24} />
                  </div>
                  <span className="font-bold text-lg text-sage-900">ROSM Admin</span>
                </div>
                <button onClick={() => setIsMobileMenuOpen(false)} className="p-2 text-sage-400">
                  <X size={24} />
                </button>
              </div>
              <nav className="space-y-1">
                {menuItems.map((item) => (
                  <SidebarItem 
                    key={item.to} 
                    {...item} 
                    active={location.pathname === item.to} 
                  />
                ))}
              </nav>
            </motion.aside>
          </>
        )}
      </AnimatePresence>
    </div>
  );
};

export const UserLayout = () => {
  const navigate = useNavigate();
  return (
    <div className="min-h-screen bg-sage-50 flex flex-col">
      <header className="h-16 bg-white/70 backdrop-blur-md border-b border-sage-200 px-6 flex items-center justify-between sticky top-0 z-10">
        <div className="flex items-center gap-2 cursor-pointer" onClick={() => navigate('/')}>
          <div className="w-8 h-8 bg-sage-600 rounded-lg flex items-center justify-center text-white">
            <Fingerprint size={18} />
          </div>
          <span className="font-bold text-sage-900 tracking-tight">ROSM Pass</span>
        </div>
        <div className="flex items-center gap-4">
          <button className="text-sm font-medium text-sage-600 hover:text-sage-900 transition-colors">帮助中心</button>
          <div className="w-8 h-8 rounded-full bg-sage-200 border border-white shadow-sm overflow-hidden">
            <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=user" alt="avatar" />
          </div>
        </div>
      </header>
      <main className="flex-1 p-6 lg:p-10 max-w-5xl mx-auto w-full">
        <Outlet />
      </main>
      <footer className="py-8 text-center text-sage-400 text-sm border-t border-sage-200 bg-white/30">
        <p>© 2026 ROSM 通行证 · 迷迭香主题单点登录系统</p>
      </footer>
    </div>
  );
};
