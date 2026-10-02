export function SummaryTile({ label, value, className = "" }) {
  return (
    <div className={`rounded-xl border border-border bg-surface px-4 py-3 sm:px-5 sm:py-4 ${className}`}>
      <p className="text-sm text-ink-soft">{label}</p>
      <p className="mt-1 font-display text-xl font-semibold text-ink sm:text-2xl">{value}</p>
    </div>
  );
}
