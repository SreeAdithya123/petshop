import { CheckCircle } from "@phosphor-icons/react";
import { useState } from "react";
import { formatDate, formatPrice } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { Button } from "../ui/Button";
import { Field } from "../ui/FormField";
import { Modal } from "../ui/Modal";
import { AccessNotice } from "./AccessNotice";
import {
  DELIVERY_MODES,
  PET_SPECIES_OPTIONS,
  TIME_SLOTS,
  formatDuration,
  formatTime,
  modesForCategory,
  tomorrowInputValue,
} from "./serviceCategories";
import { useBookingAccess } from "./useBookingAccess";

const MODE_HINTS = {
  in_person: "The shop will confirm the details with you once it accepts your booking.",
  video: "The clinic adds a video link to your booking once it confirms the slot.",
  phone: "The clinic will phone you on the number saved in your account.",
};

// "Pet: Bruno (Dog). Concern: limping since yesterday." — either part may be missing.
function composeConsultNotes({ petName, petSpecies, concern }) {
  const name = petName.trim();
  const pet = name && petSpecies ? `${name} (${petSpecies})` : name || petSpecies;
  const parts = [];
  if (pet) parts.push(`Pet: ${pet}.`);
  if (concern.trim()) parts.push(`Concern: ${concern.trim()}`);
  return parts.join(" ") || null;
}

/**
 * Book a slot on a service. `consult` switches to the vet teleconsultation
 * flavour: video pre-selected and pet / concern fields instead of free notes.
 * Render it only while open so each opening starts with a clean form.
 */
export function BookingModal({
  service,
  consult = false,
  onClose,
  onBooked,
  onViewMine,
  viewMineLabel = "View my bookings",
}) {
  const access = useBookingAccess();
  const modes = modesForCategory(service.category);
  const minDate = tomorrowInputValue();
  const provider = consult ? "clinic" : "shop";

  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  const [mode, setMode] = useState(consult && modes.includes("video") ? "video" : modes[0]);
  const [notes, setNotes] = useState("");
  const [petName, setPetName] = useState("");
  const [petSpecies, setPetSpecies] = useState("");
  const [concern, setConcern] = useState("");
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");
  const [booked, setBooked] = useState(false);

  const duration = formatDuration(service.duration_minutes);

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");

    const nextErrors = {};
    if (!date) nextErrors.date = "Pick a date.";
    else if (date < minDate) nextErrors.date = "Pick a date from tomorrow onwards.";
    if (!time) nextErrors.time = "Pick a time slot.";
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    try {
      const { error } = await supabase.from("service_bookings").insert({
        service_id: service.id,
        customer_id: access.userId,
        booking_date: date,
        booking_time: time,
        delivery_mode: mode,
        notes: consult ? composeConsultNotes({ petName, petSpecies, concern }) : notes.trim() || null,
      });
      if (error) throw error;
      setBooked(true);
      onBooked?.();
    } catch (error) {
      setFormError(error.message || "Couldn't book that slot. Try again.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal
      onClose={onClose}
      title={booked ? "Booking sent" : consult ? "Book a video consult" : "Book this service"}
      description={booked ? undefined : service.name}
    >
      {booked ? (
        <div className="text-center">
          <CheckCircle size={48} weight="fill" className="mx-auto text-trust" aria-hidden="true" />
          <h3 className="mt-3 font-display text-xl font-bold text-ink">Booked — the {provider} will confirm</h3>
          <p className="mt-2 text-[15px] text-ink-soft">
            {service.name} on {formatDate(date)} at {formatTime(time)} ({DELIVERY_MODES[mode].label.toLowerCase()}).{" "}
            {MODE_HINTS[mode]}
          </p>
          <div className="mt-6 flex flex-wrap justify-center gap-2">
            {onViewMine && <Button onClick={onViewMine}>{viewMineLabel}</Button>}
            <Button variant="outline" onClick={onClose}>
              Done
            </Button>
          </div>
        </div>
      ) : !access.canBook ? (
        <AccessNotice access={access} action={consult ? "book a consultation" : "book a service"} />
      ) : (
        <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-4">
          <div className="rounded-lg bg-paper p-3 text-sm">
            <p className="font-medium text-ink">{service.name}</p>
            <p className="mt-0.5 text-ink-soft">
              {[service.shops?.name && `by ${service.shops.name}`, duration, formatPrice(service.price)]
                .filter(Boolean)
                .join(" · ")}
            </p>
          </div>

          {consult && (
            <p className="rounded-lg border border-warning/40 bg-warning/10 p-3 text-sm text-ink">
              Emergency? Don't wait for a slot — go to your nearest vet clinic immediately.
            </p>
          )}

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Field label="Date" htmlFor="booking-date" error={errors.date}>
              <input
                id="booking-date"
                type="date"
                min={minDate}
                value={date}
                onChange={(event) => setDate(event.target.value)}
                aria-invalid={Boolean(errors.date)}
                className={fieldClassName(Boolean(errors.date))}
              />
            </Field>
            <Field label="Time" htmlFor="booking-time" error={errors.time}>
              <select
                id="booking-time"
                value={time}
                onChange={(event) => setTime(event.target.value)}
                aria-invalid={Boolean(errors.time)}
                className={fieldClassName(Boolean(errors.time))}
              >
                <option value="">Select a time</option>
                {TIME_SLOTS.map((slot) => (
                  <option key={slot} value={slot}>
                    {formatTime(slot)}
                  </option>
                ))}
              </select>
            </Field>
          </div>

          {modes.length > 1 ? (
            <fieldset>
              <legend className="block text-sm text-ink">How would you like to meet?</legend>
              <div className="mt-1.5 grid grid-cols-3 gap-2">
                {modes.map((value) => {
                  const { label, icon: ModeIcon } = DELIVERY_MODES[value];
                  return (
                    <label key={value} className="relative cursor-pointer">
                      <input
                        type="radio"
                        name="delivery-mode"
                        value={value}
                        checked={mode === value}
                        onChange={() => setMode(value)}
                        className="peer sr-only"
                      />
                      <span className="flex flex-col items-center gap-1 rounded-lg border border-border bg-surface px-2 py-3 text-center text-sm text-ink transition-colors peer-checked:border-primary peer-checked:bg-primary/5 peer-checked:text-primary peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-primary">
                        <ModeIcon size={20} aria-hidden="true" />
                        {label}
                      </span>
                    </label>
                  );
                })}
              </div>
              <p className="mt-1.5 text-xs text-ink-soft">{MODE_HINTS[mode]}</p>
            </fieldset>
          ) : (
            <p className="text-sm text-ink-soft">{MODE_HINTS.in_person}</p>
          )}

          {consult ? (
            <>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <Field label="Pet's name" htmlFor="booking-pet-name" optional>
                  <input
                    id="booking-pet-name"
                    type="text"
                    maxLength={60}
                    value={petName}
                    onChange={(event) => setPetName(event.target.value)}
                    className={fieldClassName(false)}
                  />
                </Field>
                <Field label="Species" htmlFor="booking-pet-species" optional>
                  <select
                    id="booking-pet-species"
                    value={petSpecies}
                    onChange={(event) => setPetSpecies(event.target.value)}
                    className={fieldClassName(false)}
                  >
                    <option value="">Select</option>
                    {PET_SPECIES_OPTIONS.map((species) => (
                      <option key={species} value={species}>
                        {species}
                      </option>
                    ))}
                  </select>
                </Field>
              </div>
              <Field
                label="What's the concern?"
                htmlFor="booking-concern"
                optional
                hint="Symptoms, how long they've lasted, anything the vet should know."
              >
                <textarea
                  id="booking-concern"
                  rows={3}
                  maxLength={500}
                  value={concern}
                  onChange={(event) => setConcern(event.target.value)}
                  className={fieldClassName(false)}
                />
              </Field>
            </>
          ) : (
            <Field label="Notes" htmlFor="booking-notes" optional>
              <textarea
                id="booking-notes"
                rows={3}
                maxLength={500}
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                placeholder="Anything the shop should know — your pet's name, temperament, preferences."
                className={fieldClassName(false)}
              />
            </Field>
          )}

          {formError && (
            <p role="alert" className="text-sm text-error">
              {formError}
            </p>
          )}

          <div className="flex justify-end gap-2 pt-1">
            <Button type="button" variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? "Booking…" : "Book this slot"}
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
