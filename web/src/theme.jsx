import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { Laptop, Moon, Sun } from 'lucide-react';
import { cn } from './lib/utils';

const STORAGE_KEY = 'rosm_theme_preference';
const ThemeContext = createContext(null);

function getSystemTheme() {
  if (typeof window === 'undefined') {
    return 'light';
  }
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function ThemeProvider({ children }) {
  const [preference, setPreference] = useState(() => {
    if (typeof window === 'undefined') {
      return 'system';
    }
    let stored;
    try { stored = window.localStorage.getItem(STORAGE_KEY); } catch {}
    return stored === 'light' || stored === 'dark' || stored === 'system' ? stored : 'system';
  });
  const [systemTheme, setSystemTheme] = useState(getSystemTheme);

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = (event) => setSystemTheme(event.matches ? 'dark' : 'light');
    onChange(media);
    media.addEventListener('change', onChange);
    return () => media.removeEventListener('change', onChange);
  }, []);

  const resolvedTheme = preference === 'system' ? systemTheme : preference;

  useEffect(() => {
    try { window.localStorage.setItem(STORAGE_KEY, preference); } catch {}
    document.documentElement.dataset.theme = resolvedTheme;
    document.documentElement.dataset.themePreference = preference;
    document.documentElement.style.colorScheme = resolvedTheme;
  }, [preference, resolvedTheme]);

  const value = useMemo(
    () => ({
      preference,
      resolvedTheme,
      setPreference,
    }),
    [preference, resolvedTheme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const value = useContext(ThemeContext);
  if (!value) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return value;
}

export function ThemeToggle({ className = '' }) {
  const { preference, setPreference } = useTheme();
  const options = [{ value: 'system', label: '跟随系统', icon: Laptop }, { value: 'light', label: '浅色主题', icon: Sun }, { value: 'dark', label: '深色主题', icon: Moon }];
  return <div className={cn('epass-theme', className)} role="group" aria-label="网站主题">{options.map(({ value, label, icon: Icon }) => <button key={value} type="button" onClick={() => setPreference(value)} aria-pressed={preference === value} aria-label={label} title={label}><Icon size={18} aria-hidden="true" /></button>)}</div>;
}
