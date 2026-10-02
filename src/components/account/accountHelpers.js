import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";

function titleCase(value) {
  const text = String(value ?? "").replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

export const ORDER_TYPE_LABELS = {
  pet_reservation: "Pet reservation",
  gift: "Gift",
  product_purchase: "Product purchase",
  service_booking: "Service booking",
  event_ticket: "Event ticket",
  insurance_purchase: "Insurance purchase",
  wallet_topup: "Wallet top-up",
};

export function orderTypeLabel(type) {
  return ORDER_TYPE_LABELS[type] ?? titleCase(type);
}

/** Orders in these states can still have a refund requested against them. */
export const REFUNDABLE_ORDER_STATUSES = ["pending", "paid", "fulfilled"];

export function isRefundable(order) {
  return REFUNDABLE_ORDER_STATUSES.includes(order.status);
}

/** Orders are uuids; the first block is enough to recognise one at a glance. */
export function shortOrderId(id) {
  return String(id).slice(0, 8).toUpperCase();
}

/** "14:30" / "14:30:00" -> "2:30 pm". Free-text values (e.g. "Morning") pass through. */
export function formatTimeOfDay(value) {
  if (!value) return "";
  const text = String(value).trim();
  const match = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(text);
  if (!match) return text;
  const hours = Number(match[1]);
  return `${hours % 12 || 12}:${match[2]} ${hours >= 12 ? "pm" : "am"}`;
}

/** Returns the URL only if it is a plain http(s) link, so stored text can never become a script link. */
export function safeExternalUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:" ? url.href : null;
  } catch {
    return null;
  }
}

function mapOrderItem(row) {
  return {
    id: row.order_item_id,
    type: row.item_type,
    itemId: row.item_id,
    quantity: row.quantity ?? 1,
    price: Number(row.price_at_purchase) || 0,
    label: row.label || "Item",
    shopId: row.shop_id ?? null,
    shopName: row.shop_name ?? "",
  };
}

// Items on a placed order never change, so share one request per order across
// the pages that need them (orders, refunds). Failures are dropped so a retry refetches.
const orderItemsRequests = new Map();

/**
 * Line items of one of the signed-in customer's own orders, with labels and
 * shop names resolved server-side (never any shop contact details).
 */
export function fetchOrderItems(orderId) {
  let request = orderItemsRequests.get(orderId);
  if (!request) {
    request = supabase.rpc("order_items_detailed", { p_order_id: orderId }).then(({ data, error }) => {
      if (error) throw error;
      return (data ?? []).map(mapOrderItem);
    });
    orderItemsRequests.set(orderId, request);
    request.catch(() => orderItemsRequests.delete(orderId));
  }
  return request;
}

/** One entry per shop on the order (refunds are requested per shop). Items with no shop are skipped. */
export function groupItemsByShop(items) {
  const groups = new Map();
  for (const item of items) {
    if (!item.shopId) continue;
    const group = groups.get(item.shopId) ?? {
      shopId: item.shopId,
      shopName: item.shopName,
      labels: [],
      total: 0,
    };
    group.labels.push(item.label);
    group.total += item.price * item.quantity;
    groups.set(item.shopId, group);
  }
  return [...groups.values()];
}

/**
 * Loads an order's items. `status` is "idle" (no order / disabled), "loading",
 * "ready" or "error"; `retry()` refetches after an error.
 */
export function useOrderItems(orderId, enabled = true) {
  const [result, setResult] = useState({ key: "", items: [], error: "" });
  const [attempt, setAttempt] = useState(0);

  const active = Boolean(orderId) && enabled;
  const key = `${orderId}:${attempt}`;

  useEffect(() => {
    if (!active) return undefined;
    let cancelled = false;
    fetchOrderItems(orderId).then(
      (items) => {
        if (!cancelled) setResult({ key, items, error: "" });
      },
      (error) => {
        if (!cancelled) setResult({ key, items: [], error: error.message || "Couldn't load the items." });
      },
    );
    return () => {
      cancelled = true;
    };
  }, [active, orderId, key]);

  const retry = () => setAttempt((count) => count + 1);

  if (!active) return { status: "idle", items: [], error: "", retry };
  if (result.key !== key) return { status: "loading", items: [], error: "", retry };
  if (result.error) return { status: "error", items: [], error: result.error, retry };
  return { status: "ready", items: result.items, error: "", retry };
}
