import { useEffect, useState } from 'react';
import { Alert } from '@rosemary-ui/react';
export function FieldFeedback({ input, value }) {
  const [feedback, setFeedback] = useState(null);
  useEffect(() => {
    const node = input.current;
    const update = event => setFeedback(event.detail);
    node?.addEventListener('epass-field-feedback', update);
    return () => node?.removeEventListener('epass-field-feedback', update);
  }, [input]);
  useEffect(() => setFeedback(null), [value]);
  return feedback ? <Alert tone={feedback.tone === 'error' ? 'danger' : feedback.tone === 'success' ? 'success' : 'info'} role={feedback.tone === 'error' ? 'alert' : 'status'}>{feedback.message}</Alert> : null;
}
