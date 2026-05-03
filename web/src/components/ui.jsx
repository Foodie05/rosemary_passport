export function Panel({ title, description, actions, children }) {
  return (
    <section className="panel">
      <div className="panel-head">
        <div className="section-heading">
          <h2>{title}</h2>
          {description && <p>{description}</p>}
        </div>
        {actions}
      </div>
      {children}
    </section>
  );
}

export function Field({ label, children }) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  );
}

export function InfoPill({ label, value }) {
  return (
    <div className="info-pill">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export function InfoTile({ title, value, tone = 'neutral' }) {
  return (
    <article className={`info-tile ${tone}`}>
      <span>{title}</span>
      <strong>{value}</strong>
    </article>
  );
}

export function KeyValueList({ items }) {
  return (
    <div className="keyvalue-list">
      {items.map(([label, value]) => (
        <div key={label} className="keyvalue-row">
          <span>{label}</span>
          <strong title={`${value}`}>{value}</strong>
        </div>
      ))}
    </div>
  );
}

export function JsonBlock({ data, compact = false }) {
  return <pre className={compact ? 'json-block compact' : 'json-block'}>{JSON.stringify(data, null, 2)}</pre>;
}

export function EmptyState({ title, body }) {
  return (
    <div className="empty-state">
      <strong>{title}</strong>
      <p>{body}</p>
    </div>
  );
}

export function DecorBackdrop() {
  return (
    <div className="decor-backdrop" aria-hidden="true">
      <span className="blur blur-a" />
      <span className="blur blur-b" />
      <span className="grid-glow" />
    </div>
  );
}
