/** Pulsing placeholders shown while a seller list (and its summary tiles) loads. */
export function ListSkeleton({ tiles = 0, rows = 3 }) {
  return (
    <div role="status" aria-busy="true" className="flex flex-col gap-4">
      <span className="sr-only">Loading…</span>
      {tiles > 0 && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4">
          {Array.from({ length: tiles }, (_, index) => (
            <div key={index} className="h-20 animate-pulse rounded-xl border border-border bg-surface" />
          ))}
        </div>
      )}
      {Array.from({ length: rows }, (_, index) => (
        <div key={index} className="h-28 animate-pulse rounded-xl border border-border bg-surface" />
      ))}
    </div>
  );
}
