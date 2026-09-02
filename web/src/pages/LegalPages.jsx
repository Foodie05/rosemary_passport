import { ArrowLeft, Ban, ExternalLink, ShieldCheck } from 'lucide-react';
import { Link } from 'react-router-dom';
import { ThemeToggle } from '../theme';

function PageChrome({ children }) {
  return (
    <div className="min-h-dvh bg-sage-50 px-5 py-8 text-sage-900 sm:px-8">
      <div className="mx-auto flex max-w-4xl items-center justify-between">
        <Link to="/login" className="flex items-center gap-2 font-bold text-sage-700">
          <ShieldCheck size={24} /> ROSM Pass
        </Link>
        <ThemeToggle />
      </div>
      {children}
    </div>
  );
}

export function LegalDocumentPage({ document, loading }) {
  return (
    <PageChrome>
      <main className="mx-auto mt-8 max-w-4xl rounded-3xl border border-sage-200 bg-white p-6 shadow-sm sm:p-10">
        <Link to="/login" className="mb-8 inline-flex items-center gap-2 text-sm font-bold text-sage-500 hover:text-sage-800">
          <ArrowLeft size={17} /> 返回登录
        </Link>
        {loading ? <p className="py-16 text-center text-sage-500">正在载入协议…</p> : document ? (
          <>
            <div className="mb-8 border-b border-sage-100 pb-6">
              <h1 className="text-3xl font-bold">{document.title}</h1>
              <p className="mt-2 text-sm text-sage-500">版本 {document.version} · 发布于 {document.published_at ? new Date(document.published_at).toLocaleString('zh-CN') : '首次发布之日'}</p>
            </div>
            <article className="whitespace-pre-wrap text-[15px] leading-8 text-sage-800">{document.content}</article>
          </>
        ) : <p className="py-16 text-center text-red-600">协议暂时无法载入，请稍后重试。</p>}
      </main>
    </PageChrome>
  );
}

export function BannedPage({ account }) {
  return (
    <PageChrome>
      <main className="mx-auto mt-16 max-w-xl rounded-3xl border border-red-100 bg-white p-8 text-center shadow-xl shadow-sage-900/5 sm:p-12">
        <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-3xl bg-red-50 text-red-600"><Ban size={38} /></div>
        <h1 className="mt-7 text-3xl font-bold">账户已被封禁</h1>
        <p className="mt-4 leading-7 text-sage-600">该账户目前无法登录 ROSM Pass，也无法继续向已接入的平台授权。</p>
        {account ? <p className="mt-4 rounded-2xl bg-sage-50 px-4 py-3 text-sm text-sage-600">账户信息：{account}</p> : null}
        <div className="mt-7 rounded-2xl border border-sage-200 bg-sage-50/70 p-5 text-left text-sm leading-7 text-sage-600">
          如认为处置有误，请发送邮件至 <a className="font-bold text-sage-900 underline" href="mailto:info@rosemaryisland.pro">info@rosemaryisland.pro</a>，并提供账户信息、事实说明与申诉理由。
        </div>
        <a href="mailto:info@rosemaryisland.pro" className="btn-primary mt-7 inline-flex w-full items-center justify-center gap-2 py-4 font-bold">提交申诉 <ExternalLink size={17} /></a>
        <Link to="/login" className="mt-5 inline-block text-sm font-bold text-sage-500 hover:text-sage-800">返回登录页</Link>
      </main>
    </PageChrome>
  );
}
