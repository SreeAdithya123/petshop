import { Button } from "../ui/Button";

/** Heading + one-line helper (+ optional action) shared by every account page. */
export function AccountPageHeader({ title, description, action }) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-4">
      <div className="min-w-0">
        <h1 className="font-display text-2xl font-bold text-ink">{title}</h1>
        {description && <p className="mt-1.5 max-w-xl text-[15px] text-ink-soft">{description}</p>}
      </div>
      {action}
    </div>
  );
}

export function LoadingNote({ children = "Loading…" }) {
  return (
    <p role="status" className="mt-8 text-[15px] text-ink-soft">
      {children}
    </p>
  );
}

/** Load failure with the server's message and an optional retry. */
export function ErrorNote({ message, onRetry }) {
  return (
    <div
      role="alert"
      className="mt-8 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-error/30 bg-error/5 px-4 py-3"
    >
      <p className="text-sm text-error">{message}</p>
      {onRetry && (
        <Button variant="outline" size="sm" onClick={onRetry}>
          Try again
        </Button>
      )}
    </div>
  );
}
