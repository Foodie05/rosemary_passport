// Retain only the active field element, never its value or credentials.
let activeField = null;
export function rememberField(node) { if (node?.id) activeField = node; }
export function fieldFeedbackTarget() {
  const node = activeField;
  return (message, tone = 'info') => {
    if (!node?.isConnected) return false;
    node.dispatchEvent(new CustomEvent('epass-field-feedback', { detail: { message, tone }, bubbles: false }));
    return true;
  };
}
export function publishFieldFeedback(message, tone) { return fieldFeedbackTarget()(message, tone); }

// Autofill can populate a form without focusing an editor first.
export function rememberActionField(button) {
  const adjacent = button.closest?.('.rm-field')?.querySelector('input');
  const form = button.form;
  const field = adjacent || (activeField?.isConnected && form?.contains(activeField) ? activeField : null) || form?.querySelector('input[autocomplete="one-time-code"]') || form?.querySelector('input[type="password"]') || form?.querySelector('input:not([type="hidden"]):not([type="checkbox"])');
  if (field) rememberField(field);
}
