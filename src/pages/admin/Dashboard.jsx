import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";

const STAT_DEFS = [
  { key: "totalShops", label: "Total shops" },
  { key: "pendingShops", label: "Shops pending approval" },
  { key: "totalPets", label: "Total pets" },
  { key: "totalProducts", label: "Total products" },
  { key: "totalOrders", label: "Total orders" },
  { key: "totalCustomers", label: "Total customers" },
];

export function AdminDashboard() {
  const [stats, setStats] = useState(null);
  const [pendingShops, setPendingShops] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoading(true);
      const [
        totalShops,
        pendingShopsCount,
        totalPets,
        totalProducts,
        totalOrders,
        totalCustomers,
        recentPending,
      ] = await Promise.all([
        supabase.from("shops").select("id", { count: "exact", head: true }),
        supabase.from("shops").select("id", { count: "exact", head: true }).eq("status", "pending"),
        supabase.from("pets").select("id", { count: "exact", head: true }),
        supabase.from("products").select("id", { count: "exact", head: true }),
        supabase.from("orders").select("id", { count: "exact", head: true }),
        supabase.from("profiles").select("id", { count: "exact", head: true }).eq("role", "customer"),
        supabase.from("shops").select("*").eq("status", "pending").order("created_at", { ascending: false }).limit(5),
      ]);

      if (cancelled) return;

      setStats({
        totalShops: totalShops.count ?? 0,
        pendingShops: pendingShopsCount.count ?? 0,
        totalPets: totalPets.count ?? 0,
        totalProducts: totalProducts.count ?? 0,
        totalOrders: totalOrders.count ?? 0,
        totalCustomers: totalCustomers.count ?? 0,
      });
      setPendingShops(recentPending.data ?? []);
      setLoading(false);
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-bold text-ink">Admin dashboard</h1>
      <p className="mt-1 text-[15px] text-ink-soft">A platform-wide snapshot of shops, listings, and orders.</p>

      <div className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-3">
        {STAT_DEFS.map((def) => (
          <div key={def.key} className="rounded-xl border border-border bg-surface p-5">
            <div className="font-display text-3xl font-bold text-ink">
              {loading ? "—" : stats[def.key]}
            </div>
            <div className="mt-1 text-sm text-ink-soft">{def.label}</div>
          </div>
        ))}
      </div>

      <div className="mt-10">
        <h2 className="font-display text-xl font-semibold text-ink">Needs your attention</h2>
        <p className="mt-1 text-sm text-ink-soft">Shops awaiting approval, most recent first.</p>

        {!loading && pendingShops.length === 0 && (
          <p className="mt-4 text-[15px] text-ink-soft">No shops are currently pending approval.</p>
        )}

        {pendingShops.length > 0 && (
          <ul className="mt-4 divide-y divide-border rounded-xl border border-border bg-surface">
            {pendingShops.map((shop) => (
              <li key={shop.id} className="flex items-center justify-between gap-4 p-4">
                <div>
                  <div className="font-medium text-ink">{shop.name}</div>
                  <div className="text-sm text-ink-soft">{shop.address}</div>
                </div>
                <span className="text-sm text-ink-soft">pending</span>
              </li>
            ))}
          </ul>
        )}

        <Button to="/admin/shops" variant="accent" size="md" className="mt-6">
          Review shops
        </Button>
      </div>
    </Container>
  );
}
