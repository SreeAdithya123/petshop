import { useCallback, useState } from "react";
import { ConfirmModal } from "../../components/seller/ConfirmModal";
import { CustomerContact } from "../../components/seller/CustomerContact";
import { FilterChips } from "../../components/seller/FilterChips";
import { applyFilter, countByStatus, shortOrderId, withCounts } from "../../components/seller/helpers";
import { ListSkeleton } from "../../components/seller/ListSkeleton";
import { LoadError } from "../../components/seller/LoadError";
import { Meta, MetaList } from "../../components/seller/Meta";
import { updateRow } from "../../components/seller/mutations";
import { Notice } from "../../components/seller/Notice";
import { attachCustomers } from "../../components/seller/profiles";
import { SellerPage } from "../../components/seller/SellerPage";
import { SummaryTile } from "../../components/seller/SummaryTile";
import { useLoader } from "../../components/seller/useLoader";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { useMyShop } from "../../hooks/useMyShop";
import { formatDate, formatPrice } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";

const FILTERS = [
  { value: "pending", label: "Pending" },
  { value: "approved", label: "Approved" },
  { value: "rejected", label: "Rejected" },
  { value: "all", label: "All" },
];

const DECISIONS = {
  approved: {
    title: "Approve this refund?",
    confirmLabel: "Approve refund",
    destructive: false,
    notice:
      "Approving records that you will refund the customer in person or off-platform. PETSTA does not move money, so you return the payment to the customer directly.",
    flash: "Refund approved. Remember to return the payment to the customer directly.",
  },
  rejected: {
    title: "Reject this refund?",
    confirmLabel: "Reject refund",
    destructive: true,
    notice: "The customer will see this request as rejected. The decision can't be changed afterwards.",
    flash: "Refund rejected.",
  },
};

function RefundCard({ refund, customer, readOnly, onDecide }) {
  const pending = refund.status === "pending";

  return (
    <article className="rounded-xl border border-border bg-surface p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[15px] font-medium text-ink">{refund.item_label || "Refund request"}</h3>
          <p className="text-sm text-ink-soft">
            Order {shortOrderId(refund.order_id)} &middot; Requested {formatDate(refund.created_at)}
          </p>
        </div>
        <div className="flex flex-col items-end gap-2">
          <StatusBadge status={refund.status} />
          <p className="font-display text-lg font-semibold text-accent">{formatPrice(refund.amount)}</p>
        </div>
      </div>

      <MetaList className="mt-4">
        <Meta label="Customer">
          <CustomerContact profile={customer} />
        </Meta>
        {!pending && refund.resolved_at && <Meta label="Resolved">{formatDate(refund.resolved_at)}</Meta>}
      </MetaList>

      <div className="mt-4 rounded-lg bg-paper px-3 py-2 text-sm text-ink">
        <p>
          <span className="text-ink-soft">Reason: </span>
          {refund.reason}
        </p>
        {refund.notes && (
          <p className="mt-1 whitespace-pre-line">
            <span className="text-ink-soft">Notes: </span>
            {refund.notes}
          </p>
        )}
      </div>

      {pending && !readOnly && (
        <div className="mt-4 flex flex-wrap gap-2 border-t border-border pt-4">
          <Button type="button" variant="accent" size="sm" onClick={() => onDecide(refund, "approved")}>
            Approve
          </Button>
          <Button type="button" variant="outline" size="sm" onClick={() => onDecide(refund, "rejected")}>
            Reject
          </Button>
        </div>
      )}
    </article>
  );
}

function RefundsContent({ shop }) {
  const readOnly = shop.status !== "approved";
  const [filter, setFilter] = useState(null);
  const [decision, setDecision] = useState(null); // { refund, status }
  const [flash, setFlash] = useState("");

  const load = useCallback(
    async () =>
      attachCustomers(
        await supabase.from("refunds").select("*").eq("shop_id", shop.id).order("created_at", { ascending: false }),
      ),
    [shop.id],
  );
  const query = useLoader(load);

  if (query.loading) return <ListSkeleton tiles={2} rows={3} />;
  if (query.error && !query.data) {
    return <LoadError what="refund requests" message={query.error} onRetry={query.reload} />;
  }

  const { rows = [], profiles = {}, profilesError = null } = query.data ?? {};
  const pendingCount = countByStatus(rows).pending ?? 0;
  const approvedTotal = rows
    .filter((row) => row.status === "approved")
    .reduce((sum, row) => sum + (Number(row.amount) || 0), 0);
  // Open on "Pending" when there is something to decide, otherwise show everything.
  const activeFilter = filter ?? (pendingCount > 0 ? "pending" : "all");
  const visible = applyFilter(FILTERS, activeFilter, rows);

  async function handleConfirm() {
    const message = await updateRow("refunds", decision.refund.id, { status: decision.status }, { status: "pending" });
    if (message) return message;
    setFlash(DECISIONS[decision.status].flash);
    setDecision(null);
    query.reload();
    return null;
  }

  const copy = decision ? DECISIONS[decision.status] : null;

  return (
    <div className="flex flex-col gap-6">
      <Notice tone="info" title="How refunds work">
        PETSTA records your decision but does not move money. If you approve a refund, return the payment to the
        customer directly.
      </Notice>

      <div className="grid grid-cols-2 gap-3 sm:gap-4">
        <SummaryTile label="Pending" value={pendingCount} />
        <SummaryTile label="Total approved" value={formatPrice(approvedTotal)} />
      </div>

      <FilterChips
        label="Filter refunds by status"
        options={withCounts(FILTERS, rows)}
        value={activeFilter}
        onChange={setFilter}
      />

      {flash && <Notice tone="success">{flash}</Notice>}
      {query.error && <LoadError what="refund requests" message={query.error} onRetry={query.reload} />}
      {profilesError && <Notice tone="error">Couldn&rsquo;t load customer names: {profilesError}</Notice>}

      {visible.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border bg-surface">
          <EmptyState
            title={rows.length === 0 ? "No refund requests" : "Nothing here"}
            description={
              rows.length === 0
                ? "If a customer asks for a refund on an order that includes your items, it shows up here."
                : "No refund requests match this filter."
            }
          />
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {visible.map((refund) => (
            <RefundCard
              key={refund.id}
              refund={refund}
              customer={profiles[refund.customer_id]}
              readOnly={readOnly}
              onDecide={(target, status) => {
                setFlash("");
                setDecision({ refund: target, status });
              }}
            />
          ))}
        </div>
      )}

      {decision && (
        <ConfirmModal
          title={copy.title}
          description={[
            decision.refund.item_label || "Refund request",
            formatPrice(decision.refund.amount),
            `Order ${shortOrderId(decision.refund.order_id)}`,
          ].join(" · ")}
          confirmLabel={copy.confirmLabel}
          destructive={copy.destructive}
          onConfirm={handleConfirm}
          onClose={() => setDecision(null)}
        >
          <p className="text-sm text-ink">{copy.notice}</p>
        </ConfirmModal>
      )}
    </div>
  );
}

export function SellerRefunds() {
  const { shop, loading, error } = useMyShop();

  return (
    <SellerPage
      title="Refunds"
      description="Refund requests from customers on orders that include your items."
      unlocks="approve or reject refunds"
      shop={shop}
      loading={loading}
      error={error}
    >
      <RefundsContent shop={shop} />
    </SellerPage>
  );
}
