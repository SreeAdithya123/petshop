import { useEffect, useRef, useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { Field } from "../../components/ui/FormField";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { useMyShop } from "../../hooks/useMyShop";
import { formatPrice } from "../../lib/format";

const GENDER_OPTIONS = [
  { value: "", label: "Unknown" },
  { value: "Male", label: "Male" },
  { value: "Female", label: "Female" },
];

// StatusBadge has no dedicated tone for "reserved", so borrow the amber one.
const BADGE_STATUS = { reserved: "pending" };
const STATUS_LABELS = { available: "Available", reserved: "Reserved", sold: "Sold" };

const emptyForm = {
  name: "",
  gender: "",
  species: "",
  breed: "",
  age_months: "",
  price: "",
  description: "",
  photo_urls: "",
};

function petToForm(pet) {
  return {
    name: pet.name ?? "",
    gender: pet.gender ?? "",
    species: pet.species ?? "",
    breed: pet.breed ?? "",
    age_months: String(pet.age_months ?? ""),
    price: String(pet.price ?? ""),
    description: pet.description ?? "",
    photo_urls: (pet.photo_urls ?? []).join(", "),
  };
}

function formToPayload(form) {
  return {
    name: form.name.trim(),
    gender: form.gender || null,
    species: form.species.trim(),
    breed: form.breed.trim(),
    age_months: Number(form.age_months),
    price: Number(form.price),
    description: form.description.trim() || null,
    photo_urls: form.photo_urls
      .split(",")
      .map((url) => url.trim())
      .filter(Boolean),
  };
}

function validate(form) {
  const errors = {};
  if (!form.name.trim()) errors.name = "Enter a name for this pet.";
  if (!form.species.trim()) errors.species = "Enter a species.";
  if (!form.breed.trim()) errors.breed = "Enter a breed.";
  if (!form.age_months.trim()) errors.age_months = "Enter the pet's age in months.";
  else if (Number.isNaN(Number(form.age_months)) || Number(form.age_months) < 0) {
    errors.age_months = "Enter a valid age in months.";
  }
  if (!form.price.trim()) errors.price = "Enter a price.";
  else if (Number.isNaN(Number(form.price)) || Number(form.price) < 0) errors.price = "Enter a valid price.";
  return errors;
}

export function SellerPets() {
  const { shop, loading: shopLoading, error: shopError } = useMyShop();
  const [pets, setPets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);

  const [formOpen, setFormOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(emptyForm);
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const [busyId, setBusyId] = useState(null);
  const [actionError, setActionError] = useState("");
  const formRef = useRef(null);

  const reload = () => setReloadKey((key) => key + 1);

  useEffect(() => {
    if (shopLoading) return undefined;
    if (!shop) {
      setLoading(false);
      return undefined;
    }

    let cancelled = false;

    async function loadPets() {
      const { data, error: queryError } = await supabase
        .from("pets")
        .select("*")
        .eq("shop_id", shop.id)
        .order("created_at", { ascending: false });
      if (cancelled) return;
      if (queryError) setError(queryError.message);
      else {
        setError(null);
        setPets(data || []);
      }
      setLoading(false);
    }

    loadPets();
    return () => {
      cancelled = true;
    };
  }, [shop, shopLoading, reloadKey]);

  useEffect(() => {
    if (formOpen) formRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [formOpen, editingId]);

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function resetForm() {
    setEditingId(null);
    setForm(emptyForm);
    setErrors({});
    setFormError("");
  }

  function openAddForm() {
    resetForm();
    setFormOpen(true);
  }

  function openEditForm(pet) {
    resetForm();
    setEditingId(pet.id);
    setForm(petToForm(pet));
    setFormOpen(true);
  }

  function closeForm() {
    resetForm();
    setFormOpen(false);
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    const validationErrors = validate(form);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const payload = formToPayload(form);
      const { error: saveError } = editingId
        ? await supabase.from("pets").update(payload).eq("id", editingId)
        : await supabase.from("pets").insert({ shop_id: shop.id, ...payload });
      if (saveError) throw saveError;

      closeForm();
      reload();
    } catch (submitError) {
      setFormError(submitError.message || "Something went wrong saving this pet.");
    } finally {
      setSubmitting(false);
    }
  }

  async function changeStatus(petId, status) {
    setActionError("");
    setBusyId(petId);
    const { error: updateError } = await supabase.from("pets").update({ status }).eq("id", petId);
    setBusyId(null);
    if (updateError) setActionError(updateError.message);
    else reload();
  }

  async function deletePet(petId) {
    if (!window.confirm("Delete this listing?")) return;
    setActionError("");
    setBusyId(petId);
    const { error: deleteError } = await supabase.from("pets").delete().eq("id", petId);
    setBusyId(null);
    if (deleteError) setActionError(deleteError.message);
    else reload();
  }

  if (!shopLoading && !shop) {
    return (
      <Container className="py-12">
        {shopError ? (
          <p className="text-[15px] text-error">Couldn't load your shop: {shopError}</p>
        ) : (
          <EmptyState
            title="You haven't set up your shop yet"
            description="Create your shop profile to start listing pets and products."
            action={
              <Button to="/seller/store" size="sm">
                Set up your shop
              </Button>
            }
          />
        )}
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <div className="flex items-center justify-between gap-4">
        <h1 className="font-display text-3xl font-bold text-ink">Pets</h1>
        <Button type="button" variant="accent" size="sm" disabled={!shop} onClick={formOpen ? closeForm : openAddForm}>
          {formOpen ? "Cancel" : "Add a pet"}
        </Button>
      </div>

      {formOpen && (
        <form
          ref={formRef}
          onSubmit={handleSubmit}
          noValidate
          className="mt-6 flex scroll-mt-6 flex-col gap-5 rounded-xl border border-border bg-surface p-6"
        >
          <h2 className="font-display text-lg font-semibold text-ink">{editingId ? "Edit pet" : "Add a pet"}</h2>

          <div className="grid gap-5 sm:grid-cols-2">
            <Field label="Name" htmlFor="name" error={errors.name}>
              <input
                id="name"
                type="text"
                value={form.name}
                onChange={(event) => updateField("name", event.target.value)}
                aria-invalid={Boolean(errors.name)}
                className={fieldClassName(Boolean(errors.name))}
              />
            </Field>

            <Field label="Gender" htmlFor="gender">
              <select
                id="gender"
                value={form.gender}
                onChange={(event) => updateField("gender", event.target.value)}
                className={fieldClassName(false)}
              >
                {GENDER_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </Field>

            <Field label="Species" htmlFor="species" error={errors.species}>
              <input
                id="species"
                type="text"
                value={form.species}
                onChange={(event) => updateField("species", event.target.value)}
                aria-invalid={Boolean(errors.species)}
                className={fieldClassName(Boolean(errors.species))}
              />
            </Field>

            <Field label="Breed" htmlFor="breed" error={errors.breed}>
              <input
                id="breed"
                type="text"
                value={form.breed}
                onChange={(event) => updateField("breed", event.target.value)}
                aria-invalid={Boolean(errors.breed)}
                className={fieldClassName(Boolean(errors.breed))}
              />
            </Field>

            <Field label="Age (months)" htmlFor="age_months" error={errors.age_months}>
              <input
                id="age_months"
                type="number"
                min="0"
                value={form.age_months}
                onChange={(event) => updateField("age_months", event.target.value)}
                aria-invalid={Boolean(errors.age_months)}
                className={fieldClassName(Boolean(errors.age_months))}
              />
            </Field>

            <Field label="Price (INR)" htmlFor="price" error={errors.price}>
              <input
                id="price"
                type="number"
                min="0"
                step="0.01"
                value={form.price}
                onChange={(event) => updateField("price", event.target.value)}
                aria-invalid={Boolean(errors.price)}
                className={fieldClassName(Boolean(errors.price))}
              />
            </Field>
          </div>

          <Field label="Description" htmlFor="description">
            <textarea
              id="description"
              rows={3}
              value={form.description}
              onChange={(event) => updateField("description", event.target.value)}
              className={fieldClassName(false)}
            />
          </Field>

          <Field label="Photo URLs" htmlFor="photo_urls" hint="Separate multiple URLs with commas.">
            <input
              id="photo_urls"
              type="text"
              placeholder="https://example.com/photo1.jpg, https://example.com/photo2.jpg"
              value={form.photo_urls}
              onChange={(event) => updateField("photo_urls", event.target.value)}
              className={fieldClassName(false)}
            />
          </Field>

          {formError && (
            <p role="alert" className="text-sm text-error">
              {formError}
            </p>
          )}

          <Button type="submit" variant="accent" size="md" disabled={submitting} className="sm:w-auto">
            {submitting ? "Saving…" : editingId ? "Save changes" : "Add pet"}
          </Button>
        </form>
      )}

      {actionError && (
        <p role="alert" className="mt-6 text-sm text-error">
          {actionError}
        </p>
      )}

      {shopLoading || loading ? (
        <p className="mt-8 text-[15px] text-ink-soft">Loading…</p>
      ) : error ? (
        <p className="mt-8 text-sm text-error">Couldn't load your pets: {error}</p>
      ) : pets.length === 0 && !formOpen ? (
        <div className="mt-8">
          <EmptyState title="No pets listed yet" description="Add your first pet to start reaching customers." />
        </div>
      ) : pets.length > 0 ? (
        <div className="mt-8 divide-y divide-border rounded-xl border border-border bg-surface">
          {pets.map((pet) => (
            <div key={pet.id} className="flex flex-wrap items-center justify-between gap-x-6 gap-y-3 px-5 py-4">
              <div className="min-w-0 flex-1 basis-56">
                <p className="text-[15px] font-medium text-ink">
                  {pet.name && (
                    <>
                      <span className="font-semibold">{pet.name}</span> <span className="text-ink-soft">&middot;</span>{" "}
                    </>
                  )}
                  {pet.breed} <span className="text-ink-soft">({pet.species})</span>
                </p>
                <p className="text-sm text-ink-soft">
                  {[pet.gender, `${pet.age_months} months old`].filter(Boolean).join(" · ")}
                </p>
              </div>
              <p className="text-[15px] font-medium text-accent">{formatPrice(pet.price)}</p>
              <StatusBadge status={BADGE_STATUS[pet.status] ?? pet.status} label={STATUS_LABELS[pet.status]} />
              <div className="flex flex-wrap items-center gap-2">
                {pet.status === "available" && (
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    disabled={busyId === pet.id}
                    onClick={() => changeStatus(pet.id, "sold")}
                  >
                    Mark sold
                  </Button>
                )}
                {pet.status === "reserved" && (
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    disabled={busyId === pet.id}
                    onClick={() => changeStatus(pet.id, "available")}
                  >
                    Mark available
                  </Button>
                )}
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  disabled={busyId === pet.id}
                  onClick={() => openEditForm(pet)}
                >
                  Edit
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  disabled={busyId === pet.id}
                  onClick={() => deletePet(pet.id)}
                >
                  Delete
                </Button>
              </div>
            </div>
          ))}
        </div>
      ) : null}
    </Container>
  );
}
