import { formatDate, formatPrice } from "../../lib/format";
import { Button } from "../ui/Button";
import { StatusBadge } from "../ui/StatusBadge";
import { ConfirmButton } from "./ConfirmButton";
import { ListState } from "./ListState";
import { categoryMeta } from "./serviceCategories";

function RequestRow({ request, busy, onChangeStatus }) {
  const quoted = request.status === "quoted";
  const canCancel = request.status === "open" || quoted;
  const hasQuote = request.status !== "open" && (request.quoted_price != null || Boolean(request.shop_name));

  const pet =
    request.pet_name && request.pet_species
      ? `${request.pet_name} (${request.pet_species})`
      : request.pet_name || request.pet_species;
  const details = [
    request.category && categoryMeta(request.category).label,
    pet && `Pet: ${pet}`,
    request.preferred_date && `Preferred ${formatDate(request.preferred_date)}`,
    request.budget != null && `Budget ${formatPrice(request.budget)}`,
  ].filter(Boolean);

  return (
    <li className="rounded-xl border border-border bg-surface p-4">
      <div className="flex flex-wrap items-center gap-2">
        <h3 className="text-[15px] font-medium text-ink">{request.title}</h3>
        <StatusBadge status={request.status} label={request.status === "open" ? "Awaiting quotes" : undefined} />
      </div>
      {details.length > 0 && <p className="mt-1 text-sm text-ink-soft">{details.join(" · ")}</p>}
      <p className="mt-2 line-clamp-3 text-sm text-ink-soft">{request.description}</p>

      {hasQuote && (
        <div className="mt-3 rounded-lg border border-primary/20 bg-primary/5 p-3">
          <p className="text-sm text-ink-soft">
            Quote from <span className="font-medium text-ink">{request.shop_name || "a shop"}</span>
          </p>
          {request.quoted_price != null && (
            <p className="font-display text-xl font-semibold text-accent">{formatPrice(request.quoted_price)}</p>
          )}
          {request.response_message && <p className="mt-1 text-sm text-ink">{request.response_message}</p>}
        </div>
      )}

      {canCancel && (
        <div className="mt-3 flex flex-wrap items-center gap-2">
          {quoted && (
            <>
              <Button size="sm" disabled={busy} onClick={() => onChangeStatus(request.id, "accepted")}>
                Accept quote
              </Button>
              <ConfirmButton
                label="Decline"
                confirmLabel="Yes, decline"
                prompt="Decline this quote?"
                busy={busy}
                onConfirm={() => onChangeStatus(request.id, "declined")}
              />
            </>
          )}
          <ConfirmButton
            label="Cancel request"
            confirmLabel="Yes, cancel"
            prompt="Cancel this request?"
            busy={busy}
            onConfirm={() => onChangeStatus(request.id, "cancelled")}
          />
        </div>
      )}
    </li>
  );
}

/** Own custom service requests with quote handling. State comes from useCustomRequests. */
export function RequestList({ state, emptyMessage = "No custom requests yet." }) {
  const { requests, loading, error, reload, changeStatus, busyId, actionError } = state;

  return (
    <ListState
      loading={loading}
      error={error}
      onRetry={reload}
      isEmpty={requests.length === 0}
      emptyMessage={emptyMessage}
    >
      {actionError && (
        <p role="alert" className="mb-3 text-sm text-error">
          {actionError}
        </p>
      )}
      <ul className="space-y-3">
        {requests.map((request) => (
          <RequestRow
            key={request.id}
            request={request}
            busy={busyId === request.id}
            onChangeStatus={changeStatus}
          />
        ))}
      </ul>
    </ListState>
  );
}
