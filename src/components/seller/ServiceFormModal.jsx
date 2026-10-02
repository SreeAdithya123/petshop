import { useState } from "react";
import { fieldClassName } from "../../lib/styles";
import { supabase } from "../../lib/supabaseClient";
import { Button } from "../ui/Button";
import { Field } from "../ui/FormField";
import { Modal } from "../ui/Modal";
import { SERVICE_CATEGORIES } from "./helpers";
import { updateRow } from "./mutations";
import { Notice } from "./Notice";

function toForm(service) {
  return {
    category: service?.category ?? SERVICE_CATEGORIES[0].value,
    name: service?.name ?? "",
    description: service?.description ?? "",
    price: service?.price != null ? String(service.price) : "",
    duration: service?.duration_minutes != null ? String(service.duration_minutes) : "",
  };
}

function validate(form) {
  const errors = {};
  if (!form.name.trim()) errors.name = "Enter a service name.";

  if (!form.price.trim()) errors.price = "Enter a price.";
  else if (!Number.isFinite(Number(form.price)) || Number(form.price) <= 0) {
    errors.price = "Price must be greater than zero.";
  }

  if (form.duration.trim()) {
    const minutes = Number(form.duration);
    if (!Number.isInteger(minutes) || minutes <= 0) errors.duration = "Enter whole minutes, like 45.";
  }
  return errors;
}

/** Add (service = null) or edit a service. Mount it fresh each time it opens. */
export function ServiceFormModal({ shopId, service = null, onClose, onSaved }) {
  const editing = Boolean(service);
  const [form, setForm] = useState(() => toForm(service));
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  function updateField(field, value) {
    setForm((previous) => ({ ...previous, [field]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    const nextErrors = validate(form);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    // Never send `status`: the database forces new services to "pending" and
    // blocks sellers from changing it.
    const fields = {
      category: form.category,
      name: form.name.trim(),
      description: form.description.trim(),
      price: Number(form.price),
      duration_minutes: form.duration.trim() ? Number(form.duration) : null,
    };

    let message = null;
    if (editing) {
      message = await updateRow("services", service.id, fields);
    } else {
      const { error } = await supabase.from("services").insert({ shop_id: shopId, ...fields });
      message = error ? error.message : null;
    }
    setSubmitting(false);

    if (message) {
      setFormError(message);
      return;
    }
    onSaved(editing ? "Service updated." : "Service submitted. New services go live after admin approval.");
  }

  return (
    <Modal
      onClose={submitting ? undefined : onClose}
      title={editing ? "Edit service" : "Add a service"}
      description={editing ? undefined : "New services go live after admin approval."}
    >
      <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-5">
        <div className="grid gap-5 sm:grid-cols-2">
          <Field label="Category" htmlFor="service-category">
            <select
              id="service-category"
              value={form.category}
              onChange={(event) => updateField("category", event.target.value)}
              className={fieldClassName(false)}
            >
              {SERVICE_CATEGORIES.map((category) => (
                <option key={category.value} value={category.value}>
                  {category.label}
                </option>
              ))}
            </select>
          </Field>

          <Field label="Service name" htmlFor="service-name" error={errors.name}>
            <input
              id="service-name"
              type="text"
              value={form.name}
              onChange={(event) => updateField("name", event.target.value)}
              aria-invalid={Boolean(errors.name)}
              className={fieldClassName(Boolean(errors.name))}
            />
          </Field>

          <Field label="Price (INR)" htmlFor="service-price" error={errors.price}>
            <input
              id="service-price"
              type="number"
              min="0"
              step="0.01"
              inputMode="decimal"
              value={form.price}
              onChange={(event) => updateField("price", event.target.value)}
              aria-invalid={Boolean(errors.price)}
              className={fieldClassName(Boolean(errors.price))}
            />
          </Field>

          <Field
            label="Duration (minutes)"
            htmlFor="service-duration"
            error={errors.duration}
            hint="How long one session takes."
            optional
          >
            <input
              id="service-duration"
              type="number"
              min="1"
              step="1"
              inputMode="numeric"
              value={form.duration}
              onChange={(event) => updateField("duration", event.target.value)}
              aria-invalid={Boolean(errors.duration)}
              className={fieldClassName(Boolean(errors.duration))}
            />
          </Field>
        </div>

        <Field label="Description" htmlFor="service-description" optional>
          <textarea
            id="service-description"
            rows={3}
            value={form.description}
            onChange={(event) => updateField("description", event.target.value)}
            className={fieldClassName(false)}
          />
        </Field>

        {formError && <Notice tone="error">{formError}</Notice>}

        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button type="button" variant="outline" size="sm" onClick={onClose} disabled={submitting}>
            Cancel
          </Button>
          <Button type="submit" variant="accent" size="sm" disabled={submitting}>
            {submitting ? "Saving…" : editing ? "Save changes" : "Add service"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
