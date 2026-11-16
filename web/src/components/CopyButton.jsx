import { useEffect, useRef, useState } from 'react';
import { Icon, IconButton } from '@rosemary-ui/react';
import { FormaButton } from './Forma';
import { copyText } from '../lib/clipboard';

export function CopyButton({text, label = '复制代码', children}) {
  const [copied, setCopied] = useState(false), [busy, setBusy] = useState(false), [error, setError] = useState('');
  const currentText = useRef(text);
  currentText.current = text;
  const timer = useRef(), pending = useRef(false), mounted = useRef(false);
  useEffect(() => { mounted.current = true; return () => {mounted.current=false;clearTimeout(timer.current);}; }, []);
  useEffect(() => {clearTimeout(timer.current);setCopied(false);setError('');}, [text]);
  async function copy() {
    if (pending.current) return;
    pending.current = true;setBusy(true);setError('');
    try {
      await copyText(text);
      if (!mounted.current || currentText.current !== text) return;
      clearTimeout(timer.current);setCopied(true);
      timer.current = setTimeout(() => setCopied(false), 1600);
    } catch {
      if (mounted.current) {setCopied(false);setError('复制失败，请手动选择内容复制。');}
    } finally {pending.current=false;if(mounted.current)setBusy(false);}
  }
  const accessible = copied ? `${label}：已复制` : label;
  return <span className="epass-copy-control" data-copied={copied || undefined}>
    {children ? <FormaButton type="button" variant="secondary" className="flex items-center gap-2" aria-label={accessible} onClick={() => void copy()} disabled={busy}>
      <Icon name={copied ? 'check' : 'copy'} size={18} />{children}
    </FormaButton> : <IconButton type="button" variant="ghost" icon={copied ? 'check' : 'copy'} label={accessible} title={accessible} onClick={() => void copy()} disabled={busy} />}
    <span className="sr-only" role="status">{copied ? '已复制到剪贴板' : ''}</span>
    {error && <span className="epass-copy-error" role="alert">{error}</span>}
  </span>;
}
