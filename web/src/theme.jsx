import { useReducedMotion } from './design/MotionPreferences';
import { RosemaryProvider, IconButton } from '@rosemary-ui/react';
import productTheme from './design/epass-theme.json';
import { importColorScheme } from '@rosemary-ui/tokens';
const scheme = importColorScheme(productTheme);
import { createContext, useContext, useEffect, useMemo, useState } from 'react';
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
  const reduced = useReducedMotion();
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

  return <ThemeContext.Provider value={value}><RosemaryProvider reducedMotion={reduced} scheme={scheme} mode={resolvedTheme} language="zh">{children}</RosemaryProvider></ThemeContext.Provider>;
}

export function useTheme() {
  const value = useContext(ThemeContext);
  if (!value) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return value;
}

export function ThemeToggle({ className = '' }) {
  const { resolvedTheme, setPreference } = useTheme();
  const target = resolvedTheme === 'dark' ? 'light' : 'dark';
  const label = target === 'dark' ? '切换到深色主题' : '切换到浅色主题';
  return <IconButton variant="secondary" type="button" className={cn('epass-theme-toggle', className)} icon={target === 'dark' ? 'moon' : 'sun'} label={label} title={label} onClick={() => setPreference(target)} />;
}
