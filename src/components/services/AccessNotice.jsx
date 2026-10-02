import { Link } from "react-router-dom";
import { LoginPrompt } from "../ui/LoginPrompt";

/**
 * Shown in place of a booking / request form when the visitor can't submit
 * it: still checking their account, signed out, or signed in as a seller or
 * admin. `access` comes from useBookingAccess().
 */
export function AccessNotice({ access, action = "book this service" }) {
  if (access.status === "loading") {
    return <p className="text-sm text-ink-soft">Checking your account…</p>;
  }

  if (!access.session) {
    return (
      <div className="rounded-lg border border-border bg-paper p-4">
        <LoginPrompt compact description={`to ${action} with your customer account.`} />
        <p className="mt-2 text-sm text-ink-soft">
          New to PETSTA?{" "}
          <Link to="/signup" className="font-medium text-primary hover:underline">
            Create an account
          </Link>
          .
        </p>
      </div>
    );
  }

  return (
    <p className="rounded-lg border border-border bg-paper p-4 text-sm text-ink-soft">
      Only customer accounts can {action}.
      {access.role && ` Your account type is ${access.role.replace("_", " ")}.`}
    </p>
  );
}
