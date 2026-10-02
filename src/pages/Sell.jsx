import { CheckCircle } from "@phosphor-icons/react";
import { useState } from "react";
import { AccountPageHeader } from "../components/account/AccountPage";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { Field } from "../components/ui/FormField";
import { fieldClassName } from "../lib/styles";
import { roleHomePath, useAuthStore } from "../store/authStore";

const ROLE_NAMES = { shop_owner: "shop owner", admin: "admin" };

function validate(form) {
  const errors = {};
  if (!form.shopName.trim()) errors.shopName = "Enter your shop's name.";
  if (!form.contactName.trim()) errors.contactName = "Enter your name.";
  if (!form.email.trim()) errors.email = "Enter your email address.";
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) {
    errors.email = "Enter a valid email address.";
  }
  if (!form.phone.trim()) errors.phone = "Enter your phone number.";
  else if (!/^[\d\s()+-]{7,}$/.test(form.phone.trim())) errors.phone = "Enter a valid phone number.";
  if (!form.city.trim()) errors.city = "Enter your city.";
  return errors;
}

export function Sell() {
  const profile = useAuthStore((state) => state.profile);
  const sessionEmail = useAuthStore((state) => state.session?.user?.email);

  // Pre-fill what we already know about the signed-in customer.
  const [form, setForm] = useState(() => ({
    shopName: "",
    contactName: profile?.name ?? "",
    email: profile?.email ?? sessionEmail ?? "",
    phone: profile?.phone ?? "",
    city: "",
    licenseNumber: "",
    message: "",
  }));
  const [errors, setErrors] = useState({});
  const [submitted, setSubmitted] = useState(false);

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function handleSubmit(event) {
    event.preventDefault();
    const validationErrors = validate(form);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;
    setSubmitted(true);
  }

  // Shop owners and admins already have their own dashboards.
  if (profile && profile.role !== "customer") {
    return (
      <div>
        <AccountPageHeader title="Sell on PETSTA" />
        <EmptyState
          title={`You already have a ${ROLE_NAMES[profile.role] ?? profile.role} account`}
          description="Applications to list a shop are for customer accounts."
          action={
            <Button to={roleHomePath(profile.role)} size="sm">
              Go to your dashboard
            </Button>
          }
        />
      </div>
    );
  }

  if (submitted) {
    const firstName = form.contactName.trim().split(" ")[0];
    return (
      <div className="mx-auto max-w-lg py-10 text-center">
        <CheckCircle size={48} weight="fill" className="mx-auto text-primary" />
        <h1 className="mt-5 font-display text-2xl font-bold text-ink">Thanks, {firstName}</h1>
        <p className="mt-3 text-[15px] leading-relaxed text-ink-soft">
          Applications are reviewed by the PETSTA team, and a shop is only listed once it has been approved.
        </p>
        <Button to="/account" className="mt-8">
          Back to my account
        </Button>
      </div>
    );
  }

  return (
    <div>
      <AccountPageHeader
        title="Sell on PETSTA"
        description="PETSTA connects nearby buyers with real, local pet shops. Tell us about your shop and apply to list your available pets."
      />

      <ul className="mt-6 flex max-w-xl list-disc flex-col gap-3 pl-5 text-[15px] text-ink-soft">
        <li>You control which pets are listed and their prices.</li>
        <li>No listing fees while we're onboarding early shops.</li>
        <li>Buyers already know pickup and payment happen in person, so there's nothing to ship.</li>
        <li>Applications are reviewed by the PETSTA team before a shop goes live.</li>
      </ul>

      <form onSubmit={handleSubmit} noValidate className="mt-8 flex max-w-xl flex-col gap-5">
        <Field label="Shop name" htmlFor="shopName" error={errors.shopName}>
          <input
            id="shopName"
            type="text"
            value={form.shopName}
            onChange={(event) => updateField("shopName", event.target.value)}
            aria-invalid={Boolean(errors.shopName)}
            className={fieldClassName(Boolean(errors.shopName))}
          />
        </Field>

        <Field label="Your name" htmlFor="contactName" error={errors.contactName}>
          <input
            id="contactName"
            type="text"
            autoComplete="name"
            value={form.contactName}
            onChange={(event) => updateField("contactName", event.target.value)}
            aria-invalid={Boolean(errors.contactName)}
            className={fieldClassName(Boolean(errors.contactName))}
          />
        </Field>

        <div className="grid gap-5 sm:grid-cols-2">
          <Field label="Email" htmlFor="email" error={errors.email}>
            <input
              id="email"
              type="email"
              autoComplete="email"
              value={form.email}
              onChange={(event) => updateField("email", event.target.value)}
              aria-invalid={Boolean(errors.email)}
              className={fieldClassName(Boolean(errors.email))}
            />
          </Field>
          <Field label="Phone" htmlFor="phone" error={errors.phone}>
            <input
              id="phone"
              type="tel"
              autoComplete="tel"
              value={form.phone}
              onChange={(event) => updateField("phone", event.target.value)}
              aria-invalid={Boolean(errors.phone)}
              className={fieldClassName(Boolean(errors.phone))}
            />
          </Field>
        </div>

        <Field label="City" htmlFor="city" error={errors.city}>
          <input
            id="city"
            type="text"
            autoComplete="address-level2"
            value={form.city}
            onChange={(event) => updateField("city", event.target.value)}
            aria-invalid={Boolean(errors.city)}
            className={fieldClassName(Boolean(errors.city))}
          />
        </Field>

        <Field label="License number" htmlFor="licenseNumber" optional>
          <input
            id="licenseNumber"
            type="text"
            value={form.licenseNumber}
            onChange={(event) => updateField("licenseNumber", event.target.value)}
            className={fieldClassName(false)}
          />
        </Field>

        <Field label="Message" htmlFor="message" optional>
          <textarea
            id="message"
            rows={3}
            value={form.message}
            onChange={(event) => updateField("message", event.target.value)}
            className={fieldClassName(false)}
          />
        </Field>

        <Button type="submit" variant="accent" size="lg" className="mt-2 w-full">
          Send application
        </Button>
      </form>
    </div>
  );
}
