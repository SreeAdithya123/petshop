import { useState } from "react";
import { EmptyState } from "../ui/EmptyState";
import { BookingCard } from "./BookingCard";
import { FilterChips } from "./FilterChips";
import { applyFilter, countByStatus, withCounts } from "./helpers";
import { ListSkeleton } from "./ListSkeleton";
import { LoadError } from "./LoadError";
import { Notice } from "./Notice";

const FILTERS = [
  { value: "pending", label: "Pending" },
  { value: "confirmed", label: "Confirmed" },
  { value: "completed", label: "Completed" },
  { value: "cancelled", label: "Cancelled" },
  { value: "all", label: "All" },
];

/** "Bookings": customer bookings of this shop's services, newest first. */
export function BookingsTab({ readOnly, query }) {
  const [filter, setFilter] = useState(null);

  if (query.loading) return <ListSkeleton rows={3} />;
  if (query.error && !query.data) return <LoadError what="bookings" message={query.error} onRetry={query.reload} />;

  const { rows = [], profiles = {}, profilesError = null } = query.data ?? {};
  // Open on "Pending" when there is something to act on, otherwise show everything.
  const activeFilter = filter ?? (countByStatus(rows).pending > 0 ? "pending" : "all");
  const visible = applyFilter(FILTERS, activeFilter, rows);

  return (
    <div className="flex flex-col gap-5">
      <FilterChips
        label="Filter bookings by status"
        options={withCounts(FILTERS, rows)}
        value={activeFilter}
        onChange={setFilter}
      />

      {query.error && <LoadError what="bookings" message={query.error} onRetry={query.reload} />}
      {profilesError && <Notice tone="error">Couldn&rsquo;t load customer names: {profilesError}</Notice>}

      {visible.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border bg-surface">
          <EmptyState
            title={rows.length === 0 ? "No bookings yet" : "Nothing here"}
            description={
              rows.length === 0
                ? "When customers book one of your approved services, it shows up here."
                : "No bookings match this filter."
            }
          />
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {visible.map((booking) => (
            <BookingCard
              key={booking.id}
              booking={booking}
              customer={profiles[booking.customer_id]}
              readOnly={readOnly}
              onChanged={query.reload}
            />
          ))}
        </div>
      )}
    </div>
  );
}
