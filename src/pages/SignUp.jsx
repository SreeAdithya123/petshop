import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { fieldClassName } from "../lib/styles";
import {
  PASSWORD_HINT,
  authErrorMessage,
  isValidEmail,
  passwordProblem,
  roleHomePath,
  useAuthStore,
} from "../store/authStore";

const RESEND_COOLDOWN_SECONDS = 45;

const initialForm = {
  name: "",
  email: "",
  phone: "",
  password: "",
  confirm: "",
  role: "customer",
  agree: false,
};

const roleOptions = [
  { value: "customer", label: "Customer" },
  { value: "shop_owner", label: "Shop owner" },
];

const roleDescriptions = {
  customer: "Browse and reserve pets, buy supplies and book services and vet video consults.",
  shop_owner: "List your pets, products and services. Your shop is reviewed and approved before it goes live.",
};

function validate(form) {
  const errors = {};

  const name = form.name.trim();
  if (!name) errors.name = "Enter your name.";
  else if (name.length < 2) errors.name = "Your name looks too short.";
  else if (name.length > 80) errors.name = "Please use 80 characters or fewer.";

  const email = form.email.trim();
  if (!email) errors.email = "Enter your email address.";
  else if (!isValidEmail(email)) errors.email = "Enter a valid email address.";

  const phone = form.phone.trim();
  if (!phone) errors.phone = "Enter a phone number.";
  else {
    const digits = phone.replace(/\D/g, "");
    if (!/^\+?[\d\s().-]+$/.test(phone) || digits.length < 7 || digits.length > 15) {
      errors.phone = "Enter a valid phone number, for example +91 98765 43210.";
    }
  }

  const passwordIssue = passwordProblem(form.password);
  if (passwordIssue) errors.password = passwordIssue;
  if (!form.confirm) errors.confirm = "Re-enter your password.";
  else if (form.confirm !== form.password) errors.confirm = "Passwords don't match.";

  if (!form.agree) errors.agree = "Please agree to the Terms and Privacy Policy to continue.";
  return errors;
}

function FieldError({ message }) {
  if (!message) return null;
  return <p className="mt-1.5 text-sm text-error">{message}</p>;
}

export function SignUp() {
  const navigate = useNavigate();
  const signUp = useAuthStore((state) => state.signUp);
  const resendConfirmation = useAuthStore((state) => state.resendConfirmation);

  const [form, setForm] = useState(initialForm);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");

  // The address the confirmation link was sent to; set once sign-up succeeded
  // and the account is waiting for email confirmation.
  const [confirmEmail, setConfirmEmail] = useState("");
  const [resending, setResending] = useState(false);
  const [resendMessage, setResendMessage] = useState("");
  const [resendFailed, setResendFailed] = useState(false);
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    if (cooldown <= 0) return undefined;
    const timer = setTimeout(() => setCooldown((seconds) => seconds - 1), 1000);
    return () => clearTimeout(timer);
  }, [cooldown]);

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;
    setFormError("");
    const validationErrors = validate(form);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const email = form.email.trim();
      const { needsEmailConfirmation, profile } = await signUp({
        email,
        password: form.password,
        name: form.name.trim(),
        phone: form.phone.trim(),
        role: form.role,
      });

      if (needsEmailConfirmation) {
        setConfirmEmail(email);
        setCooldown(RESEND_COOLDOWN_SECONDS);
        return;
      }
      navigate(roleHomePath(profile?.role ?? form.role), { replace: true });
    } catch (error) {
      setFormError(authErrorMessage(error, "Something went wrong creating your account."));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleResend() {
    if (resending || cooldown > 0) return;
    setResending(true);
    setResendMessage("");
    setResendFailed(false);
    try {
      await resendConfirmation(confirmEmail);
      setResendMessage("We sent the email again. It can take a minute to arrive.");
      setCooldown(RESEND_COOLDOWN_SECONDS);
    } catch (error) {
      setResendMessage(authErrorMessage(error));
      setResendFailed(true);
    } finally {
      setResending(false);
    }
  }

  function handleWrongEmail() {
    setConfirmEmail("");
    setResendMessage("");
    setResendFailed(false);
    setCooldown(0);
  }

  if (confirmEmail) {
    return (
      <Container className="py-16">
        <div className="mx-auto max-w-md">
          <h1 className="font-display text-3xl font-bold text-ink">Check your email</h1>
          <div role="status" className="mt-6 rounded-xl border border-trust/30 bg-trust/5 p-4">
            <p className="font-medium text-ink">Almost there</p>
            <p className="mt-1 text-sm text-ink-soft">
              We sent a confirmation link to <span className="text-ink">{confirmEmail}</span>. Open it to confirm
              your address, then log in to continue. If you can't find it, check your spam folder.
            </p>
          </div>

          <div className="mt-6 flex flex-col gap-3">
            <Button to="/login" className="w-full">
              Go to log in
            </Button>
            <Button
              type="button"
              variant="outline"
              onClick={handleResend}
              disabled={resending || cooldown > 0}
              className="w-full"
            >
              {resending
                ? "Sending…"
                : cooldown > 0
                  ? `Resend email in ${cooldown}s`
                  : "Resend confirmation email"}
            </Button>
          </div>

          {resendMessage && (
            <p
              role={resendFailed ? "alert" : "status"}
              className={`mt-4 text-sm ${resendFailed ? "text-error" : "text-ink-soft"}`}
            >
              {resendMessage}
            </p>
          )}

          <button type="button" onClick={handleWrongEmail} className="mt-5 text-[15px] text-primary hover:underline">
            Wrong email address? Go back
          </button>
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
              maxLength={80}
              value={form.name}
              onChange={(event) => updateField("name", event.target.value)}
              disabled={submitting}
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
              disabled={submitting}
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
              maxLength={20}
              placeholder="+91 98765 43210"
              value={form.phone}
              onChange={(event) => updateField("phone", event.target.value)}
              disabled={submitting}
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
              disabled={submitting}
              aria-invalid={Boolean(errors.password)}
              className={fieldClassName(Boolean(errors.password))}
            />
            {errors.password ? <FieldError message={errors.password} /> : <p className="mt-1.5 text-xs text-ink-soft">{PASSWORD_HINT}</p>}
          </div>

          <div>
            <label htmlFor="confirm" className="block text-sm text-ink">
              Confirm password
            </label>
            <input
              id="confirm"
              type="password"
              autoComplete="new-password"
              value={form.confirm}
              onChange={(event) => updateField("confirm", event.target.value)}
              disabled={submitting}
              aria-invalid={Boolean(errors.confirm)}
              className={fieldClassName(Boolean(errors.confirm))}
            />
            <FieldError message={errors.confirm} />
          </div>

          <div>
            <label htmlFor="role" className="block text-sm text-ink">
              I am a
            </label>
            <select
              id="role"
              value={form.role}
              onChange={(event) => updateField("role", event.target.value)}
              disabled={submitting}
              className="mt-1.5 w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
            >
              {roleOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            <p className="mt-1.5 text-xs text-ink-soft">{roleDescriptions[form.role]}</p>
          </div>

          <div>
            <label htmlFor="agree" className="flex items-start gap-3 text-sm text-ink">
              <input
                id="agree"
                type="checkbox"
                checked={form.agree}
                onChange={(event) => updateField("agree", event.target.checked)}
                disabled={submitting}
                aria-invalid={Boolean(errors.agree)}
                className="mt-0.5 h-4 w-4 flex-none accent-primary"
              />
              <span>
                I agree to the{" "}
                <Link
                  to="/legal/terms"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary underline hover:opacity-80"
                >
                  Terms
                </Link>{" "}
                and{" "}
                <Link
                  to="/legal/privacy"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary underline hover:opacity-80"
                >
                  Privacy Policy
                </Link>
              </span>
            </label>
            <FieldError message={errors.agree} />
          </div>

          {formError && (
            <p role="alert" className="text-sm text-error">
              {formError}
            </p>
          )}

          <Button type="submit" variant="accent" size="lg" disabled={submitting} className="mt-2 w-full">
            {submitting ? "Creating account…" : "Create account"}
          </Button>
        </form>
      </div>
    </Container>
  );
}
