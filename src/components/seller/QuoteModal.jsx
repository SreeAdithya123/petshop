import { useState } from "react";
import { formatDate, formatPrice } from "../../lib/format";
import { fieldClassName } from "../../lib/styles";
import { Button } from "../ui/Button";
import { Field } from "../ui/FormField";
import { Modal } from "../ui/Modal";
import { categoryLabel } from "./helpers";
import { updateRow } from "./mutations";
import { Notice } from "./Notice";

/** Send a first quote on an open request, or revise a quote this shop already made. */
export function QuoteModal({ request, shopId, onClose, onSent }) {
  const revising = request.status === "quoted";
  const [price, setPrice] = useState(revising && request.quoted_price != null ? String(request.quoted_price) : "");
  const [message, setMessage] = useState(revising ? (request.response_message ?? "") : "");
  const [priceError, setPriceError] = useState("");
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");

    const amount = Number(price);
    if (!price.trim()) {
      setPriceError("Enter your price.");
      return;
    }
    if (!Number.isFinite(amount) || amount < 0) {
      setPriceError("Price can't be negative.");
      return;
    }
    setPriceError("");

    setSubmitting(true);
    const fields = { quoted_price: amount, response_message: message.trim() || null };
    // The database fills in the shop name and response time itself.
    const failure = revising
      ? await updateRow("custom_service_requests", request.id, fields, { status: "quoted", shop_id: shopId })
      : await updateRow(
          "custom_service_requests",
          request.id,
          { status: "quoted", shop_id: shopId, ...fields },
          { status: "open" },
        );
    setSubmitting(false);

    if (failure) {
      setFormError(failure);
      return;
    }
    onSent(revising ? "Quote updated." : "Quote sent. You'll see it here if the customer accepts.");
  }

  return (
    <Modal
      onClose={submitting ? undefined : onClose}
      title={revising ? "Revise your quote" : "Send a quote"}
      description={request.title}
    >
      <div className="rounded-lg bg-paper px-3 py-2 text-sm text-ink">
        <p className="whitespace-pre-line">{request.description}</p>
        <p className="mt-1 text-xs text-ink-soft">
          {[
            request.category ? categoryLabel(request.category) : null,
            request.budget != null ? `Budget ${formatPrice(request.budget)}` : null,
            request.preferred_date ? `Preferred ${formatDate(request.preferred_date)}` : null,
          ]
            .filter(Boolean)
            .join(" · ")}
        </p>
      </div>

      <form onSubmit={handleSubmit} noValidate className="mt-5 flex flex-col gap-5">
        <Field label="Your price (INR)" htmlFor="quote-price" error={priceError}>
          <input
            id="quote-price"
            type="number"
            min="0"
            step="0.01"
            inputMode="decimal"
            value={price}
            onChange={(event) => setPrice(event.target.value)}
            aria-invalid={Boolean(priceError)}
            className={fieldClassName(Boolean(priceError))}
          />
        </Field>

        <Field
          label="Message to the customer"
          htmlFor="quote-message"
          hint="Say what's included and when you can do it. Please keep phone numbers and addresses out of it."
          optional
        >
          <textarea
            id="quote-message"
            rows={4}
            value={message}
            onChange={(event) => setMessage(event.target.value)}
            className={fieldClassName(false)}
          />
        </Field>

        <p className="text-xs text-ink-soft">The customer sees your shop name, this price and your message.</p>

        {formError && <Notice tone="error">{formError}</Notice>}

        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button type="button" variant="outline" size="sm" onClick={onClose} disabled={submitting}>
            Cancel
          </Button>
          <Button type="submit" variant="accent" size="sm" disabled={submitting}>
            {submitting ? "Sending…" : revising ? "Update quote" : "Send quote"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
