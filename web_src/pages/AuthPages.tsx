import React from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Fingerprint, 
  Mail, 
  Lock, 
  User, 
  ArrowRight, 
  Github, 
  Chrome, 
  ChevronLeft,
  ShieldCheck,
  CheckCircle2,
  Info
} from 'lucide-react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { cn } from '@/src/lib/utils';

// --- Auth Components ---

const AuthInput = ({ icon: Icon, label, type = "text", placeholder }: any) => (
  <div className="space-y-2">
    <label className="text-sm font-bold text-sage-700 ml-1">{label}</label>
    <div className="relative group">
      <div className="absolute left-4 top-1/2 -translate-y-1/2 text-sage-400 group-focus-within:text-sage-600 transition-colors">
        <Icon size={18} />
      </div>
      <input 
        type={type} 
        placeholder={placeholder}
        className="w-full pl-12 pr-4 py-3 bg-sage-50/50 border border-sage-200 rounded-2xl focus:outline-none focus:ring-4 focus:ring-sage-400/10 focus:border-sage-400 transition-all duration-300 placeholder:text-sage-300"
      />
    </div>
  </div>
);

const BrandSection = () => (
  <div className="hidden lg:flex flex-col justify-between p-12 bg-sage-900 text-white relative overflow-hidden">
    {/* Decorative Background Elements */}
    <div className="absolute top-0 right-0 w-96 h-96 bg-sage-600/20 blur-[120px] rounded-full -mr-48 -mt-48"></div>
    <div className="absolute bottom-0 left-0 w-96 h-96 bg-sage-400/10 blur-[100px] rounded-full -ml-48 -mb-48"></div>
    
    <div className="relative z-10">
      <div className="flex items-center gap-3 mb-12">
        <div className="w-12 h-12 bg-white text-sage-900 rounded-2xl flex items-center justify-center shadow-xl">
          <Fingerprint size={28} />
        </div>
        <span className="text-2xl font-bold tracking-tight">ROSM Pass</span>
      </div>
      
      <motion.div
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ delay: 0.2, duration: 0.8 }}
      >
        <h2 className="text-5xl font-bold leading-tight mb-6">
          温和且坚定的<br />
          数字身份守护者
        </h2>
        <p className="text-sage-400 text-lg max-w-md leading-relaxed">
          迷迭香的花语是回忆与忠诚。我们以此为名，致力于为您提供最安全、最人性化的单点登录体验。
        </p>
      </motion.div>
    </div>

    <div className="relative z-10">
      <div className="flex gap-8 mb-8">
        <div>
          <p className="text-3xl font-bold">12k+</p>
          <p className="text-sage-500 text-sm mt-1">信任用户</p>
        </div>
        <div className="w-px h-12 bg-white/10"></div>
        <div>
          <p className="text-3xl font-bold">99.9%</p>
          <p className="text-sage-500 text-sm mt-1">在线率</p>
        </div>
      </div>
      <p className="text-sage-600 text-xs font-medium uppercase tracking-widest">
        © 2026 ROSM TECHNOLOGY GROUP
      </p>
    </div>
  </div>
);

// --- Pages ---

export const LoginPage = () => {
  const navigate = useNavigate();
  return (
    <div className="min-h-screen grid grid-cols-1 lg:grid-cols-2 bg-white">
      <BrandSection />
      
      <div className="flex flex-col justify-center p-8 sm:p-12 lg:p-24 relative">
        <div className="max-w-md w-full mx-auto space-y-10">
          <div className="space-y-2">
            <h1 className="text-3xl font-bold text-sage-900">欢迎回来</h1>
            <p className="text-sage-500">请输入您的凭据以访问您的账户。</p>
          </div>

          <form className="space-y-6" onSubmit={(e) => { e.preventDefault(); navigate('/admin'); }}>
            <AuthInput icon={Mail} label="邮箱地址" placeholder="name@example.com" />
            <div className="space-y-2">
              <div className="flex justify-between items-center px-1">
                <label className="text-sm font-bold text-sage-700">密码</label>
                <Link to="/forgot-password" title="忘记密码" className="text-xs font-bold text-sage-600 hover:text-sage-900 transition-colors">
                  忘记密码？
                </Link>
              </div>
              <div className="relative group">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 text-sage-400 group-focus-within:text-sage-600 transition-colors">
                  <Lock size={18} />
                </div>
                <input 
                  type="password" 
                  placeholder="••••••••"
                  className="w-full pl-12 pr-4 py-3 bg-sage-50/50 border border-sage-200 rounded-2xl focus:outline-none focus:ring-4 focus:ring-sage-400/10 focus:border-sage-400 transition-all duration-300"
                />
              </div>
            </div>

            <div className="flex items-center gap-2 px-1">
              <input type="checkbox" id="remember" className="w-4 h-4 rounded text-sage-600 focus:ring-sage-400" />
              <label htmlFor="remember" className="text-sm text-sage-500">保持登录状态</label>
            </div>

            <button type="submit" className="btn-primary w-full py-4 text-lg font-bold flex items-center justify-center gap-2">
              登录
              <ArrowRight size={20} />
            </button>
          </form>

          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-sage-100"></div>
            </div>
            <div className="relative flex justify-center text-xs uppercase tracking-widest font-bold">
              <span className="bg-white px-4 text-sage-400">或者通过以下方式</span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <button className="btn-secondary flex items-center justify-center gap-2 py-3">
              <Github size={20} />
              GitHub
            </button>
            <button className="btn-secondary flex items-center justify-center gap-2 py-3">
              <Chrome size={20} />
              Google
            </button>
          </div>

          <p className="text-center text-sage-500 text-sm">
            还没有账户？{' '}
            <Link to="/register" className="font-bold text-sage-900 hover:underline decoration-sage-400 underline-offset-4">
              立即注册
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export const RegisterPage = () => {
  const navigate = useNavigate();
  return (
    <div className="min-h-screen grid grid-cols-1 lg:grid-cols-2 bg-white">
      <BrandSection />
      
      <div className="flex flex-col justify-center p-8 sm:p-12 lg:p-24">
        <div className="max-w-md w-full mx-auto space-y-8">
          <div className="space-y-2">
            <h1 className="text-3xl font-bold text-sage-900">创建新账户</h1>
            <p className="text-sage-500">加入 ROSM 通行证，开启您的数字身份之旅。</p>
          </div>

          <form className="space-y-5" onSubmit={(e) => { e.preventDefault(); navigate('/account'); }}>
            <AuthInput icon={User} label="全名" placeholder="张三" />
            <AuthInput icon={Mail} label="邮箱地址" placeholder="name@example.com" />
            <AuthInput icon={Lock} label="设置密码" type="password" placeholder="••••••••" />
            
            <div className="p-4 bg-sage-50 rounded-2xl border border-sage-100 space-y-3">
              <p className="text-xs font-bold text-sage-400 uppercase tracking-wider">密码强度</p>
              <div className="flex gap-1">
                <div className="h-1.5 flex-1 bg-sage-400 rounded-full"></div>
                <div className="h-1.5 flex-1 bg-sage-400 rounded-full"></div>
                <div className="h-1.5 flex-1 bg-sage-200 rounded-full"></div>
                <div className="h-1.5 flex-1 bg-sage-200 rounded-full"></div>
              </div>
              <p className="text-[10px] text-sage-500">建议包含大写字母、数字和特殊符号。</p>
            </div>

            <div className="flex items-start gap-2 px-1">
              <input type="checkbox" id="terms" className="mt-1 w-4 h-4 rounded text-sage-600 focus:ring-sage-400" />
              <label htmlFor="terms" className="text-xs text-sage-500 leading-relaxed">
                我已阅读并同意 <Link to="#" className="text-sage-900 underline underline-offset-2">服务条款</Link> 和 <Link to="#" className="text-sage-900 underline underline-offset-2">隐私政策</Link>。
              </label>
            </div>

            <button type="submit" className="btn-primary w-full py-4 text-lg font-bold">
              注册账户
            </button>
          </form>

          <p className="text-center text-sage-500 text-sm">
            已经有账户了？{' '}
            <Link to="/login" className="font-bold text-sage-900 hover:underline decoration-sage-400 underline-offset-4">
              返回登录
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export const ForgotPasswordPage = () => {
  const [isSent, setIsSent] = React.useState(false);

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-sage-50">
      <div className="max-w-md w-full">
        <motion.div 
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="glass-card rounded-[2.5rem] p-10 shadow-2xl shadow-sage-900/5"
        >
          <AnimatePresence mode="wait">
            {!isSent ? (
              <motion.div 
                key="request"
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -20 }}
                className="space-y-8"
              >
                <div className="text-center space-y-4">
                  <div className="w-16 h-16 bg-sage-100 text-sage-600 rounded-2xl flex items-center justify-center mx-auto">
                    <Lock size={32} />
                  </div>
                  <h1 className="text-2xl font-bold text-sage-900">忘记密码了？</h1>
                  <p className="text-sage-500 leading-relaxed">
                    别担心，这很正常。请输入您的注册邮箱，我们将向您发送重置链接。
                  </p>
                </div>

                <div className="space-y-6">
                  <AuthInput icon={Mail} label="邮箱地址" placeholder="name@example.com" />
                  <button 
                    onClick={() => setIsSent(true)}
                    className="btn-primary w-full py-4 font-bold"
                  >
                    发送重置链接
                  </button>
                  <Link to="/login" className="flex items-center justify-center gap-2 text-sm font-bold text-sage-400 hover:text-sage-600 transition-colors">
                    <ChevronLeft size={18} />
                    返回登录
                  </Link>
                </div>
              </motion.div>
            ) : (
              <motion.div 
                key="success"
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -20 }}
                className="text-center space-y-8 py-4"
              >
                <div className="w-20 h-20 bg-green-100 text-green-600 rounded-full flex items-center justify-center mx-auto">
                  <CheckCircle2 size={48} />
                </div>
                <div className="space-y-3">
                  <h1 className="text-2xl font-bold text-sage-900">邮件已发送</h1>
                  <p className="text-sage-500 leading-relaxed">
                    我们已向您的邮箱发送了重置密码的指令。请检查您的收件箱（以及垃圾邮件箱）。
                  </p>
                </div>
                <div className="pt-4">
                  <button 
                    onClick={() => setIsSent(false)}
                    className="btn-secondary w-full py-4 font-bold mb-4"
                  >
                    没收到？重新发送
                  </button>
                  <Link to="/login" className="text-sm font-bold text-sage-600 hover:underline underline-offset-4">
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
};
