/** Small "label / value" grid used inside seller cards. */
export function MetaList({ children, className = "" }) {
  return <dl className={`grid gap-x-6 gap-y-3 sm:grid-cols-2 lg:grid-cols-3 ${className}`}>{children}</dl>;
}

export function Meta({ label, children }) {
  return (
    <div className="min-w-0">
      <dt className="text-xs text-ink-soft">{label}</dt>
      <dd className="mt-0.5 break-words text-sm text-ink">{children}</dd>
    </div>
  );
}
