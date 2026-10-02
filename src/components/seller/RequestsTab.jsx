import { useState } from "react";
import { EmptyState } from "../ui/EmptyState";
import { FilterChips } from "./FilterChips";
import { applyFilter, countByStatus, withCounts } from "./helpers";
import { ListSkeleton } from "./ListSkeleton";
import { LoadError } from "./LoadError";
import { Notice } from "./Notice";
import { QuoteModal } from "./QuoteModal";
import { RequestCard } from "./RequestCard";

const FILTERS = [
  { value: "open", label: "Open" },
  { value: "quoted", label: "Quoted" },
  { value: "accepted", label: "Accepted" },
  { value: "ended", label: "Declined & closed", statuses: ["declined", "cancelled", "closed"] },
  { value: "all", label: "All" },
];

/** "Custom requests": open requests from customers, plus the ones this shop has quoted. */
export function RequestsTab({ shopId, readOnly, query }) {
  const [filter, setFilter] = useState(null);
  const [quoteTarget, setQuoteTarget] = useState(null);
  const [flash, setFlash] = useState("");

  if (query.loading) return <ListSkeleton rows={3} />;
  if (query.error && !query.data) {
    return <LoadError what="custom requests" message={query.error} onRetry={query.reload} />;
  }

  const requests = query.data ?? [];
  const activeFilter = filter ?? (countByStatus(requests).open > 0 ? "open" : "all");
  const visible = applyFilter(FILTERS, activeFilter, requests);

  function handleSent(message) {
    setQuoteTarget(null);
    setFlash(message);
    query.reload();
  }

  return (
    <div className="flex flex-col gap-5">
      <p className="text-sm text-ink-soft">
        Customers describe what they need and any approved shop can send a quote. They then accept or decline it.
      </p>

      <FilterChips
        label="Filter custom requests by status"
        options={withCounts(FILTERS, requests)}
        value={activeFilter}
        onChange={setFilter}
      />

      {flash && <Notice tone="success">{flash}</Notice>}
      {query.error && <LoadError what="custom requests" message={query.error} onRetry={query.reload} />}

      {visible.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border bg-surface">
          <EmptyState
            title={requests.length === 0 ? "No custom requests" : "Nothing here"}
            description={
              requests.length === 0
                ? "New requests from customers show up here so you can send a quote."
                : "No requests match this filter."
            }
          />
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {visible.map((request) => (
            <RequestCard
              key={request.id}
              request={request}
              shopId={shopId}
              readOnly={readOnly}
              onQuote={(target) => {
                setFlash("");
                setQuoteTarget(target);
              }}
              onChanged={query.reload}
            />
          ))}
        </div>
      )}

      {quoteTarget && (
        <QuoteModal request={quoteTarget} shopId={shopId} onClose={() => setQuoteTarget(null)} onSent={handleSent} />
      )}
    </div>
  );
}
