/**
 * Label + control + optional hint/error. Pass the control as children and
 * give it `id={htmlFor}` and `className={fieldClassName(Boolean(error))}`
 * (from lib/styles).
 */
export function Field({ label, htmlFor, error, hint, optional = false, children, className = "" }) {
  return (
    <div className={className}>
      <label htmlFor={htmlFor} className="block text-sm text-ink">
        {label}
        {optional && <span className="text-ink-soft"> (optional)</span>}
      </label>
      {children}
      {hint && !error && <p className="mt-1.5 text-xs text-ink-soft">{hint}</p>}
      {error && <p className="mt-1.5 text-sm text-error">{error}</p>}
    </div>
  );
}
