import { useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { AccountPageHeader, ErrorNote, LoadingNote } from "../../components/account/AccountPage";
import {
  groupItemsByShop,
  orderTypeLabel,
  shortOrderId,
  useOrderItems,
} from "../../components/account/accountHelpers";
import { Button } from "../../components/ui/Button";
import { Field } from "../../components/ui/FormField";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { formatDate, formatOrderDate, formatPrice } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { useAuthStore } from "../../store/authStore";

const REASONS = ["Pet unwell", "Not as described", "Wrong item", "Changed my mind", "Other"];

function describeOrder(order) {
  return `${orderTypeLabel(order.order_type)} · ${formatDate(order.created_at)} · ${formatPrice(order.total_amount)} · #${shortOrderId(order.id)}`;
}

function RefundCard({ refund }) {
  const items = useOrderItems(refund.order_id);
  const shopName = items.items.find((item) => item.shopId === refund.shop_id)?.shopName;
  const hasAmount = refund.amount !== null && refund.amount !== undefined;

  return (
    <article className="rounded-xl border border-border bg-surface p-4 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-2">
        <div className="min-w-0">
          <h3 className="break-words text-[15px] font-medium text-ink">{refund.item_label || "Refund request"}</h3>
          <p className="mt-0.5 text-sm text-ink-soft">
            {shopName && `${shopName} · `}
            <Link to="/account/orders" className="hover:text-primary hover:underline">
              Order #{shortOrderId(refund.order_id)}
            </Link>
          </p>
        </div>
        <div className="flex items-center gap-3">
          <StatusBadge status={refund.status} />
          {hasAmount && (
            <p className="font-display text-lg font-semibold text-accent">{formatPrice(refund.amount)}</p>
          )}
        </div>
      </div>

      <div className="mt-3 flex flex-col gap-1 text-sm text-ink-soft">
        <p>Reason: {refund.reason}</p>
        {refund.notes && <p className="break-words">“{refund.notes}”</p>}
        <p>Requested {formatOrderDate(refund.created_at)}</p>
        {refund.resolved_at && <p>Resolved {formatOrderDate(refund.resolved_at)}</p>}
      </div>
    </article>
  );
}

export function AccountRefunds() {
  const userId = useAuthStore((state) => state.session?.user?.id);
  const [searchParams] = useSearchParams();

  const [data, setData] = useState(null);
  const [loadError, setLoadError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);

  const [selectedOrderId, setSelectedOrderId] = useState(searchParams.get("order") ?? "");
  const [selectedShopId, setSelectedShopId] = useState("");
  const [reason, setReason] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState("");

  useEffect(() => {
    if (!userId) return undefined;
    let cancelled = false;

    async function load() {
      const [ordersResult, refundsResult] = await Promise.all([
        supabase
          .from("orders")
          .select("id, order_type, status, total_amount, created_at")
          .eq("customer_id", userId)
          .neq("status", "cancelled")
          .order("created_at", { ascending: false }),
        supabase
          .from("refunds")
          .select("id, order_id, shop_id, reason, notes, amount, status, item_label, created_at, resolved_at")
          .eq("customer_id", userId)
          .order("created_at", { ascending: false }),
      ]);
      if (cancelled) return;

      const failure = ordersResult.error || refundsResult.error;
      if (failure) {
        setLoadError(failure.message);
        return;
      }
      setData({ orders: ordersResult.data ?? [], refunds: refundsResult.data ?? [] });
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [userId, reloadKey]);

  const orders = data?.orders ?? [];
  const refunds = data?.refunds ?? [];

  // Ignore a stale/unknown ?order= id rather than selecting something that isn't in the list.
  const orderId = orders.some((order) => order.id === selectedOrderId) ? selectedOrderId : "";
  const unknownPreselect = Boolean(data && selectedOrderId && !orderId);

  const items = useOrderItems(orderId);
  const groups = groupItemsByShop(items.items);
  const refundsForOrder = new Map(
    refunds.filter((refund) => refund.order_id === orderId).map((refund) => [refund.shop_id, refund]),
  );
  const openGroups = groups.filter((group) => !refundsForOrder.has(group.shopId));
  const shopId = openGroups.some((group) => group.shopId === selectedShopId)
    ? selectedShopId
    : openGroups.length === 1
      ? openGroups[0].shopId
      : "";

  function retryLoad() {
    setLoadError("");
    setData(null);
    setReloadKey((key) => key + 1);
  }

  function handleOrderChange(event) {
    setSelectedOrderId(event.target.value);
    setSelectedShopId("");
    setErrors((current) => ({ ...current, order: undefined, shop: undefined }));
    setSuccess("");
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    setSuccess("");

    const nextErrors = {};
    if (!orderId) nextErrors.order = "Choose the order this refund is for.";
    else if (!shopId) nextErrors.shop = "Choose what the refund is for.";
    if (!reason) nextErrors.reason = "Tell us why you're asking for a refund.";
    if (reason === "Other" && !notes.trim()) nextErrors.notes = "Add a few words so the shop knows what happened.";
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    const group = groups.find((candidate) => candidate.shopId === shopId);
    setSubmitting(true);
    // The server fills in the amount (that shop's total on the order) and the pending status.
    const { error } = await supabase.from("refunds").insert({
      order_id: orderId,
      customer_id: userId,
      shop_id: shopId,
      reason,
      item_label: group.labels.join(", "),
      ...(notes.trim() && { notes: notes.trim() }),
    });
    setSubmitting(false);

    if (error) {
      setFormError(error.message);
      return;
    }
    setSuccess("Refund request sent. The shop will review it, and you can follow its status below.");
    setSelectedShopId("");
    setReason("");
    setNotes("");
    setErrors({});
    setReloadKey((key) => key + 1);
  }

  const header = (
    <AccountPageHeader
      title="Refunds"
      description="Ask a shop for a refund on something you bought. Each shop reviews its own requests."
    />
  );

  if (loadError) {
    return (
      <div>
        {header}
        <ErrorNote message={loadError} onRetry={retryLoad} />
      </div>
    );
  }

  if (!data) {
    return (
      <div>
        {header}
        <LoadingNote />
      </div>
    );
  }

  return (
    <div>
      {header}

      <section className="mt-8">
        <h2 className="font-display text-xl font-semibold text-ink">Request a refund</h2>

        {orders.length === 0 ? (
          <div className="mt-4 rounded-xl border border-border bg-surface p-5">
            <p className="text-[15px] text-ink-soft">
              You don't have any orders to request a refund for yet.{" "}
              <Link to="/account/orders" className="font-medium text-primary hover:underline">
                View your orders
              </Link>
            </p>
          </div>
        ) : (
          <form
            onSubmit={handleSubmit}
            noValidate
            className="mt-4 flex flex-col gap-5 rounded-xl border border-border bg-surface p-5 sm:p-6"
          >
            {unknownPreselect && (
              <p role="status" className="rounded-lg bg-warning/15 px-3.5 py-2.5 text-sm text-amber-700">
                We couldn't find that order among the ones you can ask a refund for. Pick one below.
              </p>
            )}

            <Field label="Order" htmlFor="refund-order" error={errors.order}>
              <select
                id="refund-order"
                value={orderId}
                onChange={handleOrderChange}
                aria-invalid={Boolean(errors.order)}
                className={fieldClassName(Boolean(errors.order))}
              >
                <option value="">Choose an order…</option>
                {orders.map((order) => (
                  <option key={order.id} value={order.id}>
                    {describeOrder(order)}
                  </option>
                ))}
              </select>
            </Field>

            {orderId && (
              <fieldset className="min-w-0">
                <legend className="text-sm text-ink">What is the refund for?</legend>

                {(items.status === "loading" || items.status === "idle") && (
                  <p className="mt-2 text-sm text-ink-soft">Loading items…</p>
                )}

                {items.status === "error" && (
                  <p role="alert" className="mt-2 text-sm text-error">
                    {items.error}{" "}
                    <button type="button" onClick={items.retry} className="font-medium underline">
                      Try again
                    </button>
                  </p>
                )}

                {items.status === "ready" && groups.length === 0 && (
                  <p className="mt-2 text-sm text-ink-soft">
                    None of the items on this order can be refunded through a shop.
                  </p>
                )}

                {groups.length > 0 && (
                  <>
                    <p className="mt-1 text-xs text-ink-soft">
                      Refunds are handled by each shop separately. If your order has items from more than one shop,
                      send one request per shop.
                    </p>
                    <div className="mt-3 flex flex-col gap-2">
                      {groups.map((group) => {
                        const existing = refundsForOrder.get(group.shopId);
                        const checked = shopId === group.shopId;
                        return (
                          <label
                            key={group.shopId}
                            className={`flex items-start gap-3 rounded-lg border p-3.5 ${
                              existing
                                ? "cursor-not-allowed border-border bg-paper opacity-70"
                                : checked
                                  ? "cursor-pointer border-primary bg-primary/5"
                                  : "cursor-pointer border-border hover:border-primary/40"
                            }`}
                          >
                            <input
                              type="radio"
                              name="refund-shop"
                              value={group.shopId}
                              checked={checked}
                              disabled={Boolean(existing)}
                              onChange={() => setSelectedShopId(group.shopId)}
                              className="mt-1 accent-primary"
                            />
                            <span className="min-w-0 flex-1">
                              <span className="block text-[15px] font-medium text-ink">
                                {group.shopName || "Shop"}
                              </span>
                              <span className="mt-0.5 block break-words text-sm text-ink-soft">
                                {group.labels.join(", ")}
                              </span>
                              {existing && (
                                <span className="mt-1.5 flex flex-wrap items-center gap-2 text-sm text-ink-soft">
                                  Refund already requested
                                  <StatusBadge status={existing.status} />
                                </span>
                              )}
                            </span>
                            <span className="flex-none text-sm text-ink">{formatPrice(group.total)}</span>
                          </label>
                        );
                      })}
                    </div>
                    {openGroups.length === 0 && (
                      <p className="mt-3 text-sm text-ink-soft">
                        You've already requested a refund from every shop on this order.
                      </p>
                    )}
                    {errors.shop && <p className="mt-1.5 text-sm text-error">{errors.shop}</p>}
                  </>
                )}
              </fieldset>
            )}

            <Field label="Reason" htmlFor="refund-reason" error={errors.reason}>
              <select
                id="refund-reason"
                value={reason}
                onChange={(event) => setReason(event.target.value)}
                aria-invalid={Boolean(errors.reason)}
                className={fieldClassName(Boolean(errors.reason))}
              >
                <option value="">Choose a reason…</option>
                {REASONS.map((option) => (
                  <option key={option} value={option}>
                    {option}
                  </option>
                ))}
              </select>
            </Field>

            <Field
              label="Notes"
              htmlFor="refund-notes"
              error={errors.notes}
              optional={reason !== "Other"}
              hint="Anything the shop should know."
            >
              <textarea
                id="refund-notes"
                rows={3}
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                aria-invalid={Boolean(errors.notes)}
                className={fieldClassName(Boolean(errors.notes))}
              />
            </Field>

            {formError && (
              <p role="alert" className="text-sm text-error">
                {formError}
              </p>
            )}
            {success && (
              <p role="status" className="text-sm text-trust">
                {success}
              </p>
            )}

            <Button
              type="submit"
              variant="accent"
              disabled={submitting || (Boolean(orderId) && items.status === "ready" && openGroups.length === 0)}
              className="w-full sm:w-fit"
            >
              {submitting ? "Sending…" : "Send refund request"}
            </Button>
          </form>
        )}
      </section>

      <section className="mt-10">
        <h2 className="font-display text-xl font-semibold text-ink">Your refund requests</h2>
        {refunds.length > 0 ? (
          <div className="mt-4 flex flex-col gap-3">
            {refunds.map((refund) => (
              <RefundCard key={refund.id} refund={refund} />
            ))}
          </div>
        ) : (
          <p className="mt-4 text-[15px] text-ink-soft">You haven't requested any refunds yet.</p>
        )}
      </section>
    </div>
  );
}
