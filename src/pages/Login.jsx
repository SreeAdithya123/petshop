import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { roleHomePath, useAuthStore } from "../store/authStore";

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

export function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const signIn = useAuthStore((state) => state.signIn);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");

    const validationErrors = {};
    if (!email.trim()) validationErrors.email = "Enter your email address.";
    if (!password) validationErrors.password = "Enter your password.";
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const profile = await signIn({ email: email.trim(), password });
      const redirectTo = location.state?.from?.pathname || roleHomePath(profile?.role);
      navigate(redirectTo, { replace: true });
    } catch (error) {
      setFormError(error.message || "Couldn't log you in. Check your details and try again.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Container className="py-16">
      <div className="mx-auto max-w-md">
        <h1 className="font-display text-3xl font-bold text-ink">Log in</h1>
        <p className="mt-2 text-[15px] text-ink-soft">
          New to Paws Nearby?{" "}
          <Link to="/signup" className="text-primary hover:underline">
            Create an account
          </Link>
        </p>

        <form onSubmit={handleSubmit} noValidate className="mt-8 flex flex-col gap-5">
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
            <label htmlFor="password" className="block text-sm text-ink">
              Password
            </label>
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

          {formError && <p className="text-sm text-error">{formError}</p>}

          <Button type="submit" variant="accent" size="lg" disabled={submitting} className="mt-2 w-full">
            {submitting ? "Logging in…" : "Log in"}
          </Button>
        </form>
      </div>
    </Container>
  );
}
