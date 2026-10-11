import { createContext, useContext, useEffect, useLayoutEffect, useState } from 'react';
import { MotionConfig } from 'motion/react';
const Context = createContext(null);
export function MotionPreferences({ children }) {
  const [reduce, setReduce] = useState(() => { try { return localStorage.getItem('rosemary_motion') === 'reduce'; } catch { return false; } });
  const [systemReduce, setSystemReduce] = useState(() => matchMedia('(prefers-reduced-motion: reduce)').matches);
  useEffect(() => {
    const media = matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => setSystemReduce(media.matches);
    media.addEventListener('change', update);
    return () => media.removeEventListener('change', update);
  }, []);
  const reduced = reduce || systemReduce;
  useLayoutEffect(() => { document.documentElement.dataset.reduceMotion = String(reduced); }, [reduced]);
  useEffect(() => {
    const update = () => { document.documentElement.dataset.documentHidden = String(document.hidden); };
    update();
    document.addEventListener('visibilitychange', update);
    return () => document.removeEventListener('visibilitychange', update);
  }, []);
  useEffect(() => { try { localStorage.setItem('rosemary_motion', reduce ? 'reduce' : 'system'); } catch {} }, [reduce]);
  return <Context.Provider value={{ reduce, reduced, setReduce }}><MotionConfig reducedMotion={reduced ? 'always' : 'never'}>{children}</MotionConfig></Context.Provider>;
}
export function MotionToggle() {
  const { reduce, setReduce } = useContext(Context);
  return <button className="epass-motion" type="button" aria-pressed={reduce} onClick={() => setReduce(!reduce)}>动态效果：{reduce ? '减少' : '跟随系统'}</button>;
}

export function useReducedMotion() { return useContext(Context)?.reduced ?? false; }
