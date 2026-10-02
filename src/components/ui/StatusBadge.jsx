const TONES = {
  good: "bg-trust/10 text-trust",
  pending: "bg-warning/15 text-amber-700",
  active: "bg-primary/10 text-primary",
  bad: "bg-error/10 text-error",
  muted: "bg-ink/5 text-ink-soft",
};

const STATUS_TONE = {
  // demo requests, bookings, requests, refunds, orders, tickets, services
  pending: "pending",
  open: "active",
  quoted: "active",
  in_progress: "active",
  approved: "good",
  confirmed: "good",
  accepted: "good",
  completed: "good",
  resolved: "good",
  paid: "good",
  fulfilled: "good",
  available: "good",
  reserved: "pending",
  sold: "muted",
  rejected: "bad",
  declined: "bad",
  cancelled: "bad",
  suspended: "bad",
  closed: "muted",
};

function titleCase(value) {
  const text = String(value).replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** Colored pill for any status string. `label` overrides the text. */
export function StatusBadge({ status, label, className = "" }) {
  const tone = TONES[STATUS_TONE[status] ?? "muted"];
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ${tone} ${className}`}
    >
      {label ?? titleCase(status)}
    </span>
  );
}
