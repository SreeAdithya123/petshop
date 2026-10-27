import { Trash, Warning } from "@phosphor-icons/react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../../lib/supabaseClient";
import { useAuthStore } from "../../store/authStore";
import { Button } from "../ui/Button";
import { Modal } from "../ui/Modal";
import { rpcErrorMessage } from "./accountHelpers";

/** The word the customer has to type before an account can be deleted. */
const DELETE_WORD = "DELETE";

const DANGER_OUTLINE =
  "inline-flex items-center justify-center gap-2 rounded-lg border border-error/40 px-4 py-2 text-sm font-medium text-error transition-colors duration-150 hover:bg-error/5 disabled:pointer-events-none disabled:opacity-50 whitespace-nowrap";
const DANGER_SOLID =
  "inline-flex items-center justify-center gap-2 rounded-lg bg-error px-5 py-2.5 text-[15px] font-medium text-white transition-colors duration-150 hover:opacity-90 disabled:pointer-events-none disabled:opacity-50 whitespace-nowrap";

/**
 * "Danger zone" card on the profile page. Customers can delete their account;
 * shop owners and admins are pointed to support instead.
 */
export function DangerZone({ role }) {
  const navigate = useNavigate();
  const signOut = useAuthStore((state) => state.signOut);

  const [open, setOpen] = useState(false);
  const [confirmText, setConfirmText] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState("");

  const isCustomer = role === "customer";
  const confirmed = confirmText.trim() === DELETE_WORD;

  function openDialog() {
    setConfirmText("");
    setError("");
    setOpen(true);
  }

  function closeDialog() {
    if (!deleting) setOpen(false);
  }

  async function handleDelete(event) {
    event.preventDefault();
    if (deleting || !confirmed) return;
    setDeleting(true);
    setError("");

    try {
      const { error: rpcError } = await supabase.rpc("delete_my_account");
      if (rpcError) {
        setError(rpcErrorMessage(rpcError));
        setDeleting(false);
        return;
      }
    } catch (thrown) {
      setError(rpcErrorMessage(thrown));
      setDeleting(false);
      return;
    }

    // The account is gone on the server. Whatever happens to the sign-out
    // call, the local session must not outlive it. Leaving this page is the
    // last step, so nothing here updates this component's state any more.
    try {
      await signOut();
    } catch {
      useAuthStore.setState({ session: null, profile: null, status: "signed-out", passwordRecovery: false });
    }
    navigate("/", { replace: true });
  }

  return (
    <section className="rounded-xl border border-error/30 bg-error/5 p-5">
      <h2 className="flex items-center gap-2 font-display text-lg font-semibold text-error">
        <Warning size={20} aria-hidden="true" />
        Danger zone
      </h2>

      {isCustomer ? (
        <>
          <p className="mt-2 max-w-xl text-sm text-ink-soft">
            Delete your account and the personal data tied to it. Open orders are cancelled and your order history is
            anonymised. This can't be undone.
          </p>
          <button type="button" onClick={openDialog} className={`${DANGER_OUTLINE} mt-4`}>
            <Trash size={16} />
            Delete my account
          </button>
        </>
      ) : (
        <>
          <p className="mt-2 max-w-xl text-sm text-ink-soft">
            Contact support to close a shop or admin account. These accounts can't be deleted from the website.
          </p>
          <Button to="/support" variant="outline" size="sm" className="mt-4">
            Contact support
          </Button>
        </>
      )}

      {open && (
        <Modal onClose={closeDialog} title="Delete your account?" maxWidth="max-w-md">
          <form onSubmit={handleDelete} noValidate>
            <p className="text-[15px] text-ink-soft">This can't be undone. Here's what happens:</p>
            <ul className="mt-3 list-disc space-y-2 pl-5 text-[15px] text-ink-soft">
              <li>Any open orders are cancelled and their items go back to the shop.</li>
              <li>Your personal data is removed: your profile, saved addresses, wishlist and support messages.</li>
              <li>
                Past orders stay in the shop's records, but anonymised, without your name or contact details.
              </li>
            </ul>
            <p className="mt-3 text-[15px] font-medium text-ink">
              You'll be signed out straight away and won't be able to log in again.
            </p>

            <label htmlFor="delete-confirm" className="mt-5 block text-sm text-ink">
              Type <span className="font-semibold text-error">{DELETE_WORD}</span> to confirm
            </label>
            <input
              id="delete-confirm"
              type="text"
              autoComplete="off"
              autoCapitalize="characters"
              spellCheck={false}
              value={confirmText}
              onChange={(event) => setConfirmText(event.target.value.toUpperCase())}
              disabled={deleting}
              placeholder={DELETE_WORD}
              className="mt-1.5 w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-error focus:outline-none"
            />

            {error && (
              <p role="alert" className="mt-3 text-sm text-error">
                {error}
              </p>
            )}

            <div className="mt-6 flex flex-wrap justify-end gap-3">
              <Button type="button" variant="outline" onClick={closeDialog} disabled={deleting}>
                Keep my account
              </Button>
              <button type="submit" disabled={!confirmed || deleting} className={DANGER_SOLID}>
                {deleting ? "Deleting…" : "Delete account"}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </section>
  );
}
