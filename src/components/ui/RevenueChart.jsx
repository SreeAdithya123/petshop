import { useMemo, useState } from "react";
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { formatPrice } from "../../lib/format";

const RANGES = [
  { value: "week", label: "Week" },
  { value: "month", label: "Month" },
  { value: "year", label: "Year" },
];

const WEEKDAY_LABEL = new Intl.DateTimeFormat("en-US", { weekday: "short" });
const MONTH_LABEL = new Intl.DateTimeFormat("en-US", { month: "short" });

/** Builds N empty buckets ending today, then sums order totals into them by date. */
function bucketize(orders, range) {
  const now = new Date();
  const buckets = [];

  if (range === "week") {
    for (let i = 6; i >= 0; i -= 1) {
      const day = new Date(now);
      day.setDate(now.getDate() - i);
      buckets.push({ key: day.toDateString(), label: WEEKDAY_LABEL.format(day), amount: 0 });
    }
    for (const order of orders) {
      const date = new Date(order.created_at);
      const bucket = buckets.find((b) => b.key === date.toDateString());
      if (bucket) bucket.amount += Number(order.total_amount) || 0;
    }
  } else if (range === "month") {
    // 5 weekly buckets covering the last ~35 days.
    for (let i = 4; i >= 0; i -= 1) {
      const end = new Date(now);
      end.setDate(now.getDate() - i * 7);
      const start = new Date(end);
      start.setDate(end.getDate() - 6);
      buckets.push({
        key: `${start.toDateString()}-${end.toDateString()}`,
        label: `${start.getDate()}/${start.getMonth() + 1}`,
        amount: 0,
        start,
        end,
      });
    }
    for (const order of orders) {
      const date = new Date(order.created_at);
      const bucket = buckets.find((b) => date >= startOfDay(b.start) && date <= endOfDay(b.end));
      if (bucket) bucket.amount += Number(order.total_amount) || 0;
    }
  } else {
    for (let i = 11; i >= 0; i -= 1) {
      const month = new Date(now.getFullYear(), now.getMonth() - i, 1);
      buckets.push({
        key: `${month.getFullYear()}-${month.getMonth()}`,
        label: MONTH_LABEL.format(month),
        amount: 0,
      });
    }
    for (const order of orders) {
      const date = new Date(order.created_at);
      const key = `${date.getFullYear()}-${date.getMonth()}`;
      const bucket = buckets.find((b) => b.key === key);
      if (bucket) bucket.amount += Number(order.total_amount) || 0;
    }
  }

  return buckets;
}

function startOfDay(date) {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function endOfDay(date) {
  const copy = new Date(date);
  copy.setHours(23, 59, 59, 999);
  return copy;
}

function TooltipContent({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-lg border border-border bg-surface px-3 py-2 text-sm shadow-lg">
      <p className="text-ink-soft">{label}</p>
      <p className="font-display font-semibold text-ink">{formatPrice(payload[0].value)}</p>
    </div>
  );
}

/**
 * Revenue tracker with a week/month/year range toggle, used on both the
 * seller and admin dashboards. `orders` is the full set of relevant orders
 * (own-shop orders for sellers, every order for admin) as
 * {created_at, total_amount} rows -- aggregation happens client-side since
 * order volume here is small enough that a dedicated SQL rollup isn't
 * warranted yet.
 */
export function RevenueChart({ orders }) {
  const [range, setRange] = useState("month");

  const buckets = useMemo(() => bucketize(orders, range), [orders, range]);
  const total = useMemo(() => buckets.reduce((sum, b) => sum + b.amount, 0), [buckets]);

  return (
    <div className="rounded-xl border border-border bg-surface p-5">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="font-display text-xl font-semibold text-ink">Revenue</h2>
          <p className="mt-1 font-display text-2xl font-bold text-accent">{formatPrice(total)}</p>
        </div>
        <div className="flex gap-1 rounded-lg border border-border p-1">
          {RANGES.map((r) => (
            <button
              key={r.value}
              type="button"
              onClick={() => setRange(r.value)}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                range === r.value ? "bg-primary text-white" : "text-ink-soft hover:text-ink"
              }`}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-5 h-64">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={buckets} margin={{ top: 4, right: 8, left: 8, bottom: 4 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" vertical={false} />
            <XAxis
              dataKey="label"
              tick={{ fontSize: 12, fill: "#64748b" }}
              axisLine={{ stroke: "#e2e8f0" }}
              tickLine={false}
            />
            <YAxis
              tick={{ fontSize: 12, fill: "#64748b" }}
              axisLine={false}
              tickLine={false}
              width={48}
              tickFormatter={(value) => (value >= 1000 ? `${Math.round(value / 1000)}k` : value)}
            />
            <Tooltip content={<TooltipContent />} cursor={{ fill: "#4f46e5", opacity: 0.08 }} />
            <Bar dataKey="amount" fill="#4f46e5" radius={[6, 6, 0, 0]} maxBarSize={48} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
