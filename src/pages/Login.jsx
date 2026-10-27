import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { fieldClassName } from "../lib/styles";
import { authErrorMessage, isValidEmail, roleHomePath, useAuthStore } from "../store/authStore";

const AUTH_PATHS = ["/login", "/signup", "/forgot-password", "/reset-password"];

/** Where a visitor sent here by a route guard (or a "Log in to ..." prompt) should land afterwards. */
function returnPath(from) {
  const pathname = from?.pathname;
  if (!pathname || AUTH_PATHS.includes(pathname)) return "";
  return `${pathname}${from.search ?? ""}${from.hash ?? ""}`;
}

function isUnconfirmedEmail(error) {
  return error?.code === "email_not_confirmed" || /email not confirmed/i.test(error?.message ?? "");
}

export function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const signIn = useAuthStore((state) => state.signIn);
  const resendConfirmation = useAuthStore((state) => state.resendConfirmation);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [notice, setNotice] = useState(location.state?.notice ?? "");
  const [needsConfirmation, setNeedsConfirmation] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [resending, setResending] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;
    setFormError("");
    setNotice("");
    setNeedsConfirmation(false);

    const validationErrors = {};
    if (!email.trim()) validationErrors.email = "Enter your email address.";
    else if (!isValidEmail(email)) validationErrors.email = "Enter a valid email address.";
    if (!password) validationErrors.password = "Enter your password.";
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const profile = await signIn({ email: email.trim(), password });
      navigate(returnPath(location.state?.from) || roleHomePath(profile?.role), { replace: true });
    } catch (error) {
      setFormError(authErrorMessage(error, "Couldn't log you in. Check your details and try again."));
      setNeedsConfirmation(isUnconfirmedEmail(error));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleResend() {
    if (resending) return;
    setFormError("");
    setNotice("");
    if (!isValidEmail(email)) {
      setErrors({ email: "Enter your email address first." });
      return;
    }
    setErrors({});

    setResending(true);
    try {
      await resendConfirmation(email);
      setNotice("We sent a new confirmation email. Check your inbox (and spam folder).");
      setNeedsConfirmation(false);
    } catch (error) {
      setFormError(authErrorMessage(error));
    } finally {
      setResending(false);
    }
  }

  return (
    <Container className="py-16">
      <div className="mx-auto max-w-md">
        <h1 className="font-display text-3xl font-bold text-ink">Log in</h1>
        <p className="mt-2 text-[15px] text-ink-soft">
          New to PETSTA?{" "}
          <Link to="/signup" className="text-primary hover:underline">
            Create an account
          </Link>
        </p>

        <form onSubmit={handleSubmit} noValidate className="mt-8 flex flex-col gap-5">
          {notice && (
            <p role="status" className="rounded-lg border border-trust/30 bg-trust/5 px-4 py-3 text-sm text-ink">
              {notice}
            </p>
          )}

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
              aria-invalid={Boolean(errors.email)}
              className={fieldClassName(Boolean(errors.email))}
            />
            {errors.email && <p className="mt-1.5 text-sm text-error">{errors.email}</p>}
          </div>

          <div>
            <div className="flex items-baseline justify-between gap-3">
              <label htmlFor="password" className="block text-sm text-ink">
                Password
              </label>
              <Link
                to="/forgot-password"
                state={{ email: email.trim() }}
                className="text-sm text-primary hover:underline"
              >
                Forgot password?
              </Link>
            </div>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              aria-invalid={Boolean(errors.password)}
              className={fieldClassName(Boolean(errors.password))}
            />
            {errors.password && <p className="mt-1.5 text-sm text-error">{errors.password}</p>}
          </div>

          {formError && (
            <p role="alert" className="text-sm text-error">
              {formError}
            </p>
          )}

          {needsConfirmation && (
            <Button type="button" variant="outline" size="sm" onClick={handleResend} disabled={resending} className="w-fit">
              {resending ? "Sending…" : "Resend confirmation email"}
            </Button>
          )}

          <Button type="submit" variant="accent" size="lg" disabled={submitting} className="mt-2 w-full">
            {submitting ? "Logging in…" : "Log in"}
          </Button>
        </form>
      </div>
    </Container>
  );
}
