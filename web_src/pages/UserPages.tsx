import React from 'react';
import { motion } from 'motion/react';
import { 
  User, 
  Shield, 
  Key, 
  Smartphone, 
  History, 
  ChevronRight, 
  Camera,
  Mail,
  Lock,
  LogOut,
  ExternalLink,
  Bell,
  Eye,
  EyeOff
} from 'lucide-react';
import { cn } from '@/src/lib/utils';

const AccountSection = ({ title, children, icon: Icon }: any) => (
  <div className="space-y-4">
    <div className="flex items-center gap-2 px-2">
      <Icon size={18} className="text-sage-400" />
      <h3 className="text-sm font-bold text-sage-400 uppercase tracking-wider">{title}</h3>
    </div>
    <div className="glass-card rounded-3xl overflow-hidden divide-y divide-sage-100">
      {children}
    </div>
  </div>
);

const AccountItem = ({ label, value, action, icon: Icon, danger }: any) => (
  <div className="p-5 flex items-center justify-between hover:bg-sage-50/30 transition-colors group cursor-pointer">
    <div className="flex items-center gap-4">
      {Icon && (
        <div className={cn(
          "p-2 rounded-xl",
          danger ? "bg-red-50 text-red-500" : "bg-sage-100 text-sage-600"
        )}>
          <Icon size={18} />
        </div>
      )}
      <div>
        <p className="text-xs font-bold text-sage-400 uppercase tracking-tight">{label}</p>
        <p className={cn("text-sm font-semibold mt-0.5", danger ? "text-red-600" : "text-sage-900")}>{value}</p>
      </div>
    </div>
    <div className="flex items-center gap-2 text-sage-400 group-hover:text-sage-600 transition-colors">
      <span className="text-xs font-bold">{action}</span>
      <ChevronRight size={16} />
    </div>
  </div>
);

export const UserAccountPage = () => {
  return (
    <div className="space-y-10 py-6">
      {/* Profile Header */}
      <div className="flex flex-col md:flex-row items-center gap-8 bg-white/40 p-8 rounded-[2.5rem] border border-white/50 shadow-sm">
        <div className="relative group">
          <div className="w-32 h-32 rounded-[2.5rem] bg-sage-200 border-4 border-white shadow-xl overflow-hidden">
            <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=user" alt="avatar" />
          </div>
          <button className="absolute -bottom-2 -right-2 p-2.5 bg-sage-600 text-white rounded-2xl shadow-lg shadow-sage-600/20 opacity-0 group-hover:opacity-100 transition-all transform translate-y-2 group-hover:translate-y-0">
            <Camera size={18} />
          </button>
        </div>
        <div className="text-center md:text-left space-y-2">
          <h2 className="text-3xl font-bold text-sage-900">迷迭香草</h2>
          <p className="text-sage-500 font-medium">UID: 82739410 · 注册于 2026年3月</p>
          <div className="flex flex-wrap justify-center md:justify-start gap-2 pt-2">
            <span className="px-3 py-1 bg-green-100 text-green-700 rounded-full text-[10px] font-bold uppercase tracking-wider">已实名认证</span>
            <span className="px-3 py-1 bg-sage-100 text-sage-600 rounded-full text-[10px] font-bold uppercase tracking-wider">普通用户</span>
          </div>
        </div>
        <div className="md:ml-auto flex gap-3">
          <button className="btn-secondary px-4">编辑资料</button>
          <button className="btn-primary px-4 bg-red-500 hover:bg-red-600 shadow-red-500/20">
            <LogOut size={18} />
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        <div className="lg:col-span-2 space-y-10">
          <AccountSection title="基本信息" icon={User}>
            <AccountItem label="用户名" value="迷迭香草" action="修改" />
            <AccountItem label="邮箱地址" value="rosemary@example.com" action="更换" />
            <AccountItem label="手机号码" value="+86 138 **** 8888" action="绑定" />
          </AccountSection>

          <AccountSection title="安全设置" icon={Shield}>
            <AccountItem label="登录密码" value="上次修改于 3个月前" action="重置" />
            <AccountItem label="双因素认证 (2FA)" value="未启用" action="去开启" />
            <AccountItem label="安全问题" value="已设置 3 个问题" action="管理" />
          </AccountSection>

          <AccountSection title="最近登录活动" icon={History}>
            {[
              { device: 'MacBook Pro · Chrome', location: '上海, 中国', time: '刚刚', current: true },
              { device: 'iPhone 15 Pro · Safari', location: '上海, 中国', time: '2小时前', current: false },
              { device: 'Windows PC · Edge', location: '北京, 中国', time: '昨天 14:20', current: false },
            ].map((log, i) => (
              <div key={i} className="p-5 flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="p-2 bg-sage-50 text-sage-400 rounded-xl">
                    <Smartphone size={18} />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-semibold text-sage-900">{log.device}</p>
                      {log.current && <span className="text-[10px] bg-sage-100 text-sage-600 px-1.5 py-0.5 rounded font-bold">当前</span>}
                    </div>
                    <p className="text-xs text-sage-400 mt-0.5">{log.location} · {log.time}</p>
                  </div>
                </div>
                <button className="text-xs font-bold text-sage-400 hover:text-red-500 transition-colors">下线</button>
              </div>
            ))}
            <div className="p-4 bg-sage-50/50 text-center">
              <button className="text-xs font-bold text-sage-500 hover:text-sage-900 transition-colors">查看完整登录历史</button>
            </div>
          </AccountSection>
        </div>

        <div className="space-y-8">
          <div className="glass-card p-6 rounded-[2rem] space-y-6">
            <h3 className="font-bold text-sage-900 flex items-center gap-2">
              <ExternalLink size={18} className="text-sage-400" />
              已授权的应用
            </h3>
            <div className="space-y-4">
              {[
                { name: 'ROSM Blog', icon: 'B', color: 'bg-blue-500' },
                { name: '迷迭香社区', icon: 'C', color: 'bg-sage-600' },
                { name: '开发者控制台', icon: 'D', color: 'bg-amber-500' },
              ].map((app) => (
                <div key={app.name} className="flex items-center justify-between group">
                  <div className="flex items-center gap-3">
                    <div className={cn("w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold text-lg shadow-sm", app.color)}>
                      {app.icon}
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-sage-900">{app.name}</p>
                      <p className="text-[10px] text-sage-400 uppercase tracking-wider">已授权基本资料</p>
                    </div>
                  </div>
                  <button className="p-2 text-sage-300 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-all">
                    <LogOut size={16} />
                  </button>
                </div>
              ))}
            </div>
            <button className="w-full py-3 border border-dashed border-sage-200 rounded-2xl text-xs font-bold text-sage-400 hover:border-sage-400 hover:text-sage-600 transition-all">
              管理所有授权
            </button>
          </div>

          <div className="bg-sage-100/50 p-6 rounded-[2rem] border border-sage-200">
            <h3 className="font-bold text-sage-900 mb-4 flex items-center gap-2">
              <Bell size={18} className="text-sage-400" />
              通知偏好
            </h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-sage-600">登录异常提醒</span>
                <div className="w-10 h-5 bg-sage-600 rounded-full relative cursor-pointer">
                  <div className="absolute right-0.5 top-0.5 w-4 h-4 bg-white rounded-full shadow-sm"></div>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-sage-600">新功能与活动</span>
                <div className="w-10 h-5 bg-sage-200 rounded-full relative cursor-pointer">
                  <div className="absolute left-0.5 top-0.5 w-4 h-4 bg-white rounded-full shadow-sm"></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
