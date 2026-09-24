import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { roleHomePath, useAuthStore } from "../store/authStore";

const initialForm = {
  name: "",
  email: "",
  phone: "",
  password: "",
  role: "customer",
};

const roleOptions = [
  { value: "customer", label: "Customer" },
  { value: "shop_owner", label: "Shop Owner" },
  { value: "admin", label: "Admin" },
];

function validate(form) {
  const errors = {};
  if (!form.name.trim()) errors.name = "Enter your name.";
  if (!form.email.trim()) errors.email = "Enter an email address.";
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) {
    errors.email = "Enter a valid email address.";
  }
  if (!form.phone.trim()) errors.phone = "Enter a phone number.";
  else if (!/^[\d\s()+-]{7,}$/.test(form.phone.trim())) errors.phone = "Enter a valid phone number.";
  if (!form.password) errors.password = "Create a password.";
  else if (form.password.length < 6) errors.password = "Password must be at least 6 characters.";
  return errors;
}

function FieldError({ message }) {
  if (!message) return null;
  return <p className="mt-1.5 text-sm text-error">{message}</p>;
}

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

export function SignUp() {
  const navigate = useNavigate();
  const signUp = useAuthStore((state) => state.signUp);

  const [form, setForm] = useState(initialForm);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");
  const [needsEmailConfirmation, setNeedsEmailConfirmation] = useState(false);

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
      const { needsEmailConfirmation: pending, profile } = await signUp({
        email: form.email.trim(),
        password: form.password,
        name: form.name.trim(),
        phone: form.phone.trim(),
        role: form.role,
      });

      if (pending) {
        setNeedsEmailConfirmation(true);
        return;
      }
      navigate(roleHomePath(profile?.role ?? form.role), { replace: true });
    } catch (error) {
      setFormError(error.message || "Something went wrong creating your account.");
    } finally {
      setSubmitting(false);
    }
  }

  if (needsEmailConfirmation) {
    return (
      <Container className="py-16">
        <div className="mx-auto max-w-md text-center">
          <h1 className="font-display text-2xl font-bold text-ink">Check your email</h1>
          <p className="mt-3 text-[15px] text-ink-soft">
            We sent a confirmation link to <span className="text-ink">{form.email}</span>. Confirm your
            address, then log in to continue.
          </p>
          <Button to="/login" className="mt-8">
            Go to login
          </Button>
        </div>
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <div className="mx-auto max-w-md">
        <h1 className="font-display text-3xl font-bold text-ink">Create your account</h1>
        <p className="mt-2 text-[15px] text-ink-soft">
          Already have an account?{" "}
          <Link to="/login" className="text-primary hover:underline">
            Log in
          </Link>
        </p>

        <form onSubmit={handleSubmit} noValidate className="mt-8 flex flex-col gap-5">
          <div>
            <label htmlFor="name" className="block text-sm text-ink">
              Full name
            </label>
            <input
              id="name"
              type="text"
              autoComplete="name"
              value={form.name}
              onChange={(event) => updateField("name", event.target.value)}
              aria-invalid={Boolean(errors.name)}
              className={fieldClassName(Boolean(errors.name))}
            />
            <FieldError message={errors.name} />
          </div>

          <div>
            <label htmlFor="email" className="block text-sm text-ink">
              Email address
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
            <label htmlFor="phone" className="block text-sm text-ink">
              Phone number
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

          <div>
            <label htmlFor="password" className="block text-sm text-ink">
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="new-password"
              value={form.password}
              onChange={(event) => updateField("password", event.target.value)}
              aria-invalid={Boolean(errors.password)}
              className={fieldClassName(Boolean(errors.password))}
            />
            <FieldError message={errors.password} />
          </div>

          <div>
            <label htmlFor="role" className="block text-sm text-ink">
              I am a
            </label>
            <select
              id="role"
              value={form.role}
              onChange={(event) => updateField("role", event.target.value)}
              className="mt-1.5 w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
            >
              {roleOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            <p className="mt-1.5 text-xs text-ink-soft">
              Demo/testing only — a real deployment shouldn't let anyone self-register as Admin.
            </p>
          </div>

          {formError && <p className="text-sm text-error">{formError}</p>}

          <Button type="submit" variant="accent" size="lg" disabled={submitting} className="mt-2 w-full">
            {submitting ? "Creating account…" : "Create account"}
          </Button>
        </form>
      </div>
    </Container>
  );
}
