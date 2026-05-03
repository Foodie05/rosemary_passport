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
    const stored = window.localStorage.getItem(STORAGE_KEY);
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
    window.localStorage.setItem(STORAGE_KEY, preference);
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
  const options = [
    { value: 'system', label: '系统', icon: Laptop },
    { value: 'light', label: '浅色', icon: Sun },
    { value: 'dark', label: '深色', icon: Moon },
  ];

  return (
    <div className={cn('inline-flex items-center rounded-2xl border border-sage-200 bg-white/70 p-1 shadow-sm backdrop-blur-md', className)}>
      {options.map(({ value, label, icon: Icon }) => (
        <button
          key={value}
          type="button"
          onClick={() => setPreference(value)}
          className={cn(
            'inline-flex items-center gap-2 rounded-xl px-3 py-2 text-sm font-medium transition-all',
            preference === value ? 'bg-sage-600 text-white shadow-sm' : 'text-sage-600 hover:bg-sage-100',
          )}
          aria-pressed={preference === value}
          title={label}
        >
          <Icon size={16} />
          <span className="hidden sm:inline">{label}</span>
        </button>
      ))}
    </div>
  );
}
