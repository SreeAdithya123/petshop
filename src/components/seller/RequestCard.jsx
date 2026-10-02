import { useState } from "react";
import { formatDate, formatPrice } from "../../lib/format";
import { Button } from "../ui/Button";
import { StatusBadge } from "../ui/StatusBadge";
import { categoryLabel } from "./helpers";
import { Meta, MetaList } from "./Meta";
import { updateRow } from "./mutations";
import { Notice } from "./Notice";

const STATUS_LABELS = {
  open: "Awaiting your quote",
  quoted: "Quote sent",
  accepted: "Accepted by customer",
  declined: "Declined by customer",
  cancelled: "Cancelled by customer",
  closed: "Closed",
};

/** One custom service request. Deliberately shows no customer identity or contact details. */
export function RequestCard({ request, shopId, readOnly, onQuote, onChanged }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const mine = request.shop_id === shopId;
  const pet = [request.pet_name, request.pet_species ? `(${request.pet_species})` : null].filter(Boolean).join(" ");

  async function markClosed() {
    setBusy(true);
    setError("");
    const message = await updateRow(
      "custom_service_requests",
      request.id,
      { status: "closed" },
      { status: "accepted" },
    );
    setBusy(false);
    if (message) setError(message);
    else onChanged();
  }

  return (
    <article className="rounded-xl border border-border bg-surface p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[15px] font-medium text-ink">{request.title}</h3>
          <p className="text-sm text-ink-soft">Requested {formatDate(request.created_at)}</p>
        </div>
        <StatusBadge status={request.status} label={STATUS_LABELS[request.status]} />
      </div>

      {request.description && <p className="mt-3 whitespace-pre-line text-sm text-ink">{request.description}</p>}

      <MetaList className="mt-4">
        {request.category && <Meta label="Category">{categoryLabel(request.category)}</Meta>}
        {pet && <Meta label="Pet">{pet}</Meta>}
        {request.preferred_date && <Meta label="Preferred date">{formatDate(request.preferred_date)}</Meta>}
        {request.budget != null && <Meta label="Customer budget">{formatPrice(request.budget)}</Meta>}
      </MetaList>

      {mine && request.quoted_price != null && (
        <div className="mt-4 rounded-lg bg-paper px-3 py-2 text-sm text-ink">
          <p>
            <span className="text-ink-soft">Your quote: </span>
            <span className="font-medium text-accent">{formatPrice(request.quoted_price)}</span>
            {request.responded_at && <span className="text-ink-soft"> &middot; {formatDate(request.responded_at)}</span>}
          </p>
          {request.response_message && <p className="mt-1 whitespace-pre-line text-ink-soft">{request.response_message}</p>}
        </div>
      )}

      {error && (
        <Notice tone="error" className="mt-4">
          {error}
        </Notice>
      )}

      {!readOnly && (
        <>
          {request.status === "open" && (
            <div className="mt-4 border-t border-border pt-4">
              <Button type="button" variant="accent" size="sm" onClick={() => onQuote(request)}>
                Send quote
              </Button>
            </div>
          )}
          {request.status === "quoted" && mine && (
            <div className="mt-4 flex flex-wrap items-center gap-3 border-t border-border pt-4">
              <Button type="button" variant="outline" size="sm" onClick={() => onQuote(request)}>
                Revise quote
              </Button>
              <p className="text-sm text-ink-soft">Waiting for the customer to accept or decline.</p>
            </div>
          )}
          {request.status === "accepted" && mine && (
            <div className="mt-4 flex flex-wrap items-center gap-3 border-t border-border pt-4">
              <Button type="button" variant="primary" size="sm" onClick={markClosed} disabled={busy}>
                {busy ? "Closing…" : "Mark closed"}
              </Button>
              <p className="text-sm text-ink-soft">Close this once you have delivered the service.</p>
            </div>
          )}
        </>
      )}
    </article>
  );
}
