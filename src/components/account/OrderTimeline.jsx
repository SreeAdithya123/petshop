import { Check, X } from "@phosphor-icons/react";

function isPetOrder(orderType) {
  return orderType === "pet_reservation" || orderType === "gift";
}

function titleCase(value) {
  const text = String(value ?? "").replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/**
 * Plain-words explanation of where an order stands. Nothing ships: the shop
 * arranges pickup and the customer pays in person.
 */
export function orderTimelineText(status, orderType) {
  switch (status) {
    case "pending":
      return `${isPetOrder(orderType) ? "Reserved" : "Placed"} — the shop will contact you to arrange pickup; pay in person.`;
    case "paid":
      return "Paid — the shop has received your payment and will hand your order over at pickup.";
    case "fulfilled":
      return "Handed over — pickup is complete. If something isn't right, you can request a refund.";
    case "cancelled":
      return "Cancelled — the items went back to the shop. If you had already paid in person, message the shop about getting your money back.";
    default:
      return titleCase(status);
  }
}

const REACHED_STEP = { pending: 0, paid: 1, fulfilled: 2 };

function Dot({ index, state }) {
  const base = "flex h-6 w-6 flex-none items-center justify-center rounded-full text-xs";
  if (state === "done") {
    return (
      <span className={`${base} bg-primary text-white`}>
        <Check size={14} weight="bold" />
      </span>
    );
  }
  if (state === "ended") {
    return (
      <span className={`${base} bg-error text-white`}>
        <X size={14} weight="bold" />
      </span>
    );
  }
  if (state === "next") {
    return <span className={`${base} border-2 border-primary bg-surface text-primary`}>{index + 1}</span>;
  }
  return <span className={`${base} border border-border bg-surface text-ink-soft`}>{index + 1}</span>;
}

/**
 * Reserved / Placed -> Paid -> Handed over, or a terminal "Cancelled".
 * Decorative: the sentence from orderTimelineText carries the meaning for
 * screen readers.
 */
export function OrderTimeline({ status, orderType }) {
  const first = isPetOrder(orderType) ? "Reserved" : "Placed";
  const cancelled = status === "cancelled";
  const labels = cancelled ? [first, "Cancelled"] : [first, "Paid", "Handed over"];
  const reached = cancelled ? 1 : (REACHED_STEP[status] ?? 0);
  const last = labels.length - 1;

  function stateAt(index) {
    if (cancelled) return index === 0 ? "done" : "ended";
    if (index <= reached) return "done";
    return index === reached + 1 ? "next" : "todo";
  }

  return (
    <ol aria-hidden="true" className="flex">
      {labels.map((label, index) => {
        const state = stateAt(index);
        const emphasised = state === "done" || state === "ended";
        return (
          <li key={label} className="flex-1">
            <div className="flex items-center">
              <span
                className={`h-0.5 flex-1 ${index === 0 ? "bg-transparent" : index <= reached ? "bg-primary" : "bg-border"}`}
              />
              <Dot index={index} state={state} />
              <span
                className={`h-0.5 flex-1 ${index === last ? "bg-transparent" : index < reached ? "bg-primary" : "bg-border"}`}
              />
            </div>
            <p
              className={`mt-1 text-center text-xs ${emphasised ? "font-medium" : ""} ${
                state === "ended" ? "text-error" : state === "done" ? "text-ink" : "text-ink-soft"
              }`}
            >
              {label}
            </p>
          </li>
        );
      })}
    </ol>
  );
}
