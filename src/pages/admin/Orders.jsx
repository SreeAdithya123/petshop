import { useEffect, useMemo, useState } from "react";
import { supabase } from "../../lib/supabaseClient";
import { Container } from "../../components/layout/Container";
import { EmptyState } from "../../components/ui/EmptyState";

const STATUS_OPTIONS = ["all", "pending", "paid", "fulfilled", "cancelled"];

const STATUS_STYLES = {
  paid: "text-trust",
  fulfilled: "text-trust",
  pending: "text-ink-soft",
  cancelled: "text-error",
};

function formatCurrency(amount) {
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(amount ?? 0);
}

function formatDate(value) {
  return new Date(value).toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
}

export function AdminOrders() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("all");

  useEffect(() => {
    async function load() {
      setLoading(true);
      const { data } = await supabase
        .from("orders")
        .select("*, profiles(name,email)")
        .order("created_at", { ascending: false });
      setOrders(data ?? []);
      setLoading(false);
    }
    load();
  }, []);

  const filteredOrders = useMemo(() => {
    if (statusFilter === "all") return orders;
    return orders.filter((order) => order.status === statusFilter);
  }, [orders, statusFilter]);

  return (
    <Container className="py-12">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="font-display text-3xl font-bold text-ink">All orders</h1>
          <p className="mt-1 text-[15px] text-ink-soft">Every order placed across the platform.</p>
        </div>
        <select
          value={statusFilter}
          onChange={(event) => setStatusFilter(event.target.value)}
          className="rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink"
        >
          {STATUS_OPTIONS.map((option) => (
            <option key={option} value={option}>
              {option === "all" ? "All statuses" : option}
            </option>
          ))}
        </select>
      </div>

      {!loading && filteredOrders.length === 0 && (
        <div className="mt-8">
          <EmptyState
            title="No orders found"
            description={
              orders.length === 0
                ? "Orders will appear here once customers start purchasing."
                : "No orders match the selected status."
            }
          />
        </div>
      )}

      {filteredOrders.length > 0 && (
        <ul className="mt-8 divide-y divide-border rounded-xl border border-border bg-surface">
          {filteredOrders.map((order) => (
            <li key={order.id} className="flex flex-col gap-2 p-5 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <div className="font-display font-semibold text-ink">
                  {order.order_type.replace("_", " ")} · {formatCurrency(order.total_amount)}
                </div>
                <div className="mt-1 text-sm text-ink-soft">
                  {order.profiles?.name ?? "Unknown customer"}
                  {order.profiles?.email ? ` · ${order.profiles.email}` : ""}
                </div>
                <div className="mt-1 text-sm text-ink-soft">
                  {order.payment_type === "deposit" ? "Deposit payment" : "Full payment"} · {formatDate(order.created_at)}
                </div>
              </div>
              <div className={`text-sm font-medium ${STATUS_STYLES[order.status] ?? "text-ink-soft"}`}>
                {order.status}
              </div>
            </li>
          ))}
        </ul>
      )}
    </Container>
  );
}
