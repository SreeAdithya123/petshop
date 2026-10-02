/**
 * Compact loading / error / empty handling for lists that live inside a page
 * section (the full-page equivalents use EmptyState). Renders `children` once
 * there is something to show; a failed refresh keeps the stale rows and puts
 * the error above them.
 */
export function ListState({ loading, error, onRetry, isEmpty, emptyMessage, children }) {
  if (loading && isEmpty) {
    return (
      <div role="status" aria-label="Loading" className="space-y-3">
        <div className="h-24 animate-pulse rounded-xl bg-ink/5" />
        <div className="h-24 animate-pulse rounded-xl bg-ink/5" />
      </div>
    );
  }

  const errorNotice = error ? (
    <div
      role="alert"
      className="mb-3 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-error/30 bg-error/5 px-4 py-3 text-sm text-error"
    >
      <p>{error}</p>
      {onRetry && (
        <button type="button" onClick={onRetry} className="font-medium underline underline-offset-2">
          Try again
        </button>
      )}
    </div>
  ) : null;

  if (isEmpty) {
    return (
      <>
        {errorNotice}
        {!error && (
          <p className="rounded-xl border border-dashed border-border bg-surface px-5 py-8 text-center text-sm text-ink-soft">
            {emptyMessage}
          </p>
        )}
      </>
    );
  }

  return (
    <>
      {errorNotice}
      {children}
    </>
  );
}
