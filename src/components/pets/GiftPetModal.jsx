import { CheckCircle, Gift } from "@phosphor-icons/react";
import { useState } from "react";
import { formatPrice } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { useAuthStore } from "../../store/authStore";
import { Button } from "../ui/Button";
import { Field } from "../ui/FormField";
import { LoginPrompt } from "../ui/LoginPrompt";
import { Modal } from "../ui/Modal";

const MESSAGE_LIMIT = 300;
const INITIAL_FORM = { name: "", contact: "", message: "" };

/** Accepts an email address or a phone number (7-15 digits, common separators allowed). */
function isEmailOrPhone(value) {
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return true;
  const digits = value.replace(/\D/g, "");
  return /^[\d\s()+-]+$/.test(value) && digits.length >= 7 && digits.length <= 15;
}

/**
 * `onGifted` (optional) fires once the gift order is placed, so the page can
 * refresh the catalog — the pet is reserved and no longer for sale.
 */
export function GiftPetModal({ open, onClose, onGifted, pet, shop }) {
  const session = useAuthStore((state) => state.session);
  const profile = useAuthStore((state) => state.profile);
  const authStatus = useAuthStore((state) => state.status);

  const [form, setForm] = useState(INITIAL_FORM);
  const [errors, setErrors] = useState({});
  const [submitError, setSubmitError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [placed, setPlaced] = useState(null);

  if (!pet) return null;

  const isCustomerBlocked = Boolean(session && profile && profile.role !== "customer");

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: undefined }));
  }

  function handleClose() {
    if (submitting) return;
    setForm(INITIAL_FORM);
    setErrors({});
    setSubmitError("");
    setPlaced(null);
    onClose();
  }

  function validate() {
    const next = {};
    if (!form.name.trim()) next.name = "Enter the recipient's name.";
    const contact = form.contact.trim();
    if (!contact) next.contact = "Enter the recipient's email or phone number.";
    else if (!isEmailOrPhone(contact)) next.contact = "Enter a valid email address or phone number.";
    return next;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;

    const nextErrors = validate();
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    setSubmitError("");
    const recipientName = form.name.trim();
    const { error } = await supabase.rpc("place_pet_gift", {
      p_pet_id: pet.id,
      p_recipient_name: recipientName,
      p_recipient_contact: form.contact.trim(),
      p_message: form.message.trim() || null,
    });
    setSubmitting(false);

    if (error) {
      setSubmitError(error.message);
      return;
    }
    setPlaced({ recipientName });
    onGifted?.();
  }

  function renderBody() {
    if (authStatus === "loading") {
      return <p className="text-sm text-ink-soft">Checking your account…</p>;
    }
    if (!session) {
      return <LoginPrompt compact description={`to send ${pet.name} as a gift.`} />;
    }
    if (isCustomerBlocked) {
      return (
        <p className="text-sm text-ink-soft">
          Only customer accounts can send pets as gifts. Sign in with a customer account to continue.
        </p>
      );
    }

    if (placed) {
      return (
        <div className="flex flex-col items-center gap-3 py-2 text-center">
          <CheckCircle size={44} weight="fill" className="text-trust" />
          <h3 className="font-display text-xl font-bold text-ink">Gift reserved</h3>
          <p className="max-w-sm text-[15px] text-ink-soft">
            {pet.name} is now held for {placed.recipientName}. The shop will arrange pickup with you — you pay in
            person. You can follow it under My account → Orders.
          </p>
          <div className="mt-2 flex flex-wrap justify-center gap-2">
            <Button to="/account/orders">View my orders</Button>
            <Button variant="outline" onClick={handleClose}>
              Close
            </Button>
          </div>
        </div>
      );
    }

    return (
      <form onSubmit={handleSubmit} noValidate className="space-y-5">
        <div className="flex items-center justify-between gap-4 rounded-lg bg-paper px-4 py-3">
          <div className="min-w-0">
            <p className="truncate text-[15px] font-medium text-ink">{pet.name}</p>
            <p className="truncate text-sm text-ink-soft">{pet.breed}</p>
          </div>
          <p className="flex-none font-display text-lg font-semibold text-accent">{formatPrice(pet.price)}</p>
        </div>

        <Field label="Recipient name" htmlFor="gift-name" error={errors.name}>
          <input
            id="gift-name"
            type="text"
            autoComplete="off"
            maxLength={80}
            value={form.name}
            onChange={(event) => update("name", event.target.value)}
            className={fieldClassName(Boolean(errors.name))}
          />
        </Field>

        <Field
          label="Recipient email or phone"
          htmlFor="gift-contact"
          error={errors.contact}
          hint="So the shop can reach your recipient about the gift."
        >
          <input
            id="gift-contact"
            type="text"
            autoComplete="off"
            maxLength={120}
            value={form.contact}
            onChange={(event) => update("contact", event.target.value)}
            className={fieldClassName(Boolean(errors.contact))}
          />
        </Field>

        <Field
          label="Gift message"
          htmlFor="gift-message"
          optional
          hint={`${form.message.length}/${MESSAGE_LIMIT} characters`}
        >
          <textarea
            id="gift-message"
            rows={3}
            maxLength={MESSAGE_LIMIT}
            value={form.message}
            onChange={(event) => update("message", event.target.value)}
            placeholder="Write a note to go with the gift"
            className={fieldClassName(false)}
          />
        </Field>

        <p className="text-xs text-ink-soft">
          The pet is held for your recipient; the shop will arrange pickup with you and pay in person. Nothing is
          charged online, and shop contact details stay private.
        </p>

        {submitError && (
          <p role="alert" className="rounded-lg bg-error/10 px-3 py-2 text-sm text-error">
            {submitError}
          </p>
        )}

        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button type="button" variant="outline" onClick={handleClose} disabled={submitting}>
            Cancel
          </Button>
          <Button type="submit" variant="accent" disabled={submitting}>
            <Gift size={18} /> {submitting ? "Reserving gift…" : `Send as gift · ${formatPrice(pet.price)}`}
          </Button>
        </div>
      </form>
    );
  }

  return (
    <Modal
      open={open}
      onClose={handleClose}
      title="Send as a gift"
      description={shop ? `${pet.name} · sold by ${shop.name}` : pet.name}
    >
      {renderBody()}
    </Modal>
  );
}
