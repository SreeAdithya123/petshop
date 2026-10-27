import { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { fieldClassName } from "../../lib/styles";
import { authErrorMessage, isValidEmail, useAuthStore } from "../../store/authStore";

const RESEND_COOLDOWN_SECONDS = 60;

/**
 * "Forgot password?": asks for an email address and sends a reset link that
 * opens /reset-password. The wording never reveals whether an account exists
 * for the address.
 */
export function ForgotPassword() {
  const location = useLocation();
  const resetPassword = useAuthStore((state) => state.resetPassword);

  // The log in page passes whatever the visitor already typed.
  const [email, setEmail] = useState(() => (isValidEmail(location.state?.email) ? location.state.email.trim() : ""));
  const [emailError, setEmailError] = useState("");
  const [formError, setFormError] = useState("");
  const [sentTo, setSentTo] = useState("");
  const [cooldown, setCooldown] = useState(0);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (cooldown <= 0) return undefined;
    const timer = setTimeout(() => setCooldown((seconds) => seconds - 1), 1000);
    return () => clearTimeout(timer);
  }, [cooldown]);

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting || cooldown > 0) return;
    setFormError("");

    const trimmed = email.trim();
    const problem = !trimmed
      ? "Enter your email address."
      : !isValidEmail(trimmed)
        ? "Enter a valid email address."
        : "";
    setEmailError(problem);
    if (problem) return;

    setSubmitting(true);
    try {
      await resetPassword(trimmed);
      setSentTo(trimmed);
      setCooldown(RESEND_COOLDOWN_SECONDS);
    } catch (error) {
      setFormError(authErrorMessage(error, "Couldn't send the reset link. Please try again."));
    } finally {
      setSubmitting(false);
    }
  }

  let buttonLabel = "Send reset link";
  if (submitting) buttonLabel = "Sending…";
  else if (sentTo) buttonLabel = cooldown > 0 ? `Send again in ${cooldown}s` : "Send the link again";

  return (
    <Container className="py-16">
      <div className="mx-auto max-w-md">
        <h1 className="font-display text-3xl font-bold text-ink">Forgot your password?</h1>
        {!sentTo && (
          <p className="mt-2 text-[15px] text-ink-soft">
            Enter the email address you signed up with and we'll send you a link to choose a new password.
          </p>
        )}

        {sentTo && (
          <div role="status" className="mt-6 rounded-xl border border-trust/30 bg-trust/5 p-4">
            <p className="font-medium text-ink">Check your email</p>
            <p className="mt-1 text-sm text-ink-soft">
              If an account exists for <span className="text-ink">{sentTo}</span>, we've emailed a reset link. It can
              take a minute to arrive, so check your spam folder too.
            </p>
          </div>
        )}

        <form onSubmit={handleSubmit} noValidate className="mt-6 flex flex-col gap-5">
          <div>
            <label htmlFor="email" className="block text-sm text-ink">
              Email address
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              disabled={submitting}
              aria-invalid={Boolean(emailError)}
              className={fieldClassName(Boolean(emailError))}
            />
            {emailError && <p className="mt-1.5 text-sm text-error">{emailError}</p>}
          </div>

          {formError && (
            <p role="alert" className="text-sm text-error">
              {formError}
            </p>
          )}

          <Button type="submit" variant="accent" size="lg" disabled={submitting || cooldown > 0} className="w-full">
            {buttonLabel}
          </Button>
        </form>

        <p className="mt-6 text-[15px]">
          <Link to="/login" className="text-primary hover:underline">
            Back to log in
          </Link>
        </p>
      </div>
    </Container>
  );
}
