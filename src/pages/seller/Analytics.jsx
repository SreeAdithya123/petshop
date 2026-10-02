import { useEffect, useMemo, useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { RevenueChart } from "../../components/ui/RevenueChart";
import { useMyShop } from "../../hooks/useMyShop";
import { supabase } from "../../lib/supabaseClient";
import { formatPrice } from "../../lib/format";

const RANGES = [
  { value: "7d", label: "7 days", days: 7 },
  { value: "30d", label: "30 days", days: 30 },
  { value: "12m", label: "12 months", months: 12 },
  { value: "all", label: "All time" },
];

const ITEM_TYPES = [
  { value: "pet", label: "Pets" },
  { value: "product", label: "Products" },
  { value: "service", label: "Services" },
];

const TYPE_LABELS = { pet: "Pet", product: "Product", service: "Service" };

const ORDER_STATUSES = ["pending", "paid", "fulfilled", "cancelled"];
const STATUS_BAR_TONES = {
  pending: "bg-warning",
  paid: "bg-primary",
  fulfilled: "bg-trust",
  cancelled: "bg-error",
};

const PAGE_SIZE = 1000;
const ID_CHUNK_SIZE = 100;

/** First moment of the selected range, or null for "all time". */
function rangeStart(range) {
  const now = new Date();
  if (range.days) {
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    start.setDate(start.getDate() - (range.days - 1));
    return start;
  }
  if (range.months) return new Date(now.getFullYear(), now.getMonth() - (range.months - 1), 1);
  return null;
}

function chunk(list, size) {
  const chunks = [];
  for (let i = 0; i < list.length; i += size) chunks.push(list.slice(i, i + size));
  return chunks;
}

/** Pages through a query past PostgREST's row cap so totals are never silently truncated. */
async function fetchAll(buildQuery) {
  const rows = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await buildQuery()
      .order("id")
      .range(from, from + PAGE_SIZE - 1);
    if (error) throw error;
    rows.push(...data);
    if (data.length < PAGE_SIZE) return rows;
  }
}

function petLabel(pet) {
  const detail = pet.breed ? `${pet.breed} (${pet.species})` : pet.species;
  return pet.name ? `${pet.name} · ${detail}` : detail;
}

/**
 * Everything the page needs in a handful of requests: the shop's own listing
 * ids (to scope order_items, same approach as the seller dashboard/orders
 * pages), the matching order lines with their order, and demo / booking rows.
 * Revenue is priced per line (price_at_purchase * quantity) so an order that
 * mixes several shops is never double counted.
 */
async function loadShopAnalytics(shopId) {
  const [pets, products, services, demos, bookings] = await Promise.all([
    fetchAll(() => supabase.from("pets").select("id, name, breed, species").eq("shop_id", shopId)),
    fetchAll(() => supabase.from("products").select("id, name").eq("shop_id", shopId)),
    fetchAll(() => supabase.from("services").select("id, name").eq("shop_id", shopId)),
    fetchAll(() => supabase.from("demo_requests").select("id, status, created_at").eq("shop_id", shopId)),
    fetchAll(() => supabase.from("service_bookings").select("id, status, created_at").eq("shop_id", shopId)),
  ]);

  const listings = new Map();
  pets.forEach((pet) => listings.set(pet.id, { type: "pet", label: petLabel(pet) }));
  products.forEach((product) => listings.set(product.id, { type: "product", label: product.name }));
  services.forEach((service) => listings.set(service.id, { type: "service", label: service.name }));

  const itemRows = (
    await Promise.all(
      chunk([...listings.keys()], ID_CHUNK_SIZE).map((ids) =>
        fetchAll(() =>
          supabase
            .from("order_items")
            .select("id, item_id, quantity, price_at_purchase, orders(id, status, created_at, order_type)")
            .in("item_id", ids),
        ),
      ),
    )
  ).flat();

  const lines = [];
  for (const row of itemRows) {
    const order = Array.isArray(row.orders) ? row.orders[0] : row.orders;
    const listing = listings.get(row.item_id);
    if (!order || !listing) continue;
    const quantity = Number(row.quantity) || 1;
    lines.push({
      orderId: order.id,
      orderStatus: order.status,
      createdAt: order.created_at,
      itemId: row.item_id,
      type: listing.type,
      label: listing.label,
      quantity,
      amount: (Number(row.price_at_purchase) || 0) * quantity,
    });
  }

  return { listingCount: listings.size, lines, demos, bookings };
}

function countBy(values) {
  const counts = {};
  for (const value of values) counts[value] = (counts[value] ?? 0) + 1;
  return counts;
}

/** Turns the raw rows into everything the page renders for one date range. */
function summarize(data, range) {
  const start = rangeStart(range);
  const inRange = (value) => !start || new Date(value) >= start;

  const orderStatuses = new Map();
  const revenueOrders = new Map();
  const revenueByType = { pet: 0, product: 0, service: 0 };
  const topItems = new Map();
  let itemsSold = 0;

  for (const line of data.lines) {
    if (!inRange(line.createdAt)) continue;
    orderStatuses.set(line.orderId, line.orderStatus);
    if (line.orderStatus === "cancelled") continue;

    const order = revenueOrders.get(line.orderId) ?? { created_at: line.createdAt, total_amount: 0 };
    order.total_amount += line.amount;
    revenueOrders.set(line.orderId, order);

    revenueByType[line.type] += line.amount;
    itemsSold += line.quantity;

    const top = topItems.get(line.itemId) ?? {
      id: line.itemId,
      label: line.label,
      type: line.type,
      units: 0,
      revenue: 0,
    };
    top.units += line.quantity;
    top.revenue += line.amount;
    topItems.set(line.itemId, top);
  }

  const chartOrders = [...revenueOrders.values()];
  const revenue = chartOrders.reduce((sum, order) => sum + order.total_amount, 0);
  const demos = data.demos.filter((demo) => inRange(demo.created_at));
  const bookings = data.bookings.filter((booking) => inRange(booking.created_at));

  return {
    revenue,
    orderCount: chartOrders.length,
    averageOrder: chartOrders.length > 0 ? revenue / chartOrders.length : 0,
    itemsSold,
    chartOrders,
    statusCounts: countBy(orderStatuses.values()),
    revenueByType,
    topItems: [...topItems.values()].sort((a, b) => b.revenue - a.revenue).slice(0, 5),
    demoCounts: countBy(demos.map((demo) => demo.status)),
    demoTotal: demos.length,
    bookingCounts: countBy(bookings.map((booking) => booking.status)),
    bookingTotal: bookings.length,
  };
}

function share(value, total) {
  return total > 0 ? Math.round((value / total) * 100) : 0;
}

export function SellerAnalytics() {
  const { shop, loading: shopLoading, error: shopError } = useMyShop();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [rangeValue, setRangeValue] = useState("30d");

  useEffect(() => {
    if (!shop) return undefined;
    let cancelled = false;

    loadShopAnalytics(shop.id)
      .then((result) => {
        if (cancelled) return;
        setData(result);
        setError(null);
      })
      .catch((loadError) => {
        if (!cancelled) setError(loadError.message || "Something went wrong loading your analytics.");
      });

    return () => {
      cancelled = true;
    };
  }, [shop, reloadKey]);

  const range = RANGES.find((option) => option.value === rangeValue) ?? RANGES[1];
  const summary = useMemo(() => (data ? summarize(data, range) : null), [data, range]);

  function retry() {
    setError(null);
    setReloadKey((key) => key + 1);
  }

  if (!shopLoading && !shop) {
    return (
      <Container className="py-12">
        {shopError ? (
          <p className="text-[15px] text-error">Couldn't load your shop: {shopError}</p>
        ) : (
          <EmptyState
            title="You haven't set up your shop yet"
            description="Create your shop profile to start listing pets and products."
            action={
              <Button to="/seller/store" size="sm">
                Set up your shop
              </Button>
            }
          />
        )}
      </Container>
    );
  }

  const loading = shopLoading || (!data && !error);

  return (
    <Container className="py-12">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-bold text-ink">Analytics</h1>
          <p className="mt-1 text-[15px] text-ink-soft">
            How your shop is doing, based on orders that include your pets, products and services.
          </p>
        </div>
        <div role="group" aria-label="Date range" className="flex gap-1 rounded-lg border border-border p-1">
          {RANGES.map((option) => (
            <button
              key={option.value}
              type="button"
              aria-pressed={option.value === range.value}
              onClick={() => setRangeValue(option.value)}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                option.value === range.value ? "bg-primary text-white" : "text-ink-soft hover:text-ink"
              }`}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <p className="mt-8 text-[15px] text-ink-soft">Loading analytics…</p>
      ) : error ? (
        <div className="mt-8 flex flex-col items-start gap-3">
          <p className="text-[15px] text-error">Couldn't load analytics: {error}</p>
          <Button type="button" variant="outline" size="sm" onClick={retry}>
            Try again
          </Button>
        </div>
      ) : data.listingCount === 0 && data.demos.length === 0 && data.bookings.length === 0 ? (
        <EmptyState
          title="Nothing to analyse yet"
          description="List a pet, product or service and your sales and requests will be summarised here."
          action={
            <Button to="/seller/pets" size="sm">
              Add a listing
            </Button>
          }
        />
      ) : (
        <AnalyticsBody summary={summary} range={range} />
      )}
    </Container>
  );
}

function AnalyticsBody({ summary, range }) {
  const { statusCounts, revenueByType, demoCounts } = summary;

  const statusRows = [
    ...ORDER_STATUSES,
    ...Object.keys(statusCounts).filter((status) => !ORDER_STATUSES.includes(status)),
  ].map((status) => ({
    key: status,
    label: <span className="capitalize">{status}</span>,
    value: statusCounts[status] ?? 0,
    tone: STATUS_BAR_TONES[status] ?? "bg-ink-soft",
  }));
  const totalOrders = statusRows.reduce((sum, row) => sum + row.value, 0);

  const typeRows = ITEM_TYPES.map((type) => ({
    key: type.value,
    label: type.label,
    value: revenueByType[type.value],
    tone: "bg-accent",
  }));
  const totalRevenue = typeRows.reduce((sum, row) => sum + row.value, 0);

  const demoRows = [
    { key: "requested", label: "Requested", value: summary.demoTotal, tone: "bg-primary" },
    { key: "approved", label: "Approved", value: demoCounts.approved ?? 0, tone: "bg-trust" },
    { key: "completed", label: "Completed", value: demoCounts.completed ?? 0, tone: "bg-trust" },
    { key: "rejected", label: "Rejected", value: demoCounts.rejected ?? 0, tone: "bg-error" },
  ];

  const cancelledCount = statusCounts.cancelled ?? 0;
  const pendingDemos = demoCounts.pending ?? 0;
  const pendingBookings = summary.bookingCounts.pending ?? 0;

  return (
    <>
      <div className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-3">
        <StatCard label="Revenue" value={formatPrice(summary.revenue)} hint="Cancelled orders excluded" />
        <StatCard
          label="Orders"
          value={summary.orderCount}
          hint={cancelledCount > 0 ? `${cancelledCount} cancelled` : undefined}
        />
        <StatCard label="Average order value" value={formatPrice(summary.averageOrder)} />
        <StatCard label="Items sold" value={summary.itemsSold} />
        <StatCard
          label="Demo requests"
          value={summary.demoTotal}
          hint={pendingDemos > 0 ? `${pendingDemos} awaiting reply` : undefined}
        />
        <StatCard
          label="Service bookings"
          value={summary.bookingTotal}
          hint={pendingBookings > 0 ? `${pendingBookings} awaiting reply` : undefined}
        />
      </div>

      <div className="mt-10">
        {summary.chartOrders.length > 0 ? (
          <RevenueChart orders={summary.chartOrders} />
        ) : (
          <Card title="Revenue">
            <EmptyText>
              {range.value === "all"
                ? "No orders yet. Orders for your pets, products and services will show up here."
                : "No orders in this range. Try a wider date range to see more of your sales."}
            </EmptyText>
          </Card>
        )}
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <Card title="Orders by status" subtitle="Every order in range, including cancelled ones.">
          {totalOrders === 0 ? (
            <EmptyText>No orders in this range.</EmptyText>
          ) : (
            <BarList rows={statusRows} total={totalOrders} />
          )}
        </Card>

        <Card title="Revenue by type" subtitle="Where your revenue comes from.">
          {totalRevenue === 0 ? (
            <EmptyText>No revenue in this range.</EmptyText>
          ) : (
            <BarList rows={typeRows} total={totalRevenue} format={formatPrice} />
          )}
        </Card>
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <Card title="Top items" subtitle="Your five best sellers by revenue.">
          {summary.topItems.length === 0 ? (
            <EmptyText>No sales in this range.</EmptyText>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="text-ink-soft">
                    <th scope="col" className="pb-2 font-medium">
                      Item
                    </th>
                    <th scope="col" className="pb-2 text-right font-medium">
                      Units
                    </th>
                    <th scope="col" className="pb-2 text-right font-medium">
                      Revenue
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {summary.topItems.map((item) => (
                    <tr key={item.id}>
                      <td className="py-3 pr-3">
                        <p className="text-ink">{item.label}</p>
                        <p className="text-xs text-ink-soft">{TYPE_LABELS[item.type]}</p>
                      </td>
                      <td className="py-3 text-right text-ink">{item.units}</td>
                      <td className="py-3 text-right font-medium text-accent">{formatPrice(item.revenue)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        <Card title="Demo funnel" subtitle="What happens to the demo requests you receive.">
          {summary.demoTotal === 0 ? (
            <EmptyText>No demo requests in this range.</EmptyText>
          ) : (
            <BarList rows={demoRows} total={summary.demoTotal} max={summary.demoTotal} />
          )}
        </Card>
      </div>
    </>
  );
}

function StatCard({ label, value, hint }) {
  return (
    <div className="rounded-xl border border-border bg-surface px-5 py-4">
      <p className="text-sm text-ink-soft">{label}</p>
      <p className="mt-1 break-words font-display text-2xl font-semibold text-ink">{value}</p>
      {hint && <p className="mt-1 text-xs text-ink-soft">{hint}</p>}
    </div>
  );
}

function Card({ title, subtitle, children }) {
  return (
    <section className="rounded-xl border border-border bg-surface p-5">
      <h2 className="font-display text-xl font-semibold text-ink">{title}</h2>
      {subtitle && <p className="mt-1 text-sm text-ink-soft">{subtitle}</p>}
      <div className="mt-4">{children}</div>
    </section>
  );
}

function EmptyText({ children }) {
  return <p className="text-[15px] text-ink-soft">{children}</p>;
}

/**
 * Horizontal bars with a readable figure beside each. Widths are relative to
 * the largest row (or `max`); the percentage is each row's share of `total`.
 */
function BarList({ rows, total, max, format = String }) {
  const scale = max ?? Math.max(0, ...rows.map((row) => row.value));
  return (
    <ul className="flex flex-col gap-4">
      {rows.map((row) => {
        const width = scale > 0 && row.value > 0 ? Math.max((row.value / scale) * 100, 2) : 0;
        return (
          <li key={row.key}>
            <div className="flex items-baseline justify-between gap-3 text-sm">
              <span className="text-ink">{row.label}</span>
              <span className="text-ink-soft">
                {format(row.value)} &middot; {share(row.value, total)}%
              </span>
            </div>
            <div aria-hidden="true" className="mt-1.5 h-2 rounded-full bg-ink/5">
              <div className={`h-2 rounded-full ${row.tone}`} style={{ width: `${width}%` }} />
            </div>
          </li>
        );
      })}
    </ul>
  );
}
