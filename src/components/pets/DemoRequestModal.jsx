import { CheckCircle, Storefront, VideoCamera } from "@phosphor-icons/react";
import { useState } from "react";
import { formatDate, toDateInputValue } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { useAuthStore } from "../../store/authStore";
import { Button } from "../ui/Button";
import { Field } from "../ui/FormField";
import { LoginPrompt } from "../ui/LoginPrompt";
import { Modal } from "../ui/Modal";

const MODES = [
  { value: "video", label: "Video call", hint: "Meet the pet live, from wherever you are", icon: VideoCamera },
  {
    value: "in_person",
    label: "Visit the shop in person",
    hint: "The shop confirms visit details once they approve",
    icon: Storefront,
  },
];

// Hourly slots from 10:00 AM to 6:00 PM, stored as their label text.
const TIME_SLOTS = Array.from({ length: 9 }, (_, index) => {
  const hour = 10 + index;
  return `${hour > 12 ? hour - 12 : hour}:00 ${hour >= 12 ? "PM" : "AM"}`;
});

const MAX_DAYS_AHEAD = 30;
const INITIAL_FORM = { mode: "video", date: "", time: "", message: "" };

function dateInDays(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return toDateInputValue(date);
}

export function DemoRequestModal({ open, onClose, pet, shop }) {
  const session = useAuthStore((state) => state.session);
  const profile = useAuthStore((state) => state.profile);
  const authStatus = useAuthStore((state) => state.status);

  const [form, setForm] = useState(INITIAL_FORM);
  const [errors, setErrors] = useState({});
  const [submitError, setSubmitError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [requested, setRequested] = useState(null);

  if (!pet) return null;

  const minDate = dateInDays(1);
  const maxDate = dateInDays(MAX_DAYS_AHEAD);
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
    setRequested(null);
    onClose();
  }

  function validate() {
    const next = {};
    if (!form.date) next.date = "Choose a preferred date.";
    else if (form.date < minDate || form.date > maxDate) {
      next.date = `Pick a date between ${formatDate(minDate)} and ${formatDate(maxDate)}.`;
    }
    if (!form.time) next.time = "Choose a preferred time.";
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
    const { error } = await supabase.from("demo_requests").insert({
      customer_id: session.user.id,
      pet_id: pet.id,
      preferred_date: form.date,
      preferred_time: form.time,
      mode: form.mode,
      message: form.message.trim() || null,
    });
    setSubmitting(false);

    if (error) {
      setSubmitError(error.message);
      return;
    }
    setRequested({ mode: form.mode, date: form.date, time: form.time });
  }

  function renderBody() {
    if (authStatus === "loading") {
      return <p className="text-sm text-ink-soft">Checking your account…</p>;
    }
    if (!session) {
      return <LoginPrompt compact description={`to request a demo of ${pet.name}.`} />;
    }
    if (isCustomerBlocked) {
      return (
        <p className="text-sm text-ink-soft">
          Only customer accounts can request demos. Sign in with a customer account to meet {pet.name}.
        </p>
      );
    }

    if (requested) {
      const modeLabel = MODES.find((mode) => mode.value === requested.mode)?.label;
      return (
        <div className="flex flex-col items-center gap-3 py-2 text-center">
          <CheckCircle size={44} weight="fill" className="text-trust" />
          <h3 className="font-display text-xl font-bold text-ink">Demo requested</h3>
          <p className="max-w-sm text-[15px] text-ink-soft">
            The shop will confirm — track it under My account → Demo requests.
          </p>
          <p className="rounded-lg bg-paper px-4 py-2 text-sm text-ink">
            {pet.name} · {modeLabel} · {formatDate(requested.date)}, {requested.time}
          </p>
          <div className="mt-2 flex flex-wrap justify-center gap-2">
            <Button to="/account/demos">View my demo requests</Button>
            <Button variant="outline" onClick={handleClose}>
              Close
            </Button>
          </div>
        </div>
      );
    }

    return (
      <form onSubmit={handleSubmit} noValidate className="space-y-5">
        <fieldset className="min-w-0">
          <legend className="text-sm text-ink">How would you like to meet {pet.name}?</legend>
          <div className="mt-2 grid gap-2 sm:grid-cols-2">
            {MODES.map(({ value, label, hint, icon: Icon }) => (
              <label
                key={value}
                className="flex cursor-pointer items-start gap-3 rounded-lg border border-border p-3 transition-colors has-[:checked]:border-primary has-[:checked]:bg-primary/5 has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-primary/40"
              >
                <input
                  type="radio"
                  name="demo-mode"
                  value={value}
                  checked={form.mode === value}
                  onChange={() => update("mode", value)}
                  className="sr-only"
                />
                <Icon size={20} className="mt-0.5 flex-none text-primary" />
                <span>
                  <span className="block text-sm font-medium text-ink">{label}</span>
                  <span className="mt-0.5 block text-xs text-ink-soft">{hint}</span>
                </span>
              </label>
            ))}
          </div>
        </fieldset>

        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Preferred date" htmlFor="demo-date" error={errors.date}>
            <input
              id="demo-date"
              type="date"
              min={minDate}
              max={maxDate}
              value={form.date}
              onChange={(event) => update("date", event.target.value)}
              className={fieldClassName(Boolean(errors.date))}
            />
          </Field>
          <Field label="Preferred time" htmlFor="demo-time" error={errors.time}>
            <select
              id="demo-time"
              value={form.time}
              onChange={(event) => update("time", event.target.value)}
              className={fieldClassName(Boolean(errors.time))}
            >
              <option value="">Select a time</option>
              {TIME_SLOTS.map((slot) => (
                <option key={slot} value={slot}>
                  {slot}
                </option>
              ))}
            </select>
          </Field>
        </div>

        <Field label="Message" htmlFor="demo-message" optional>
          <textarea
            id="demo-message"
            rows={3}
            maxLength={500}
            value={form.message}
            onChange={(event) => update("message", event.target.value)}
            placeholder="Anything you'd like the shop to know?"
            className={fieldClassName(false)}
          />
        </Field>

        <p className="text-xs text-ink-soft">
          The shop will review your request and confirm a time with you. Pickup details are shared by the shop
          after they confirm — contact details stay private.
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
            {submitting ? "Sending request…" : "Request demo"}
          </Button>
        </div>
      </form>
    );
  }

  return (
    <Modal
      open={open}
      onClose={handleClose}
      title="Request a demo"
      description={shop ? `${pet.name} · sold by ${shop.name}` : pet.name}
    >
      {renderBody()}
    </Modal>
  );
}
