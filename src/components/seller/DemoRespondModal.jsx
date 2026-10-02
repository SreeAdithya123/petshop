import { useState } from "react";
import { fieldClassName } from "../../lib/styles";
import { toDateInputValue } from "../../lib/format";
import { Button } from "../ui/Button";
import { Field } from "../ui/FormField";
import { Modal } from "../ui/Modal";
import { CustomerContact } from "./CustomerContact";
import { formatSlot, isHttpsUrl, modeLabel, toTimeInputValue } from "./helpers";
import { updateRow } from "./mutations";
import { Notice } from "./Notice";

const DECISIONS_PENDING = [
  { value: "approve", label: "Approve", hint: "Confirm a date and time" },
  { value: "reject", label: "Reject", hint: "Decline with a reason" },
];

const DECISIONS_APPROVED = [
  { value: "complete", label: "Mark completed", hint: "The demo has happened" },
  { value: "update", label: "Update details", hint: "Change the slot or link" },
  { value: "reject", label: "Reject", hint: "Call it off with a reason" },
];

function validate(decision, form, demo) {
  const errors = {};
  const needsSlot = decision === "approve" || decision === "update";

  if (needsSlot) {
    if (!form.confirmed_date) errors.confirmed_date = "Pick the date.";
    else if (decision === "approve" && form.confirmed_date < toDateInputValue()) {
      errors.confirmed_date = "Pick today or a later date.";
    }
    if (!form.confirmed_time) errors.confirmed_time = "Pick the time.";

    const link = form.meet_link.trim();
    if (demo.mode === "video" && !link) errors.meet_link = "Add the video link for this demo.";
    else if (link && !isHttpsUrl(link)) errors.meet_link = "The link must start with https://";
  }

  if (decision === "reject" && !form.seller_note.trim()) {
    errors.seller_note = "Tell the customer why you can't do it.";
  }
  return errors;
}

/** Approve / reject a pending demo request, or complete / update / reject an approved one. */
export function DemoRespondModal({ demo, customer, onClose, onDone }) {
  const decisions = demo.status === "pending" ? DECISIONS_PENDING : DECISIONS_APPROVED;
  const [decision, setDecision] = useState(decisions[0].value);
  const [form, setForm] = useState(() => ({
    confirmed_date: demo.confirmed_date ?? demo.preferred_date ?? "",
    confirmed_time: toTimeInputValue(demo.confirmed_time ?? demo.preferred_time),
    meet_link: demo.meet_link ?? "",
    seller_note: demo.seller_note ?? "",
  }));
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const showSlot = decision === "approve" || decision === "update";
  const isVideo = demo.mode === "video";

  function updateField(field, value) {
    setForm((previous) => ({ ...previous, [field]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    const nextErrors = validate(decision, form, demo);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    const note = form.seller_note.trim() || null;
    const slot = {
      confirmed_date: form.confirmed_date,
      confirmed_time: form.confirmed_time,
      meet_link: form.meet_link.trim() || null,
      seller_note: note,
    };
    const patches = {
      approve: { status: "approved", ...slot },
      update: slot,
      complete: { status: "completed", seller_note: note },
      reject: { status: "rejected", seller_note: note },
    };

    setSubmitting(true);
    // Guard on the status this screen was showing so a stale tab can't overwrite a newer decision.
    const failure = await updateRow("demo_requests", demo.id, patches[decision], { status: demo.status });
    setSubmitting(false);

    if (failure) {
      setFormError(failure);
      return;
    }
    onDone();
  }

  return (
    <Modal onClose={submitting ? undefined : onClose} title="Respond to demo request" description={demo.pet_name}>
      <div className="rounded-lg bg-paper px-3 py-2 text-sm text-ink">
        <p>
          <CustomerContact profile={customer} />
        </p>
        <p className="mt-1 text-ink-soft">
          Asked for {formatSlot(demo.preferred_date, demo.preferred_time)} &middot; {modeLabel(demo.mode)}
        </p>
        {demo.message && <p className="mt-1 whitespace-pre-line">&ldquo;{demo.message}&rdquo;</p>}
      </div>

      <form onSubmit={handleSubmit} noValidate className="mt-5 flex flex-col gap-5">
        <fieldset>
          <legend className="text-sm text-ink">Your decision</legend>
          <div className="mt-1.5 grid gap-2 sm:grid-cols-[repeat(auto-fit,minmax(9rem,1fr))]">
            {decisions.map((option) => (
              <label
                key={option.value}
                className={`cursor-pointer rounded-lg border px-3 py-2.5 text-sm transition-colors has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-primary ${
                  decision === option.value ? "border-primary bg-primary/5" : "border-border hover:bg-primary/5"
                }`}
              >
                <input
                  type="radio"
                  name="decision"
                  value={option.value}
                  checked={decision === option.value}
                  onChange={() => {
                    setDecision(option.value);
                    setErrors({});
                  }}
                  className="sr-only"
                />
                <span className="block font-medium text-ink">{option.label}</span>
                <span className="block text-xs text-ink-soft">{option.hint}</span>
              </label>
            ))}
          </div>
        </fieldset>

        {showSlot && (
          <>
            <div className="grid gap-5 sm:grid-cols-2">
              <Field label="Confirmed date" htmlFor="demo-date" error={errors.confirmed_date}>
                <input
                  id="demo-date"
                  type="date"
                  min={decision === "approve" ? toDateInputValue() : undefined}
                  value={form.confirmed_date}
                  onChange={(event) => updateField("confirmed_date", event.target.value)}
                  aria-invalid={Boolean(errors.confirmed_date)}
                  className={fieldClassName(Boolean(errors.confirmed_date))}
                />
              </Field>
              <Field label="Confirmed time" htmlFor="demo-time" error={errors.confirmed_time}>
                <input
                  id="demo-time"
                  type="time"
                  value={form.confirmed_time}
                  onChange={(event) => updateField("confirmed_time", event.target.value)}
                  aria-invalid={Boolean(errors.confirmed_time)}
                  className={fieldClassName(Boolean(errors.confirmed_time))}
                />
              </Field>
            </div>

            <Field
              label={isVideo ? "Video link" : "Meeting link"}
              htmlFor="demo-link"
              error={errors.meet_link}
              hint={
                isVideo
                  ? "Paste a Google Meet/Zoom link; the customer sees it on their Services & Health pages."
                  : "Only needed if you want to share an online link as well."
              }
              optional={!isVideo}
            >
              <input
                id="demo-link"
                type="url"
                inputMode="url"
                placeholder="https://meet.google.com/..."
                value={form.meet_link}
                onChange={(event) => updateField("meet_link", event.target.value)}
                aria-invalid={Boolean(errors.meet_link)}
                className={fieldClassName(Boolean(errors.meet_link))}
              />
            </Field>
          </>
        )}

        <Field
          label={decision === "reject" ? "Reason for the customer" : "Note for the customer"}
          htmlFor="demo-note"
          error={errors.seller_note}
          hint="Shared with the customer. Please keep your shop's address and phone number out of it."
          optional={decision !== "reject"}
        >
          <textarea
            id="demo-note"
            rows={3}
            value={form.seller_note}
            onChange={(event) => updateField("seller_note", event.target.value)}
            aria-invalid={Boolean(errors.seller_note)}
            className={fieldClassName(Boolean(errors.seller_note))}
          />
        </Field>

        {formError && <Notice tone="error">{formError}</Notice>}

        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button type="button" variant="outline" size="sm" onClick={onClose} disabled={submitting}>
            Cancel
          </Button>
          <Button
            type="submit"
            variant="accent"
            size="sm"
            disabled={submitting}
            className={decision === "reject" ? "bg-error!" : ""}
          >
            {submitting ? "Saving…" : decisions.find((option) => option.value === decision).label}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
