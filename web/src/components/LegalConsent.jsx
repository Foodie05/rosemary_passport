import { FormaButton } from './Forma';
import { useEffect, useRef, useState } from 'react';
import { AnimatePresence } from 'motion/react';
import { Link } from '../design/NavigationMotion';
import { Dialog } from './Dialog';
import { createLegalConsent } from '../lib/legal-consent';

export function useLegalConsent(documents, loading, routeKey) {
  const currentDocuments = useRef(null);
  currentDocuments.current = loading ? null : documents;
  const [open, setOpen] = useState(false);
  const [, refresh] = useState(0);
  const gateRef = useRef(null);
  if (!gateRef.current) {
    gateRef.current = createLegalConsent({
      getDocuments: () => currentDocuments.current,
      onPrompt: setOpen,
      onChange: () => refresh((value) => value + 1),
    });
  }
  const gate = gateRef.current;
  // Leaving the current route cancels the request instead of replaying it later.
  useEffect(() => () => gate.decline(), [gate, routeKey]);
  return {
    legalAccepted: gate.isAccepted(),
    setLegalAccepted: gate.setAccepted,
    requestLegalAcceptance: gate.request,
    isLegalAccepted: gate.isAccepted,
    currentLegalDocuments: () => currentDocuments.current,
    legalPrompt: <AnimatePresence>{open && <Dialog
      key="legal-consent"
      title="是否接受使用条款与隐私政策？"
      onClose={gate.decline}
      actions={<>
        <FormaButton type="button" className="btn-secondary" onClick={gate.decline}>暂不接受</FormaButton>
        <FormaButton type="button" className="btn-primary" disabled={loading || !documents?.terms || !documents?.privacy} onClick={gate.accept}>接受并继续</FormaButton>
      </>}
    >
      <p className="leading-relaxed text-muted">继续前，请阅读并确认是否接受
        <Link to="/legal/terms" target="_blank" rel="noopener noreferrer" className="mx-1 font-bold text-ink underline underline-offset-4">《使用条款》</Link>与
        <Link to="/legal/privacy" target="_blank" rel="noopener noreferrer" className="mx-1 font-bold text-ink underline underline-offset-4">《隐私政策》</Link>。
      </p>
      <p className="mt-3 text-sm text-muted" role="status">{documents?.terms && documents?.privacy
        ? `版本 ${documents.terms.version}/${documents.privacy.version}`
        : loading ? '正在加载协议…' : '协议加载失败，请关闭弹窗并刷新页面后重试。'}</p>
    </Dialog>}</AnimatePresence>,
  };
}
