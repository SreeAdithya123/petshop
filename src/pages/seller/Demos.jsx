import { useCallback, useState } from "react";
import { DemoCard } from "../../components/seller/DemoCard";
import { DemoRespondModal } from "../../components/seller/DemoRespondModal";
import { FilterChips } from "../../components/seller/FilterChips";
import { applyFilter, countByStatus, withCounts } from "../../components/seller/helpers";
import { ListSkeleton } from "../../components/seller/ListSkeleton";
import { LoadError } from "../../components/seller/LoadError";
import { Notice } from "../../components/seller/Notice";
import { attachCustomers } from "../../components/seller/profiles";
import { SellerPage } from "../../components/seller/SellerPage";
import { SummaryTile } from "../../components/seller/SummaryTile";
import { useLoader } from "../../components/seller/useLoader";
import { EmptyState } from "../../components/ui/EmptyState";
import { useMyShop } from "../../hooks/useMyShop";
import { toDateInputValue } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";

const FILTERS = [
  { value: "pending", label: "Pending" },
  { value: "approved", label: "Approved" },
  { value: "completed", label: "Completed" },
  { value: "ended", label: "Rejected & cancelled", statuses: ["rejected", "cancelled"] },
  { value: "all", label: "All" },
];

function summarize(rows) {
  const today = toDateInputValue();
  const thisMonth = today.slice(0, 7);
  // The day a demo is held on: what the shop confirmed, else what the customer asked for.
  const heldOn = (row) => row.confirmed_date ?? row.preferred_date ?? "";

  return {
    pending: rows.filter((row) => row.status === "pending").length,
    upcoming: rows.filter((row) => row.status === "approved" && heldOn(row) >= today).length,
    completedThisMonth: rows.filter((row) => row.status === "completed" && heldOn(row).startsWith(thisMonth)).length,
  };
}

function DemosContent({ shop }) {
  const readOnly = shop.status !== "approved";
  const [filter, setFilter] = useState(null);
  const [responding, setResponding] = useState(null);
  const [flash, setFlash] = useState("");

  const load = useCallback(
    async () =>
      attachCustomers(
        await supabase
          .from("demo_requests")
          .select("*")
          .eq("shop_id", shop.id)
          .order("created_at", { ascending: false }),
      ),
    [shop.id],
  );
  const query = useLoader(load);

  if (query.loading) return <ListSkeleton tiles={3} rows={3} />;
  if (query.error && !query.data) {
    return <LoadError what="demo requests" message={query.error} onRetry={query.reload} />;
  }

  const { rows = [], profiles = {}, profilesError = null } = query.data ?? {};
  const stats = summarize(rows);
  // Open on "Pending" when there is something to answer, otherwise show everything.
  const activeFilter = filter ?? (countByStatus(rows).pending > 0 ? "pending" : "all");
  const visible = applyFilter(FILTERS, activeFilter, rows);

  function handleDone() {
    setResponding(null);
    setFlash("Your response was saved and the customer can see it.");
    query.reload();
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4">
        <SummaryTile label="Pending" value={stats.pending} />
        <SummaryTile label="Upcoming approved" value={stats.upcoming} />
        <SummaryTile
          label="Completed this month"
          value={stats.completedThisMonth}
          className="col-span-2 sm:col-span-1"
        />
      </div>

      <FilterChips
        label="Filter demo requests by status"
        options={withCounts(FILTERS, rows)}
        value={activeFilter}
        onChange={setFilter}
      />

      {flash && <Notice tone="success">{flash}</Notice>}
      {query.error && <LoadError what="demo requests" message={query.error} onRetry={query.reload} />}
      {profilesError && <Notice tone="error">Couldn&rsquo;t load customer names: {profilesError}</Notice>}

      {visible.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border bg-surface">
          <EmptyState
            title={rows.length === 0 ? "No demo requests yet" : "Nothing here"}
            description={
              rows.length === 0
                ? "When a customer asks to see one of your pets, the request shows up here."
                : "No demo requests match this filter."
            }
          />
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {visible.map((demo) => (
            <DemoCard
              key={demo.id}
              demo={demo}
              customer={profiles[demo.customer_id]}
              readOnly={readOnly}
              onRespond={(target) => {
                setFlash("");
                setResponding(target);
              }}
            />
          ))}
        </div>
      )}

      {responding && (
        <DemoRespondModal
          demo={responding}
          customer={profiles[responding.customer_id]}
          onClose={() => setResponding(null)}
          onDone={handleDone}
        />
      )}
    </div>
  );
}

export function SellerDemos() {
  const { shop, loading, error } = useMyShop();

  return (
    <SellerPage
      title="Demo requests"
      description="Customers who want to meet or video-call one of your pets before they decide."
      unlocks="respond to demo requests"
      shop={shop}
      loading={loading}
      error={error}
    >
      <DemosContent shop={shop} />
    </SellerPage>
  );
}
