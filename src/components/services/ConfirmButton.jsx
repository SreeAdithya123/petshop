import { useState } from "react";

const buttonBase =
  "rounded-lg px-4 py-2 text-sm font-medium transition-colors active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50";

/** A destructive action that asks "are you sure?" inline before it fires. */
export function ConfirmButton({ label, confirmLabel, prompt = "Are you sure?", onConfirm, busy = false }) {
  const [confirming, setConfirming] = useState(false);

  if (!confirming) {
    return (
      <button
        type="button"
        disabled={busy}
        onClick={() => setConfirming(true)}
        className={`${buttonBase} border border-border text-ink hover:bg-primary/5`}
      >
        {busy ? "Working…" : label}
      </button>
    );
  }

  return (
    <span role="group" aria-label={prompt} className="inline-flex flex-wrap items-center gap-2">
      <span className="text-sm text-ink-soft">{prompt}</span>
      <button
        type="button"
        onClick={() => {
          setConfirming(false);
          onConfirm();
        }}
        className={`${buttonBase} bg-error text-white hover:opacity-90`}
      >
        {confirmLabel}
      </button>
      <button
        type="button"
        onClick={() => setConfirming(false)}
        className={`${buttonBase} text-primary hover:bg-primary/5`}
      >
        Keep
      </button>
    </span>
  );
}
