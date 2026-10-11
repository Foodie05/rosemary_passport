import { Link } from '../design/NavigationMotion';


export function Brand({ subtitle, to = '/', compact = false }) {
  return (
    <Link className={`epass-brand${compact ? ' epass-brand--compact' : ''}`} to={to} aria-label="Rosemary Epass 首页">
      <span className="epass-brand-mark"><img src="/brand/rosemary.png" alt="" width="32" height="32" /></span>
      <span className="epass-brand-type">Rosemary <span>Epass</span>{subtitle && <small>{subtitle}</small>}</span>
    </Link>
  );
}

export function BrandDrawing() {
  return (
    <svg className="epass-brand-drawing" viewBox="0 0 480 300" fill="none" aria-hidden="true">
      <path className="drawing-grid" d="M0 75H480M0 150H480M0 225H480M120 0V300M240 0V300M360 0V300" />
      <path className="drawing-leaf" d="M126 250C110 93 227 43 354 50C370 207 253 257 126 250Z" />
      <path d="M126 250L354 50M126 250C172 133 256 83 354 50M126 250C250 220 328 143 354 50" />
      <path d="M116 250H136M126 240V260M344 50H364M354 40V60" />
      <circle cx="240" cy="150" r="4" />
    </svg>
  );
}

export function SiteFooter() {
  return <footer className="epass-footer"><span>© {new Date().getFullYear()} Rosemary Epass</span><nav aria-label="法律与文档"><Link to="/legal/terms">使用条款</Link><Link to="/legal/privacy">隐私政策</Link><Link to="/docs">接入文档</Link></nav></footer>;
}
