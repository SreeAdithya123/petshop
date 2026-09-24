import { useEffect, useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { supabase } from "../../lib/supabaseClient";
import { useMyShop } from "../../hooks/useMyShop";
import { formatPrice, formatOrderDate } from "../../lib/format";

const shopStatusStyles = {
  approved: "text-trust",
  pending: "text-ink-soft",
  suspended: "text-error",
};

async function loadDashboardStats(shopId) {
  const [petsResult, productsResult, soldResult, petRowsResult, productRowsResult] = await Promise.all([
    supabase.from("pets").select("id", { count: "exact", head: true }).eq("shop_id", shopId),
    supabase.from("products").select("id", { count: "exact", head: true }).eq("shop_id", shopId),
    supabase.from("pets").select("id", { count: "exact", head: true }).eq("shop_id", shopId).eq("status", "sold"),
    supabase.from("pets").select("id").eq("shop_id", shopId),
    supabase.from("products").select("id").eq("shop_id", shopId),
  ]);

  const petIds = (petRowsResult.data || []).map((row) => row.id);
  const productIds = (productRowsResult.data || []).map((row) => row.id);

  let orderIds = [];
  if (petIds.length > 0 || productIds.length > 0) {
    const filters = [];
    if (petIds.length > 0) filters.push(`and(item_type.eq.pet,item_id.in.(${petIds.join(",")}))`);
    if (productIds.length > 0) filters.push(`and(item_type.eq.product,item_id.in.(${productIds.join(",")}))`);
    const { data: itemRows } = await supabase.from("order_items").select("order_id").or(filters.join(","));
    orderIds = [...new Set((itemRows || []).map((row) => row.order_id))];
  }

  let recentOrders = [];
  if (orderIds.length > 0) {
    const { data: orderRows } = await supabase
      .from("orders")
      .select("id, order_type, status, total_amount, created_at")
      .in("id", orderIds)
      .order("created_at", { ascending: false })
      .limit(5);
    recentOrders = orderRows || [];
  }

  return {
    stats: {
      petsCount: petsResult.count ?? 0,
      productsCount: productsResult.count ?? 0,
      soldCount: soldResult.count ?? 0,
      ordersCount: orderIds.length,
    },
    recentOrders,
  };
}

export function SellerDashboard() {
  const { shop, loading: shopLoading } = useMyShop();
  const [stats, setStats] = useState(null);
  const [recentOrders, setRecentOrders] = useState([]);
  const [statsLoading, setStatsLoading] = useState(true);

  useEffect(() => {
    if (!shop) {
      setStats(null);
      setRecentOrders([]);
      setStatsLoading(false);
      return;
    }

    let cancelled = false;
    setStatsLoading(true);

    loadDashboardStats(shop.id).then(({ stats: nextStats, recentOrders: nextOrders }) => {
      if (cancelled) return;
      setStats(nextStats);
      setRecentOrders(nextOrders);
      setStatsLoading(false);
    });

    return () => {
      cancelled = true;
    };
  }, [shop]);

  if (!shopLoading && !shop) {
    return (
      <Container className="py-12">
        <EmptyState
          title="You haven't set up your shop yet"
          description="Create your shop profile to start listing pets and products."
          action={
            <Button to="/seller/store" size="sm">
              Set up your shop
            </Button>
          }
        />
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h1 className="font-display text-3xl font-bold text-ink">Dashboard</h1>
        {shop && (
          <span className={`text-sm font-medium capitalize ${shopStatusStyles[shop.status] ?? "text-ink-soft"}`}>
            {shop.status}
          </span>
        )}
      </div>

      {shopLoading || statsLoading || !stats ? (
        <p className="mt-8 text-[15px] text-ink-soft">Loading…</p>
      ) : (
        <>
          <div className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-4">
            <StatCard label="Pets listed" value={stats.petsCount} />
            <StatCard label="Products listed" value={stats.productsCount} />
            <StatCard label="Pets sold" value={stats.soldCount} />
            <StatCard label="Orders" value={stats.ordersCount} />
          </div>

          <div className="mt-10">
            <h2 className="font-display text-xl font-semibold text-ink">Recent orders</h2>
            <p className="mt-1 text-sm text-ink-soft">Orders containing your pets or products, most recent first.</p>

            {recentOrders.length === 0 ? (
              <p className="mt-4 text-[15px] text-ink-soft">No orders yet.</p>
            ) : (
              <div className="mt-4 divide-y divide-border rounded-xl border border-border bg-surface">
                {recentOrders.map((order) => (
                  <div key={order.id} className="flex flex-wrap items-center justify-between gap-4 px-5 py-4">
                    <div>
                      <p className="text-[15px] text-ink capitalize">{order.order_type.replace("_", " ")}</p>
                      <p className="text-sm text-ink-soft">{formatOrderDate(order.created_at)}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-[15px] font-medium text-accent">{formatPrice(order.total_amount)}</p>
                      <p className="text-sm capitalize text-ink-soft">{order.status}</p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </Container>
  );
}

function StatCard({ label, value }) {
  return (
    <div className="rounded-xl border border-border bg-surface px-5 py-4">
      <p className="text-sm text-ink-soft">{label}</p>
      <p className="mt-1 font-display text-2xl font-semibold text-ink">{value}</p>
    </div>
  );
}
