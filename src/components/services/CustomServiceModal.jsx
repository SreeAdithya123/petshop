import { CheckCircle } from "@phosphor-icons/react";
import { useState } from "react";
import { toDateInputValue } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { Button } from "../ui/Button";
import { Field } from "../ui/FormField";
import { Modal } from "../ui/Modal";
import { AccessNotice } from "./AccessNotice";
import { PET_SPECIES_OPTIONS, SERVICE_CATEGORIES } from "./serviceCategories";
import { useBookingAccess } from "./useBookingAccess";

/**
 * Ask nearby approved shops for a quote on something that isn't listed.
 * Render it only while open so each opening starts with a clean form.
 */
export function CustomServiceModal({ onClose, onSent, onViewMine }) {
  const access = useBookingAccess();
  const today = toDateInputValue();

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("");
  const [petName, setPetName] = useState("");
  const [petSpecies, setPetSpecies] = useState("");
  const [preferredDate, setPreferredDate] = useState("");
  const [budget, setBudget] = useState("");
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");
  const [sent, setSent] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");

    const nextErrors = {};
    if (!title.trim()) nextErrors.title = "Give your request a short title.";
    if (!description.trim()) nextErrors.description = "Describe what you need.";
    if (preferredDate && preferredDate < today) nextErrors.preferredDate = "Pick today or a later date.";
    if (budget !== "" && !(Number(budget) >= 0)) nextErrors.budget = "Enter an amount of 0 or more.";
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    try {
      const { error } = await supabase.from("custom_service_requests").insert({
        customer_id: access.userId,
        title: title.trim(),
        description: description.trim(),
        category: category || null,
        pet_name: petName.trim() || null,
        pet_species: petSpecies || null,
        preferred_date: preferredDate || null,
        budget: budget === "" ? null : Number(budget),
      });
      if (error) throw error;
      setSent(true);
      onSent?.();
    } catch (error) {
      setFormError(error.message || "Couldn't send your request. Try again.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal
      onClose={onClose}
      title={sent ? "Request sent" : "Request a custom service"}
      description={sent ? undefined : "Tell us what you need and nearby approved shops will reply with a quote."}
    >
      {sent ? (
        <div className="text-center">
          <CheckCircle size={48} weight="fill" className="mx-auto text-trust" aria-hidden="true" />
          <h3 className="mt-3 font-display text-xl font-bold text-ink">
            Request sent to nearby approved shops — they'll reply with a quote
          </h3>
          <p className="mt-2 text-[15px] text-ink-soft">
            You can accept or decline any quote under My bookings &amp; requests.
          </p>
          <div className="mt-6 flex flex-wrap justify-center gap-2">
            {onViewMine && <Button onClick={onViewMine}>View my requests</Button>}
            <Button variant="outline" onClick={onClose}>
              Done
            </Button>
          </div>
        </div>
      ) : !access.canBook ? (
        <AccessNotice access={access} action="send a custom service request" />
      ) : (
        <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-4">
          <Field label="Title" htmlFor="custom-title" error={errors.title}>
            <input
              id="custom-title"
              type="text"
              maxLength={120}
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              placeholder="e.g. Home visit grooming for a senior dog"
              aria-invalid={Boolean(errors.title)}
              className={fieldClassName(Boolean(errors.title))}
            />
          </Field>

          <Field label="What do you need?" htmlFor="custom-description" error={errors.description}>
            <textarea
              id="custom-description"
              rows={4}
              maxLength={1000}
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              aria-invalid={Boolean(errors.description)}
              className={fieldClassName(Boolean(errors.description))}
            />
          </Field>

          <Field label="Category" htmlFor="custom-category" optional>
            <select
              id="custom-category"
              value={category}
              onChange={(event) => setCategory(event.target.value)}
              className={fieldClassName(false)}
            >
              <option value="">Other / not sure</option>
              {SERVICE_CATEGORIES.map(({ value, label }) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </Field>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Field label="Pet's name" htmlFor="custom-pet-name" optional>
              <input
                id="custom-pet-name"
                type="text"
                maxLength={60}
                value={petName}
                onChange={(event) => setPetName(event.target.value)}
                className={fieldClassName(false)}
              />
            </Field>
            <Field label="Species" htmlFor="custom-pet-species" optional>
              <select
                id="custom-pet-species"
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

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Field label="Preferred date" htmlFor="custom-date" optional error={errors.preferredDate}>
              <input
                id="custom-date"
                type="date"
                min={today}
                value={preferredDate}
                onChange={(event) => setPreferredDate(event.target.value)}
                aria-invalid={Boolean(errors.preferredDate)}
                className={fieldClassName(Boolean(errors.preferredDate))}
              />
            </Field>
            <Field label="Budget (₹)" htmlFor="custom-budget" optional error={errors.budget}>
              <input
                id="custom-budget"
                type="number"
                inputMode="decimal"
                min="0"
                step="any"
                value={budget}
                onChange={(event) => setBudget(event.target.value)}
                aria-invalid={Boolean(errors.budget)}
                className={fieldClassName(Boolean(errors.budget))}
              />
            </Field>
          </div>

          {formError && (
            <p role="alert" className="text-sm text-error">
              {formError}
            </p>
          )}

          <div className="flex justify-end gap-2 pt-1">
            <Button type="button" variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" variant="accent" disabled={submitting}>
              {submitting ? "Sending…" : "Send request"}
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
