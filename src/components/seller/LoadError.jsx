import { Button } from "../ui/Button";
import { Notice } from "./Notice";

/** Error banner for a failed list load, with a retry button. */
export function LoadError({ what, message, onRetry }) {
  return (
    <Notice tone="error" className="flex flex-wrap items-center justify-between gap-3">
      <span>
        Couldn&rsquo;t load {what}: {message}
      </span>
      <Button type="button" variant="outline" size="sm" onClick={onRetry}>
        Try again
      </Button>
    </Notice>
  );
}
