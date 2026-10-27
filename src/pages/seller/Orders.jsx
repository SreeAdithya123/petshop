import { useCallback, useRef, useState } from "react";
import { ConfirmModal } from "../../components/seller/ConfirmModal";
import { FilterChips } from "../../components/seller/FilterChips";
import { applyFilter, countByStatus, shortOrderId, withCounts } from "../../components/seller/helpers";
import { ListSkeleton } from "../../components/seller/ListSkeleton";
import { LoadError } from "../../components/seller/LoadError";
import { callRpc } from "../../components/seller/mutations";
import { Notice } from "../../components/seller/Notice";
import { OrderCard } from "../../components/seller/OrderCard";
import { loadShopOrders, ORDERS_PAGE_SIZE, orderTypeLabel } from "../../components/seller/orderData";
import { SellerPage } from "../../components/seller/SellerPage";
import { SummaryTile } from "../../components/seller/SummaryTile";
import { useLoader } from "../../components/seller/useLoader";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { useMyShop } from "../../hooks/useMyShop";

const FILTERS = [
  { value: "pending", label: "Pending" },
  { value: "paid", label: "Paid" },
  { value: "fulfilled", label: "Handed over" },
  { value: "cancelled", label: "Cancelled" },
  { value: "all", label: "All" },
];

const TRANSITIONS = {
  paid: {
    title: "Mark this order as paid?",
    message: "Confirm you have received the payment for this order in person.",
    confirmLabel: "Mark paid",
    success: "Order marked as paid.",
  },
  fulfilled: {
    title: "Mark this order as handed over?",
    message: "Confirm the customer has collected their items. Reserved pets in this order are marked as sold.",
    confirmLabel: "Mark handed over",
    success: "Order marked as handed over.",
  },
  cancelled: {
    title: "Cancel this order?",
    message:
      "Reserved pets go back to the catalog so other customers can reserve them again. The customer will see the order as cancelled. This can't be undone.",
    confirmLabel: "Cancel order",
    success: "Order cancelled. Any reserved pets are back in the catalog.",
  },
};

function OrdersContent({ shop }) {
  const readOnly = shop.status !== "approved";
  const [filter, setFilter] = useState(null);
  const [limit, setLimit] = useState(ORDERS_PAGE_SIZE);
  const [busy, setBusy] = useState(null); // { id, status } while an order is being updated
  const [confirming, setConfirming] = useState(null); // { order, status } awaiting confirmation
  const [flash, setFlash] = useState("");
  const inFlight = useRef(false);

  const load = useCallback(() => loadShopOrders(shop.id), [shop.id]);
  const query = useLoader(load);

  if (query.loading) return <ListSkeleton tiles={2} rows={3} />;
  if (query.error && !query.data) return <LoadError what="orders" message={query.error} onRetry={query.reload} />;

  const { orders: rows = [], customersError = null } = query.data ?? {};
  const counts = countByStatus(rows);
  const pendingCount = counts.pending ?? 0;
  const paidCount = counts.paid ?? 0;
  // Open on "Pending" when something needs doing, otherwise show everything.
  const activeFilter = filter ?? (pendingCount > 0 ? "pending" : "all");
  const visible = applyFilter(FILTERS, activeFilter, rows);
  const shown = Math.min(limit, visible.length);

  /**
   * Runs the confirmed change. Resolves to an error message for the dialog to
   * show (for example "This pet was put back on sale. Cancel this order
   * instead."), or null once the order has moved on and the list has reloaded.
   */
  async function applyTransition(order, status) {
    if (inFlight.current) return "Another update is still being saved. Please wait a moment.";
    inFlight.current = true;
    setBusy({ id: order.id, status });
    setFlash("");

    const failure = await callRpc("seller_update_order_status", { p_order_id: order.id, p_status: status });
    if (failure === null) {
      // Keep the card busy until the list shows the order's real state.
      await query.reload();
    } else {
      // The order may have moved on elsewhere (the customer cancelled, another device): show its real state.
      query.reload();
    }

    inFlight.current = false;
    setBusy(null);
    if (failure !== null) return failure;

    setConfirming(null);
    setFlash(TRANSITIONS[status].success);
    return null;
  }

  const transition = confirming ? TRANSITIONS[confirming.status] : null;

  return (
    <div className="flex flex-col gap-6">
      <Notice tone="info">
        Customers pay and collect in person. Mark an order paid when you receive the payment, then handed over once
        they have collected it. Cancelling releases any reserved pets back to the catalog.
      </Notice>

      <div className="grid grid-cols-2 gap-3 sm:gap-4">
        <SummaryTile label="Awaiting payment" value={pendingCount} />
        <SummaryTile label="Ready to hand over" value={paidCount} />
      </div>

      <FilterChips
        label="Filter orders by status"
        options={withCounts(FILTERS, rows)}
        value={activeFilter}
        onChange={(value) => {
          setFilter(value);
          setLimit(ORDERS_PAGE_SIZE);
        }}
      />

      {flash && <Notice tone="success">{flash}</Notice>}
      {query.error && <LoadError what="orders" message={query.error} onRetry={query.reload} />}
      {customersError && <Notice tone="error">Couldn&rsquo;t load customer names: {customersError}</Notice>}

      {visible.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border bg-surface">
          <EmptyState
            title={rows.length === 0 ? "No orders yet" : "Nothing here"}
            description={
              rows.length === 0
                ? "Orders for your pets and products will show up here."
                : "No orders match this filter."
            }
          />
        </div>
      ) : (
        <>
          <div className="flex flex-col gap-4">
            {visible.slice(0, shown).map((order) => (
              <OrderCard
                key={order.id}
                order={order}
                readOnly={readOnly}
                busyStatus={busy?.id === order.id ? busy.status : null}
                locked={busy !== null}
                onAction={(status) => {
                  setFlash("");
                  setConfirming({ order, status });
                }}
              />
            ))}
          </div>
          {shown < visible.length && (
            <div className="flex flex-col items-center gap-2">
              <p className="text-sm text-ink-soft">
                Showing {shown} of {visible.length}
              </p>
              <Button type="button" variant="outline" size="sm" onClick={() => setLimit((count) => count + ORDERS_PAGE_SIZE)}>
                Load more
              </Button>
            </div>
          )}
        </>
      )}

      {confirming && transition && (
        <ConfirmModal
          title={transition.title}
          description={`${orderTypeLabel(confirming.order.order_type)} ${shortOrderId(confirming.order.id)} · ${confirming.order.customerName}`}
          confirmLabel={transition.confirmLabel}
          cancelLabel={confirming.status === "cancelled" ? "Keep order" : "Cancel"}
          destructive={confirming.status === "cancelled"}
          onConfirm={() => applyTransition(confirming.order, confirming.status)}
          onClose={() => setConfirming(null)}
        >
          <p className="text-sm text-ink">{transition.message}</p>
        </ConfirmModal>
      )}
    </div>
  );
}

export function SellerOrders() {
  const { shop, loading, error } = useMyShop();

  return (
    <SellerPage
      title="Orders"
      description="Orders that include items from your shop."
      unlocks="update orders"
      shop={shop}
      loading={loading}
      error={error}
    >
      <OrdersContent shop={shop} />
    </SellerPage>
  );
}
