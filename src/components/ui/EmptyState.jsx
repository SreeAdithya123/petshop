export function EmptyState({ title, description, action }) {
  return (
    <div className="flex flex-col items-center gap-3 py-20 text-center">
      <h3 className="font-display text-xl font-semibold text-ink">{title}</h3>
      {description && <p className="max-w-sm text-[15px] text-ink-soft">{description}</p>}
      {action}
    </div>
  );
}
