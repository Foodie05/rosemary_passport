function versions(documents) {
  return documents?.terms && documents?.privacy
    ? `${documents.terms.version}/${documents.privacy.version}`
    : null;
}

// Resolve only the requested action; a second click cannot queue another action.
export function createLegalConsent({ getDocuments, onPrompt, onChange }) {
  let acceptedVersions = null;
  let pending = null;
  const isAccepted = () => acceptedVersions !== null && acceptedVersions === versions(getDocuments());
  const setAccepted = (accepted) => {
    acceptedVersions = accepted ? versions(getDocuments()) : null;
    onChange();
  };
  const settle = (accepted) => {
    if (!pending) return;
    const resolve = pending;
    pending = null;
    onPrompt(false);
    resolve(accepted);
  };
  return {
    isAccepted,
    setAccepted,
    request() {
      if (isAccepted()) return Promise.resolve(true);
      if (pending) return Promise.resolve(false);
      return new Promise((resolve) => {
        pending = resolve;
        onPrompt(true);
      });
    },
    accept() {
      if (!pending || !versions(getDocuments())) return;
      setAccepted(true);
      settle(true);
    },
    decline() { settle(false); },
  };
}
