import { Link, useLocation } from "react-router-dom";
import { Button } from "./Button";
import { EmptyState } from "./EmptyState";

/**
 * "Log in to ..." call-to-action. Sends the visitor to /login and brings
 * them back to the page they were on afterwards.
 */
export function LoginPrompt({ title = "Log in to continue", description, compact = false }) {
  const location = useLocation();

  if (compact) {
    return (
      <p className="text-sm text-ink-soft">
        <Link to="/login" state={{ from: location }} className="font-medium text-primary hover:underline">
          Log in
        </Link>{" "}
        {description ?? "to continue."}
      </p>
    );
  }

  return (
    <EmptyState
      title={title}
      description={description}
      action={
        <Button to="/login" state={{ from: location }} size="sm">
          Log in
        </Button>
      }
    />
  );
}
