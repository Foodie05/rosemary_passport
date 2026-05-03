import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AdminLayout, UserLayout } from './components/Layouts';
import { 
  AdminOverview, 
  AdminUsers, 
  AdminEmailConfig, 
  AdminHCaptchaConfig, 
  AdminOIDCConfig,
  AdminSecuritySettings,
} from './pages/AdminPages';
import { 
  LoginPage, 
  RegisterPage, 
  ForgotPasswordPage 
} from './pages/AuthPages';
import { UserAccountPage } from './pages/UserPages';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* Auth Routes */}
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />

        {/* Admin Routes */}
        <Route path="/admin" element={<AdminLayout />}>
          <Route index element={<AdminOverview />} />
          <Route path="users" element={<AdminUsers />} />
          <Route path="email" element={<AdminEmailConfig />} />
          <Route path="hcaptcha" element={<AdminHCaptchaConfig />} />
          <Route path="oidc" element={<AdminOIDCConfig />} />
          <Route path="settings" element={<AdminSecuritySettings />} />
        </Route>

        {/* User Routes */}
        <Route path="/account" element={<UserLayout />}>
          <Route index element={<UserAccountPage />} />
        </Route>

        {/* Default Redirect */}
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
