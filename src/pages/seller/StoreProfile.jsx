import { useEffect, useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { supabase } from "../../lib/supabaseClient";
import { useAuthStore } from "../../store/authStore";
import { useMyShop } from "../../hooks/useMyShop";

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

const emptyForm = {
  name: "",
  address: "",
  phone: "",
  license_number: "",
  description: "",
  banner_url: "",
};

function formFromShop(shop) {
  return {
    name: shop.name ?? "",
    address: shop.address ?? "",
    phone: shop.phone ?? "",
    license_number: shop.license_number ?? "",
    description: shop.description ?? "",
    banner_url: shop.banner_url ?? "",
  };
}

function validate(form) {
  const errors = {};
  if (!form.name.trim()) errors.name = "Enter your shop's name.";
  if (!form.address.trim()) errors.address = "Enter your shop's address.";
  if (!form.phone.trim()) errors.phone = "Enter a contact phone number.";
  if (!form.license_number.trim()) errors.license_number = "Enter your license number.";
  return errors;
}

const shopStatusLabel = {
  approved: "Approved",
  pending: "Pending approval",
  suspended: "Suspended",
};

export function SellerStoreProfile() {
  const userId = useAuthStore((state) => state.session?.user?.id);
  const { shop, loading, refetch } = useMyShop();

  const [form, setForm] = useState(emptyForm);
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (shop) setForm(formFromShop(shop));
  }, [shop]);

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
    setSaved(false);
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    setSaved(false);
    const validationErrors = validate(form);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const payload = {
        name: form.name.trim(),
        address: form.address.trim(),
        phone: form.phone.trim(),
        license_number: form.license_number.trim(),
        description: form.description.trim() || null,
        banner_url: form.banner_url.trim() || null,
      };

      if (shop) {
        const { error } = await supabase.from("shops").update(payload).eq("id", shop.id);
        if (error) throw error;
        setSaved(true);
      } else {
        const { error } = await supabase.from("shops").insert({ ...payload, owner_id: userId });
        if (error) throw error;
      }
      await refetch();
    } catch (submitError) {
      setFormError(submitError.message || "Something went wrong saving your shop profile.");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <Container className="py-12">
        <p className="text-[15px] text-ink-soft">Loading…</p>
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <div className="mx-auto max-w-2xl">
        <h1 className="font-display text-3xl font-bold text-ink">{shop ? "Shop profile" : "Set up your shop"}</h1>
        <p className="mt-2 text-[15px] text-ink-soft">
          {shop
            ? "Keep your shop's details up to date. Customers see this information across Paws Nearby."
            : "Tell us about your shop. An admin will review and approve it before it goes live."}
        </p>

        {shop && (
          <div className="mt-6 flex flex-wrap items-center gap-x-8 gap-y-2 rounded-xl border border-border bg-surface px-5 py-4">
            <div>
              <p className="text-sm text-ink-soft">Status</p>
              <p className={`text-[15px] font-medium ${shop.status === "approved" ? "text-trust" : shop.status === "suspended" ? "text-error" : "text-ink"}`}>
                {shopStatusLabel[shop.status] ?? shop.status}
              </p>
            </div>
            <div>
              <p className="text-sm text-ink-soft">License number</p>
              <p className="text-[15px] text-ink">{shop.license_number}</p>
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit} noValidate className="mt-8 flex flex-col gap-5">
          <div>
            <label htmlFor="name" className="block text-sm text-ink">
              Shop name
            </label>
            <input
              id="name"
              type="text"
              value={form.name}
              onChange={(event) => updateField("name", event.target.value)}
              aria-invalid={Boolean(errors.name)}
              className={fieldClassName(Boolean(errors.name))}
            />
            {errors.name && <p className="mt-1.5 text-sm text-error">{errors.name}</p>}
          </div>

          <div>
            <label htmlFor="address" className="block text-sm text-ink">
              Address
            </label>
            <input
              id="address"
              type="text"
              value={form.address}
              onChange={(event) => updateField("address", event.target.value)}
              aria-invalid={Boolean(errors.address)}
              className={fieldClassName(Boolean(errors.address))}
            />
            {errors.address && <p className="mt-1.5 text-sm text-error">{errors.address}</p>}
          </div>

          <div>
            <label htmlFor="phone" className="block text-sm text-ink">
              Phone number
            </label>
            <input
              id="phone"
              type="tel"
              value={form.phone}
              onChange={(event) => updateField("phone", event.target.value)}
              aria-invalid={Boolean(errors.phone)}
              className={fieldClassName(Boolean(errors.phone))}
            />
            {errors.phone && <p className="mt-1.5 text-sm text-error">{errors.phone}</p>}
          </div>

          <div>
            <label htmlFor="license_number" className="block text-sm text-ink">
              License number
            </label>
            <input
              id="license_number"
              type="text"
              value={form.license_number}
              onChange={(event) => updateField("license_number", event.target.value)}
              aria-invalid={Boolean(errors.license_number)}
              className={fieldClassName(Boolean(errors.license_number))}
            />
            {errors.license_number && <p className="mt-1.5 text-sm text-error">{errors.license_number}</p>}
          </div>

          <div>
            <label htmlFor="description" className="block text-sm text-ink">
              Description
            </label>
            <textarea
              id="description"
              rows={4}
              value={form.description}
              onChange={(event) => updateField("description", event.target.value)}
              className={fieldClassName(false)}
            />
          </div>

          <div>
            <label htmlFor="banner_url" className="block text-sm text-ink">
              Banner image URL
            </label>
            <input
              id="banner_url"
              type="url"
              value={form.banner_url}
              onChange={(event) => updateField("banner_url", event.target.value)}
              className={fieldClassName(false)}
            />
          </div>

          {formError && <p className="text-sm text-error">{formError}</p>}
          {saved && (
            <p className="flex items-center gap-3 text-sm text-trust">
              Saved.
              <button type="button" onClick={() => setSaved(false)} className="text-ink-soft underline">
                Dismiss
              </button>
            </p>
          )}

          <Button type="submit" variant="accent" size="lg" disabled={submitting} className="mt-2 w-full sm:w-auto">
            {submitting ? "Saving…" : shop ? "Save changes" : "Create shop"}
          </Button>
        </form>
      </div>
    </Container>
  );
}
