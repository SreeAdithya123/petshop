import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { fieldClassName } from "../../lib/styles";
import { PASSWORD_HINT, authErrorMessage, passwordProblem, useAuthStore } from "../../store/authStore";

/**
 * Where the password-reset email lands. Once the auth client has turned the
 * link into a temporary session the visitor picks a new password here; the
 * temporary session is then signed out and they log in with the new one.
 */
export function ResetPassword() {
  const navigate = useNavigate();
  const status = useAuthStore((state) => state.status);
  const session = useAuthStore((state) => state.session);
  const passwordRecovery = useAuthStore((state) => state.passwordRecovery);
  const updatePassword = useAuthStore((state) => state.updatePassword);
  const signOut = useAuthStore((state) => state.signOut);

  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [done, setDone] = useState(false);

  // `cancelling` keeps the form on screen while the temporary session is signed out.
  const ready = passwordRecovery || Boolean(session) || cancelling;

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;
    setFormError("");

    const nextErrors = {};
    const problem = passwordProblem(password);
    if (problem) nextErrors.password = problem;
    if (!confirm) nextErrors.confirm = "Re-enter your password.";
    else if (confirm !== password) nextErrors.confirm = "Passwords don't match.";
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    try {
      await updatePassword(password);
    } catch (error) {
      setFormError(authErrorMessage(error, "Couldn't update your password. Please try again."));
      setSubmitting(false);
      return;
    }

    setDone(true);
    try {
      await signOut();
    } catch {
      // The password is already changed; the visitor simply logs in again.
    }
    navigate("/login", {
      replace: true,
      state: { notice: "Your password has been updated. Log in with your new password." },
    });
  }

  /** Abandons the recovery: the temporary session is signed out so nobody is left logged in without choosing a password. */
  async function handleCancel() {
    if (cancelling || submitting) return;
    setCancelling(true);
    try {
      if (passwordRecovery) await signOut();
    } catch {
      // Leaving anyway; the page redirect below is what matters.
    }
    navigate(passwordRecovery ? "/login" : "/", { replace: true });
  }

  if (done) {
    return (
      <Container className="py-16">
        <div className="mx-auto max-w-md">
          <h1 className="font-display text-3xl font-bold text-ink">Password updated</h1>
          <div role="status" className="mt-6 rounded-xl border border-trust/30 bg-trust/5 p-4">
            <p className="font-medium text-ink">All set</p>
            <p className="mt-1 text-sm text-ink-soft">
              Your password has been changed. Taking you to log in with your new password…
            </p>
          </div>
          <Button to="/login" className="mt-6">
            Go to log in
          </Button>
        </div>
      </Container>
    );
  }

  if (!ready && status === "loading") {
    return (
      <Container className="py-16">
        <p role="status" className="text-center text-[15px] text-ink-soft">
          Checking your reset link…
        </p>
      </Container>
    );
  }

  if (!ready) {
    return (
      <Container className="py-16">
        <div className="mx-auto max-w-md">
          <h1 className="font-display text-3xl font-bold text-ink">This link has expired</h1>
          <p role="alert" className="mt-6 rounded-xl border border-warning/40 bg-warning/10 p-4 text-sm text-ink">
            The reset link is invalid, has expired or was already used. Reset links only work once, so request a
            new one.
          </p>
          <Button to="/forgot-password" variant="accent" className="mt-6 w-full">
            Request a new link
          </Button>
          <p className="mt-6 text-[15px]">
            <Link to="/login" className="text-primary hover:underline">
              Back to log in
            </Link>
          </p>
        </div>
      </Container>
    );
  }

  return (
    <Container className="py-16">
      <div className="mx-auto max-w-md">
        <h1 className="font-display text-3xl font-bold text-ink">Choose a new password</h1>
        <p className="mt-2 text-[15px] text-ink-soft">Pick something you haven't used on PETSTA before.</p>

        <form onSubmit={handleSubmit} noValidate className="mt-8 flex flex-col gap-5">
          <div>
            <label htmlFor="new-password" className="block text-sm text-ink">
              New password
            </label>
            <input
              id="new-password"
              type="password"
              autoComplete="new-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              disabled={submitting}
              aria-invalid={Boolean(errors.password)}
              className={fieldClassName(Boolean(errors.password))}
            />
            {errors.password ? (
              <p className="mt-1.5 text-sm text-error">{errors.password}</p>
            ) : (
              <p className="mt-1.5 text-xs text-ink-soft">{PASSWORD_HINT}</p>
            )}
          </div>

          <div>
            <label htmlFor="confirm-password" className="block text-sm text-ink">
              Confirm new password
            </label>
            <input
              id="confirm-password"
              type="password"
              autoComplete="new-password"
              value={confirm}
              onChange={(event) => setConfirm(event.target.value)}
              disabled={submitting}
              aria-invalid={Boolean(errors.confirm)}
              className={fieldClassName(Boolean(errors.confirm))}
            />
            {errors.confirm && <p className="mt-1.5 text-sm text-error">{errors.confirm}</p>}
          </div>

          {formError && (
            <p role="alert" className="text-sm text-error">
              {formError}
            </p>
          )}

          <Button type="submit" variant="accent" size="lg" disabled={submitting} className="mt-2 w-full">
            {submitting ? "Updating password…" : "Update password"}
          </Button>
        </form>

        <button
          type="button"
          onClick={handleCancel}
          disabled={cancelling || submitting}
          className="mt-5 text-[15px] text-primary hover:underline disabled:opacity-50"
        >
          Cancel
        </button>
      </div>
    </Container>
  );
}
