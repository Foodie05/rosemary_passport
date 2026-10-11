import { Link } from '../design/NavigationMotion';
import { ArrowLeft, Ban, ExternalLink } from 'lucide-react';

import { Brand, SiteFooter } from '../components/Brand';
import { ThemeToggle } from '../theme';

function PageChrome({ children }) {
  return <div className="flex min-h-dvh flex-col"><header className="epass-topbar"><Brand /><ThemeToggle /></header><div className="flex-1 px-5">{children}</div><SiteFooter /></div>;
}

export function LegalDocumentPage({ document, loading }) {
  return (
    <PageChrome>
      <main className="epass-document">
        <Link to="/login" className="mb-8 inline-flex items-center gap-2 text-sm font-bold text-muted hover:text-ink">
          <ArrowLeft size={17} /> 返回登录
        </Link>
        {loading ? <p role="status" className="py-16 text-center text-muted">正在载入协议…</p> : document ? (
          <>
            <div className="mb-8 border-b border-line pb-6">
              <h1 className="font-editorial text-4xl font-normal">{document.title}</h1>
              <p className="mt-2 text-sm text-muted">版本 {document.version} · 发布于 {document.published_at ? new Date(document.published_at).toLocaleString('zh-CN') : '首次发布之日'}</p>
            </div>
            <article className="whitespace-pre-wrap break-words text-base leading-8 text-ink">{document.content}</article>
          </>
        ) : <p className="py-16 text-center text-danger">协议暂时无法载入，请稍后重试。</p>}
      </main>
    </PageChrome>
  );
}

export function BannedPage({ account }) {
  return (
    <PageChrome>
      <main className="epass-banned">
        <div className="mb-6 inline-flex items-center gap-2 text-sm font-medium text-danger"><Ban size={20} />账户访问受限</div>
        <h1 className="mt-7 font-editorial text-4xl font-normal">账户已被封禁</h1>
        <p className="mt-4 leading-7 text-muted">该账户目前无法登录 Rosemary Epass，也无法继续向已接入的平台授权。</p>
        {account ? <p className="mt-4 break-all rounded-panel bg-canvas px-4 py-3 text-sm text-muted">账户信息：{account}</p> : null}
        <div className="mt-7 rounded-panel border border-line bg-canvas p-5 text-left text-sm leading-7 text-muted">
          如认为处置有误，请发送邮件至 <a className="font-bold text-ink underline" href="mailto:info@rosemaryisland.pro">info@rosemaryisland.pro</a>，并提供账户信息、事实说明与申诉理由。
        </div>
        <a href="mailto:info@rosemaryisland.pro" className="btn-primary mt-7 inline-flex w-full items-center justify-center gap-2 py-4 font-bold">提交申诉 <ExternalLink size={17} /></a>
        <Link to="/login" className="mt-5 inline-block text-sm font-bold text-muted hover:text-ink">返回登录页</Link>
      </main>
    </PageChrome>
  );
}
