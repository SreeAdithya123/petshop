import { useEffect, useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { supabase } from "../../lib/supabaseClient";
import { useMyShop } from "../../hooks/useMyShop";
import { formatPrice } from "../../lib/format";

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

const statusStyles = {
  available: "text-trust",
  reserved: "text-ink-soft",
  sold: "text-error",
};

const emptyForm = {
  species: "",
  breed: "",
  age_months: "",
  price: "",
  description: "",
  photo_urls: "",
};

function validate(form) {
  const errors = {};
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
  const { shop, loading: shopLoading } = useMyShop();
  const [pets, setPets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function loadPets(shopId) {
    setLoading(true);
    const { data, error: queryError } = await supabase
      .from("pets")
      .select("*")
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false });
    if (queryError) setError(queryError.message);
    else {
      setError(null);
      setPets(data || []);
    }
    setLoading(false);
  }

  useEffect(() => {
    if (shop) loadPets(shop.id);
    else setLoading(false);
  }, [shop]);

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    const validationErrors = validate(form);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const photoUrls = form.photo_urls
        .split(",")
        .map((url) => url.trim())
        .filter(Boolean);

      const { error: insertError } = await supabase.from("pets").insert({
        shop_id: shop.id,
        species: form.species.trim(),
        breed: form.breed.trim(),
        age_months: Number(form.age_months),
        price: Number(form.price),
        description: form.description.trim() || null,
        photo_urls: photoUrls,
      });
      if (insertError) throw insertError;

      setForm(emptyForm);
      setErrors({});
      setFormOpen(false);
      await loadPets(shop.id);
    } catch (submitError) {
      setFormError(submitError.message || "Something went wrong adding this pet.");
    } finally {
      setSubmitting(false);
    }
  }

  async function markSold(petId) {
    const { error: updateError } = await supabase.from("pets").update({ status: "sold" }).eq("id", petId);
    if (!updateError) await loadPets(shop.id);
  }

  async function deletePet(petId) {
    if (!window.confirm("Delete this listing?")) return;
    const { error: deleteError } = await supabase.from("pets").delete().eq("id", petId);
    if (!deleteError) await loadPets(shop.id);
  }

  if (!shopLoading && !shop) {
    return (
      <Container className="py-12">
        <EmptyState
          title="You haven't set up your shop yet"
          description="Create your shop profile to start listing pets and products."
          action={
            <Button to="/seller/store" size="sm">
              Set up your shop
            </Button>
          }
        />
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <div className="flex items-center justify-between gap-4">
        <h1 className="font-display text-3xl font-bold text-ink">Pets</h1>
        <Button type="button" variant="accent" size="sm" onClick={() => setFormOpen((open) => !open)}>
          {formOpen ? "Cancel" : "Add a pet"}
        </Button>
      </div>

      {formOpen && (
        <form
          onSubmit={handleSubmit}
          noValidate
          className="mt-6 flex flex-col gap-5 rounded-xl border border-border bg-surface p-6"
        >
          <div className="grid gap-5 sm:grid-cols-2">
            <div>
              <label htmlFor="species" className="block text-sm text-ink">
                Species
              </label>
              <input
                id="species"
                type="text"
                value={form.species}
                onChange={(event) => updateField("species", event.target.value)}
                aria-invalid={Boolean(errors.species)}
                className={fieldClassName(Boolean(errors.species))}
              />
              {errors.species && <p className="mt-1.5 text-sm text-error">{errors.species}</p>}
            </div>

            <div>
              <label htmlFor="breed" className="block text-sm text-ink">
                Breed
              </label>
              <input
                id="breed"
                type="text"
                value={form.breed}
                onChange={(event) => updateField("breed", event.target.value)}
                aria-invalid={Boolean(errors.breed)}
                className={fieldClassName(Boolean(errors.breed))}
              />
              {errors.breed && <p className="mt-1.5 text-sm text-error">{errors.breed}</p>}
            </div>

            <div>
              <label htmlFor="age_months" className="block text-sm text-ink">
                Age (months)
              </label>
              <input
                id="age_months"
                type="number"
                min="0"
                value={form.age_months}
                onChange={(event) => updateField("age_months", event.target.value)}
                aria-invalid={Boolean(errors.age_months)}
                className={fieldClassName(Boolean(errors.age_months))}
              />
              {errors.age_months && <p className="mt-1.5 text-sm text-error">{errors.age_months}</p>}
            </div>

            <div>
              <label htmlFor="price" className="block text-sm text-ink">
                Price
              </label>
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
              {errors.price && <p className="mt-1.5 text-sm text-error">{errors.price}</p>}
            </div>
          </div>

          <div>
            <label htmlFor="description" className="block text-sm text-ink">
              Description
            </label>
            <textarea
              id="description"
              rows={3}
              value={form.description}
              onChange={(event) => updateField("description", event.target.value)}
              className={fieldClassName(false)}
            />
          </div>

          <div>
            <label htmlFor="photo_urls" className="block text-sm text-ink">
              Photo URLs
            </label>
            <input
              id="photo_urls"
              type="text"
              placeholder="https://example.com/photo1.jpg, https://example.com/photo2.jpg"
              value={form.photo_urls}
              onChange={(event) => updateField("photo_urls", event.target.value)}
              className={fieldClassName(false)}
            />
            <p className="mt-1.5 text-xs text-ink-soft">Separate multiple URLs with commas.</p>
          </div>

          {formError && <p className="text-sm text-error">{formError}</p>}

          <Button type="submit" variant="accent" size="md" disabled={submitting} className="sm:w-auto">
            {submitting ? "Adding…" : "Add pet"}
          </Button>
        </form>
      )}

      {loading ? (
        <p className="mt-8 text-[15px] text-ink-soft">Loading…</p>
      ) : error ? (
        <p className="mt-8 text-sm text-error">{error}</p>
      ) : pets.length === 0 && !formOpen ? (
        <div className="mt-8">
          <EmptyState title="No pets listed yet" description="Add your first pet to start reaching customers." />
        </div>
      ) : pets.length > 0 ? (
        <div className="mt-8 divide-y divide-border rounded-xl border border-border bg-surface">
          {pets.map((pet) => (
            <div key={pet.id} className="flex flex-wrap items-center justify-between gap-4 px-5 py-4">
              <div>
                <p className="text-[15px] font-medium text-ink">
                  {pet.breed} <span className="text-ink-soft">({pet.species})</span>
                </p>
                <p className="text-sm text-ink-soft">{pet.age_months} months old</p>
              </div>
              <p className="text-[15px] font-medium text-accent">{formatPrice(pet.price)}</p>
              <p className={`text-sm font-medium capitalize ${statusStyles[pet.status] ?? "text-ink-soft"}`}>
                {pet.status}
              </p>
              <div className="flex items-center gap-3">
                {pet.status === "available" && (
                  <Button type="button" variant="outline" size="sm" onClick={() => markSold(pet.id)}>
                    Mark sold
                  </Button>
                )}
                <Button type="button" variant="ghost" size="sm" onClick={() => deletePet(pet.id)}>
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
