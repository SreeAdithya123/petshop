import { formatOrderDate, formatPrice } from "../../lib/format";
import { Button } from "../ui/Button";
import { StatusBadge } from "../ui/StatusBadge";
import { shortOrderId } from "./helpers";
import { Meta, MetaList } from "./Meta";
import { orderTypeLabel, PET_STATUS_LABELS } from "./orderData";

const BUSY_LABELS = {
  paid: "Marking paid…",
  fulfilled: "Marking handed over…",
  cancelled: "Cancelling…",
};

/**
 * One order that includes this shop's items, with the next-step actions: Mark
 * paid (pending), Mark handed over (paid) and Cancel order (pending or paid).
 * Payment and pickup happen in person, so the shop owner records each step.
 *
 * `busyStatus` is the status being applied to this order right now (null when
 * idle); `locked` disables the actions while any order is being updated.
 * `onAction(status)` asks to move the order to 'paid', 'fulfilled' or 'cancelled'.
 */
export function OrderCard({ order, readOnly, busyStatus, locked, onAction }) {
  const pending = order.status === "pending";
  const paid = order.status === "paid";
  const canAct = !readOnly && (pending || paid);
  const showOrderTotal = Math.abs(order.total_amount - order.shopSubtotal) > 0.5;
  const disabled = locked || busyStatus !== null;

  return (
    <article className="rounded-xl border border-border bg-surface p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[15px] font-medium text-ink">
            {orderTypeLabel(order.order_type)} <span className="text-ink-soft">{shortOrderId(order.id)}</span>
          </h3>
          <p className="text-sm text-ink-soft">
            {order.customerName} &middot; {formatOrderDate(order.created_at)}
          </p>
        </div>
        <StatusBadge status={order.status} />
      </div>

      <ul className="mt-4 divide-y divide-border border-y border-border">
        {order.lines.map((line) => (
          <li key={line.key} className="flex items-start justify-between gap-4 py-2.5">
            <div className="min-w-0">
              <p className="text-sm text-ink">
                {line.name}
                {line.quantity > 1 && <span className="text-ink-soft"> &times; {line.quantity}</span>}
              </p>
              {line.petStatus && (
                <StatusBadge
                  status={line.petStatus}
                  label={PET_STATUS_LABELS[line.petStatus] ?? `Pet ${line.petStatus}`}
                  className="mt-1"
                />
              )}
            </div>
            <p className="flex-none text-sm text-ink-soft">{formatPrice(line.total)}</p>
          </li>
        ))}
      </ul>

      <MetaList className="mt-4">
        <Meta label="Your items">{formatPrice(order.shopSubtotal)}</Meta>
        {showOrderTotal && <Meta label="Order total">{formatPrice(order.total_amount)}</Meta>}
        <Meta label="Payment">{order.payment_type === "deposit" ? "Deposit" : "Full payment"}</Meta>
      </MetaList>

      {canAct && (
        <div className="mt-4 border-t border-border pt-4">
          <p className="text-sm text-ink-soft">
            {pending
              ? "Mark this order paid once you have received the payment in person."
              : "Mark this order handed over once the customer has collected everything."}
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            {pending && (
              <Button type="button" variant="accent" size="sm" onClick={() => onAction("paid")} disabled={disabled}>
                {busyStatus === "paid" ? BUSY_LABELS.paid : "Mark paid"}
              </Button>
            )}
            {paid && (
              <Button
                type="button"
                variant="accent"
                size="sm"
                onClick={() => onAction("fulfilled")}
                disabled={disabled}
              >
                {busyStatus === "fulfilled" ? BUSY_LABELS.fulfilled : "Mark handed over"}
              </Button>
            )}
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onAction("cancelled")}
              disabled={disabled}
              className="border-error! text-error! hover:bg-error/5!"
            >
              {busyStatus === "cancelled" ? BUSY_LABELS.cancelled : "Cancel order"}
            </Button>
          </div>
        </div>
      )}

      <div className="mt-3">
        <Button
          to="/seller/support"
          variant="ghost"
          size="sm"
          title="Customers write to your shop from Support; reply to their ticket there"
          className="-ml-3"
        >
          Message customer
        </Button>
      </div>
    </article>
  );
}
