import { EpassBadge } from './EpassBadge';
import { RosemaryLogo } from '@rosemary-ui/react';
import { Link } from '../design/NavigationMotion';

export function Brand({ to = '/', compact = false }) {
  return <Link className={`epass-brand${compact ? ' epass-brand--compact' : ''}`} to={to} aria-label={compact ? 'Epass 首页' : 'Rosemary Epass 首页'}>
    {compact ? <><EpassBadge size={32} /><span className="epass-brand-short">Epass</span></> : <>
      <RosemaryLogo size={64} alt="" /><span className="epass-brand-words"><span>Rosemary</span><strong>Epass</strong></span>
    </>}
  </Link>;
}
export function BrandDrawing() { return <div className="epass-brand-emblem" aria-hidden="true"><EpassBadge size={160} /></div>; }
export function SiteFooter() {
  return <footer className="epass-footer"><span>© {new Date().getFullYear()} Rosemary Epass</span><nav aria-label="法律与文档"><Link to="/legal/terms">使用条款</Link><Link to="/legal/privacy">隐私政策</Link><Link to="/docs">接入文档</Link></nav></footer>;
}
