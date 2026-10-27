import { Link } from "react-router-dom";
import {
  ArrowUUpLeft,
  CalendarCheck,
  Package,
  PawPrint,
  Quotes,
  Receipt,
  SealCheck,
  ShoppingBag,
  VideoCamera,
} from "@phosphor-icons/react";
import { useCallback } from "react";
import { ListSkeleton } from "../../components/seller/ListSkeleton";
import { LoadError } from "../../components/seller/LoadError";
import { Notice } from "../../components/seller/Notice";
import { loadShopOrders, orderTypeLabel } from "../../components/seller/orderData";
import { SellerPage } from "../../components/seller/SellerPage";
import { shortOrderId } from "../../components/seller/helpers";
import { useLoader } from "../../components/seller/useLoader";
import { RevenueChart } from "../../components/ui/RevenueChart";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { useMyShop } from "../../hooks/useMyShop";
import { formatOrderDate, formatPrice } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";

const SHOP_STATUS_LABELS = {
  approved: "Approved",
  pending: "Awaiting approval",
  suspended: "Suspended",
};

const RECENT_ORDER_COUNT = 5;

/** A head-only row count; resolves to null (shown as a dash) when the count could not be read. */
async function safeCount(buildQuery) {
  try {
    const { count, error } = await buildQuery();
    return error ? null : (count ?? 0);
  } catch {
    return null;
  }
}

/**
 * Everything the dashboard shows. A part that fails to load is null (its tile
 * shows a dash) so one failing table doesn't blank the whole page; only when
 * everything fails does the page show its full-page retry.
 */
async function loadDashboard(shopId) {
  const [ordersResult, pendingDemos, pendingRefunds, pendingBookings, openRequests] = await Promise.all([
    loadShopOrders(shopId),
    safeCount(() =>
      supabase
        .from("demo_requests")
        .select("id", { count: "exact", head: true })
        .eq("shop_id", shopId)
        .eq("status", "pending"),
    ),
    safeCount(() =>
      supabase
        .from("refunds")
        .select("id", { count: "exact", head: true })
        .eq("shop_id", shopId)
        .eq("status", "pending"),
    ),
    safeCount(() =>
      supabase
        .from("service_bookings")
        .select("id", { count: "exact", head: true })
        .eq("shop_id", shopId)
        .eq("status", "pending"),
    ),
    // Open requests are visible to every approved shop: they are the ones to quote on.
    safeCount(() =>
      supabase.from("custom_service_requests").select("id", { count: "exact", head: true }).eq("status", "open"),
    ),
  ]);

  const orders = ordersResult.data;
  const counts = [pendingDemos, pendingRefunds, pendingBookings, openRequests];
  if (!orders && counts.every((count) => count === null)) {
    return { data: null, error: ordersResult.error };
  }

  return {
    data: {
      orders,
      ordersError: orders ? null : ordersResult.error.message,
      pendingDemos,
      pendingRefunds,
      pendingBookings,
      openRequests,
    },
    error: null,
  };
}

/** A tappable counter. `attention` tiles highlight while the count is above zero; a null `value` shows a dash. */
function ActionTile({ label, value, hint, to, icon: Icon, attention = false }) {
  const highlighted = attention && (value ?? 0) > 0;

  return (
    <Link
      to={to}
      className={`flex min-h-24 flex-col rounded-xl border px-4 py-3 transition-colors sm:px-5 sm:py-4 ${
        highlighted
          ? "border-accent/40 bg-accent/5 hover:bg-accent/10"
          : "border-border bg-surface hover:bg-primary/5"
      }`}
    >
      <span className="flex items-start gap-2 text-sm text-ink-soft">
        <Icon size={18} aria-hidden="true" className={`mt-0.5 flex-none ${highlighted ? "text-accent" : ""}`} />
        {label}
      </span>
      <span className="mt-1 font-display text-2xl font-semibold text-ink">
        {value == null ? (
          <>
            &ndash;<span className="sr-only">unavailable</span>
          </>
        ) : (
          value
        )}
      </span>
      {hint && <span className="mt-0.5 text-xs text-ink-soft">{hint}</span>}
    </Link>
  );
}

function RecentOrderRow({ order }) {
  return (
    <Link
      to="/seller/orders"
      className="flex flex-wrap items-center justify-between gap-4 px-5 py-4 transition-colors hover:bg-primary/5"
    >
      <div className="min-w-0">
        <p className="text-[15px] text-ink">
          {orderTypeLabel(order.order_type)} <span className="text-ink-soft">{shortOrderId(order.id)}</span>
        </p>
        <p className="text-sm text-ink-soft">
          {order.customerName} &middot; {formatOrderDate(order.created_at)}
        </p>
      </div>
      <div className="flex flex-col items-end gap-1.5">
        <p className="text-[15px] font-medium text-accent">{formatPrice(order.shopSubtotal)}</p>
        <StatusBadge status={order.status} />
      </div>
    </Link>
  );
}

function DashboardContent({ shop }) {
  const load = useCallback(() => loadDashboard(shop.id), [shop.id]);
  const query = useLoader(load);

  const heading = (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <p className="min-w-0 truncate font-display text-lg font-semibold text-ink">{shop.name}</p>
      <StatusBadge status={shop.status} label={SHOP_STATUS_LABELS[shop.status]} />
    </div>
  );

  if (query.loading) {
    return (
      <div className="flex flex-col gap-6">
        {heading}
        <ListSkeleton tiles={4} rows={2} />
      </div>
    );
  }

  if (query.error && !query.data) {
    return (
      <div className="flex flex-col gap-6">
        {heading}
        <LoadError what="your dashboard" message={query.error} onRetry={query.reload} />
      </div>
    );
  }

  const data = query.data;
  const shopOrders = data.orders;
  const orders = shopOrders?.orders ?? [];
  const pendingOrders = shopOrders ? orders.filter((order) => order.status === "pending").length : null;
  const paidOrders = orders.filter((order) => order.status === "paid").length;
  const countsIncomplete =
    !shopOrders ||
    data.pendingDemos === null ||
    data.pendingRefunds === null ||
    data.pendingBookings === null ||
    data.openRequests === null;

  // Revenue counts this shop's own lines on orders that weren't cancelled.
  const revenueOrders = orders
    .filter((order) => order.status !== "cancelled")
    .map((order) => ({ created_at: order.created_at, total_amount: order.shopSubtotal }));

  return (
    <div className="flex flex-col gap-8">
      {heading}

      <section aria-labelledby="needs-attention">
        <h2 id="needs-attention" className="font-display text-xl font-semibold text-ink">
          Needs your attention
        </h2>

        {countsIncomplete && (
          <Notice tone="warning" className="mt-4 flex flex-wrap items-center justify-between gap-3">
            <span>
              {data.ordersError
                ? `Your orders and listings couldn't be loaded: ${data.ordersError}`
                : "Some counts couldn't be loaded."}
            </span>
            <button
              type="button"
              onClick={query.reload}
              className="font-medium text-primary hover:underline"
            >
              Try again
            </button>
          </Notice>
        )}

        <div className="mt-4 grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3">
          <ActionTile
            label="Orders awaiting payment"
            value={pendingOrders}
            hint={paidOrders > 0 ? `${paidOrders} paid, to hand over` : null}
            to="/seller/orders"
            icon={Receipt}
            attention
          />
          <ActionTile
            label="Demo requests to answer"
            value={data.pendingDemos}
            to="/seller/demos"
            icon={VideoCamera}
            attention
          />
          <ActionTile
            label="Refund requests"
            value={data.pendingRefunds}
            to="/seller/refunds"
            icon={ArrowUUpLeft}
            attention
          />
          <ActionTile
            label="Service bookings to confirm"
            value={data.pendingBookings}
            to="/seller/services?tab=bookings"
            icon={CalendarCheck}
            attention
          />
          <ActionTile
            label="Open custom requests"
            value={data.openRequests}
            to="/seller/services?tab=requests"
            icon={Quotes}
            attention
          />
        </div>
      </section>

      <section aria-labelledby="your-shop">
        <h2 id="your-shop" className="font-display text-xl font-semibold text-ink">
          Your shop
        </h2>
        <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
          <ActionTile label="Pets listed" value={shopOrders?.petCount ?? null} to="/seller/pets" icon={PawPrint} />
          <ActionTile
            label="Products listed"
            value={shopOrders?.productCount ?? null}
            to="/seller/products"
            icon={Package}
          />
          <ActionTile label="Pets sold" value={shopOrders?.soldCount ?? null} to="/seller/pets" icon={SealCheck} />
          <ActionTile
            label="Orders"
            value={shopOrders ? orders.length : null}
            to="/seller/orders"
            icon={ShoppingBag}
          />
        </div>
      </section>

      {shopOrders && (
        <>
          <RevenueChart orders={revenueOrders} />

          <section aria-labelledby="recent-orders">
            <h2 id="recent-orders" className="font-display text-xl font-semibold text-ink">
              Recent orders
            </h2>
            <p className="mt-1 text-sm text-ink-soft">
              Orders containing your pets, products or services, most recent first.
            </p>

            {orders.length === 0 ? (
              <p className="mt-4 text-[15px] text-ink-soft">No orders yet.</p>
            ) : (
              <div className="mt-4 divide-y divide-border overflow-hidden rounded-xl border border-border bg-surface">
                {orders.slice(0, RECENT_ORDER_COUNT).map((order) => (
                  <RecentOrderRow key={order.id} order={order} />
                ))}
              </div>
            )}

            {orders.length > RECENT_ORDER_COUNT && (
              <Link to="/seller/orders" className="mt-3 inline-block text-sm font-medium text-primary hover:underline">
                See all orders
              </Link>
            )}
          </section>
        </>
      )}
    </div>
  );
}

export function SellerDashboard() {
  const { shop, loading, error } = useMyShop();

  return (
    <SellerPage
      title="Dashboard"
      description="What needs your attention and how your shop is doing."
      unlocks="manage your orders, bookings and requests"
      shop={shop}
      loading={loading}
      error={error}
    >
      <DashboardContent shop={shop} />
    </SellerPage>
  );
}
