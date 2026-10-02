import { useState } from "react";
import { Button } from "../ui/Button";
import { Modal } from "../ui/Modal";
import { Notice } from "./Notice";

/**
 * Confirm-before-you-act dialog. `onConfirm` resolves to an error message
 * (shown inside the dialog) or null on success, in which case the caller is
 * expected to close the dialog.
 */
export function ConfirmModal({
  title,
  description,
  confirmLabel,
  cancelLabel = "Cancel",
  destructive = false,
  onConfirm,
  onClose,
  children,
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function handleConfirm() {
    setBusy(true);
    setError("");
    const message = await onConfirm();
    setBusy(false);
    if (message) setError(message);
  }

  return (
    <Modal onClose={busy ? undefined : onClose} title={title} description={description} maxWidth="max-w-md">
      {children}
      {error && (
        <Notice tone="error" className="mt-4">
          {error}
        </Notice>
      )}
      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button type="button" variant="outline" size="sm" onClick={onClose} disabled={busy}>
          {cancelLabel}
        </Button>
        <Button
          type="button"
          size="sm"
          onClick={handleConfirm}
          disabled={busy}
          className={destructive ? "bg-error!" : ""}
        >
          {busy ? "Working…" : confirmLabel}
        </Button>
      </div>
    </Modal>
  );
}
