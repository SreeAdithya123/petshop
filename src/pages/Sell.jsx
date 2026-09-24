import { CheckCircle } from "@phosphor-icons/react";
import { useState } from "react";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";

const initialForm = {
  shopName: "",
  contactName: "",
  email: "",
  phone: "",
  city: "",
  licenseNumber: "",
  message: "",
};

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

function FieldError({ message }) {
  if (!message) return null;
  return <p className="mt-1.5 text-sm text-error">{message}</p>;
}

function fieldClassName(hasError) {
  const border = hasError ? "border-error" : "border-border";
  return `mt-1.5 w-full rounded-lg border ${border} bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none`;
}

export function Sell() {
  const [form, setForm] = useState(initialForm);
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

  if (submitted) {
    const firstName = form.contactName.trim().split(" ")[0];
    return (
      <Container className="py-16">
        <div className="mx-auto max-w-lg text-center">
          <CheckCircle size={48} weight="fill" className="mx-auto text-primary" />
          <h1 className="mt-5 font-display text-3xl font-semibold text-ink">Thanks, {firstName}</h1>
          <p className="mt-3 text-[15px] leading-relaxed text-ink-soft">
            We've received your application for {form.shopName} and will follow up at {form.email} within
            a few business days.
          </p>
          <Button to="/" className="mt-8">
            Back to home
          </Button>
        </div>
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <div className="grid gap-12 lg:grid-cols-[1fr_420px] lg:gap-16">
        <div className="max-w-xl">
          <h1 className="font-display text-3xl font-semibold text-ink md:text-4xl">List your shop</h1>
          <p className="mt-4 text-[15px] leading-relaxed text-ink-soft">
            Paws Nearby connects nearby buyers with real, local pet shops. Tell us a bit about your shop
            and we'll reach out to help you get your available pets listed.
          </p>
          <ul className="mt-6 flex list-disc flex-col gap-3 pl-5 text-[15px] text-ink-soft">
            <li>You control which pets are listed and their prices.</li>
            <li>No listing fees while we're onboarding early shops.</li>
            <li>Buyers already know pickup and payment happen in person, so there's nothing to ship.</li>
          </ul>
        </div>

        <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-5">
          <div>
            <label htmlFor="shopName" className="block text-sm font-medium text-ink">
              Shop name
            </label>
            <input
              id="shopName"
              type="text"
              value={form.shopName}
              onChange={(event) => updateField("shopName", event.target.value)}
              aria-invalid={Boolean(errors.shopName)}
              className={fieldClassName(Boolean(errors.shopName))}
            />
            <FieldError message={errors.shopName} />
          </div>

          <div>
            <label htmlFor="contactName" className="block text-sm font-medium text-ink">
              Your name
            </label>
            <input
              id="contactName"
              type="text"
              autoComplete="name"
              value={form.contactName}
              onChange={(event) => updateField("contactName", event.target.value)}
              aria-invalid={Boolean(errors.contactName)}
              className={fieldClassName(Boolean(errors.contactName))}
            />
            <FieldError message={errors.contactName} />
          </div>

          <div className="grid gap-5 sm:grid-cols-2">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-ink">
                Email
              </label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                value={form.email}
                onChange={(event) => updateField("email", event.target.value)}
                aria-invalid={Boolean(errors.email)}
                className={fieldClassName(Boolean(errors.email))}
              />
              <FieldError message={errors.email} />
            </div>
            <div>
              <label htmlFor="phone" className="block text-sm font-medium text-ink">
                Phone
              </label>
              <input
                id="phone"
                type="tel"
                autoComplete="tel"
                value={form.phone}
                onChange={(event) => updateField("phone", event.target.value)}
                aria-invalid={Boolean(errors.phone)}
                className={fieldClassName(Boolean(errors.phone))}
              />
              <FieldError message={errors.phone} />
            </div>
          </div>

          <div>
            <label htmlFor="city" className="block text-sm font-medium text-ink">
              City
            </label>
            <input
              id="city"
              type="text"
              autoComplete="address-level2"
              value={form.city}
              onChange={(event) => updateField("city", event.target.value)}
              aria-invalid={Boolean(errors.city)}
              className={fieldClassName(Boolean(errors.city))}
            />
            <FieldError message={errors.city} />
          </div>

          <div>
            <label htmlFor="licenseNumber" className="block text-sm font-medium text-ink">
              License number <span className="text-ink-soft">(optional)</span>
            </label>
            <input
              id="licenseNumber"
              type="text"
              value={form.licenseNumber}
              onChange={(event) => updateField("licenseNumber", event.target.value)}
              className={fieldClassName(false)}
            />
          </div>

          <div>
            <label htmlFor="message" className="block text-sm font-medium text-ink">
              Message <span className="text-ink-soft">(optional)</span>
            </label>
            <textarea
              id="message"
              rows={3}
              value={form.message}
              onChange={(event) => updateField("message", event.target.value)}
              className={fieldClassName(false)}
            />
          </div>

          <Button type="submit" variant="accent" size="lg" className="w-full mt-2">
            Send application
          </Button>
        </form>
      </div>
    </Container>
  );
}
