import { ArrowCounterClockwise, Gift } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { AccountPageHeader, ErrorNote, LoadingNote } from "../../components/account/AccountPage";
import {
  isRefundable,
  orderTypeLabel,
  shortOrderId,
  useOrderItems,
} from "../../components/account/accountHelpers";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { formatDate, formatOrderDate, formatPrice } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { useAuthStore } from "../../store/authStore";
import { useCatalog } from "../../store/catalogStore";

const PAGE_SIZE = 10;

function OrderItems({ state }) {
  if (state.status === "idle" || state.status === "loading") {
    return <p className="mt-4 text-sm text-ink-soft">Loading items…</p>;
  }
  if (state.status === "error") {
    return (
      <p role="alert" className="mt-4 text-sm text-error">
        {state.error}{" "}
        <button type="button" onClick={state.retry} className="font-medium underline">
          Try again
        </button>
      </p>
    );
  }
  if (state.items.length === 0) {
    return <p className="mt-4 text-sm text-ink-soft">No item details are available for this order.</p>;
  }

  return (
    <ul className="mt-4 divide-y divide-border rounded-lg border border-border">
      {state.items.map((item) => {
        const detail = [item.quantity > 1 ? `Qty ${item.quantity}` : null, item.shopName ? `Sold by ${item.shopName}` : null]
          .filter(Boolean)
          .join(" · ");
        return (
          <li key={item.id} className="flex items-start justify-between gap-3 px-3.5 py-3">
            <div className="min-w-0">
              <p className="text-[15px] text-ink">{item.label}</p>
              {detail && <p className="mt-0.5 text-sm text-ink-soft">{detail}</p>}
            </div>
            <p className="flex-none text-[15px] text-ink">{formatPrice(item.price * item.quantity)}</p>
          </li>
        );
      })}
    </ul>
  );
}

function GiftNote({ gift }) {
  return (
    <div className="mt-4 rounded-lg bg-primary/5 px-3.5 py-3 text-sm">
      <p className="flex items-start gap-2 text-ink">
        <Gift size={16} className="mt-0.5 flex-none text-primary" aria-hidden="true" />
        <span className="min-w-0 break-words">
          Gift for {gift.recipient_name}
          {gift.recipient_contact && <span className="text-ink-soft"> ({gift.recipient_contact})</span>}
        </span>
      </p>
      {gift.message && <p className="mt-1 break-words text-ink-soft">“{gift.message}”</p>}
      {gift.delivery_status && (
        <p className="mt-1 text-ink-soft">
          Delivery: <span className="capitalize">{gift.delivery_status}</span>
        </p>
      )}
    </div>
  );
}

function OrderCard({ order, gift }) {
  const items = useOrderItems(order.id);
  // Nothing to refund when none of the items belongs to a shop.
  const canRefund =
    isRefundable(order) && (items.status !== "ready" || items.items.some((item) => item.shopId));
  const discount = Number(order.discount_amount) || 0;

  return (
    <article className="rounded-xl border border-border bg-surface p-4 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-2">
        <div className="min-w-0">
          <h3 className="text-[15px] font-medium text-ink">{orderTypeLabel(order.order_type)}</h3>
          <p className="mt-0.5 text-sm text-ink-soft">
            {formatOrderDate(order.created_at)} · Order #{shortOrderId(order.id)}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <StatusBadge status={order.status} />
          <p className="font-display text-lg font-semibold text-accent">{formatPrice(order.total_amount)}</p>
        </div>
      </div>

      {gift && <GiftNote gift={gift} />}

      <OrderItems state={items} />

      {(discount > 0 || order.eta_date || order.tracking_number) && (
        <div className="mt-3 flex flex-col gap-1 text-sm text-ink-soft">
          {discount > 0 && <p>Discount applied: {formatPrice(discount)}</p>}
          {order.eta_date && <p>Expected by {formatDate(order.eta_date)}</p>}
          {order.tracking_number && <p>Tracking number: {order.tracking_number}</p>}
        </div>
      )}

      {canRefund && (
        <div className="mt-4 flex justify-end">
          <Button to={`/account/refunds?order=${order.id}`} variant="outline" size="sm">
            <ArrowCounterClockwise size={16} />
            Request refund
          </Button>
        </div>
      )}
    </article>
  );
}

function ReservationCard({ reservation, pet, catalogLoading }) {
  // Reserved pets drop out of the public catalog, so fall back to the label
  // recorded on the order itself.
  const items = useOrderItems(reservation.order_id, !pet && !catalogLoading);
  const orderLabel = items.items.find((item) => item.itemId === reservation.pet_id)?.label;
  const finalAmount = Number(reservation.final_sale_amount) || 0;
  const holdOpen = reservation.expires_at && ["pending", "confirmed"].includes(reservation.status);

  return (
    <article className="rounded-xl border border-border bg-surface p-4 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-2">
        <div className="min-w-0">
          <h3 className="text-[15px] font-medium text-ink">
            {pet ? (
              <Link to={`/pets/${pet.id}`} className="hover:text-primary hover:underline">
                {pet.name} · {pet.breed}
              </Link>
            ) : (
              (orderLabel ?? "Pet")
            )}
          </h3>
          <p className="mt-0.5 text-sm text-ink-soft">Reserved {formatOrderDate(reservation.created_at)}</p>
        </div>
        <div className="flex items-center gap-3">
          <StatusBadge status={reservation.status} />
          <p className="font-display text-lg font-semibold text-accent">
            {formatPrice(reservation.deposit_amount)}
            <span className="ml-1 text-sm font-normal text-ink-soft">deposit</span>
          </p>
        </div>
      </div>

      <div className="mt-3 flex flex-col gap-1 text-sm text-ink-soft">
        {finalAmount > 0 && <p>Final price: {formatPrice(finalAmount)}</p>}
        {holdOpen && <p>Reservation held until {formatOrderDate(reservation.expires_at)}</p>}
        {reservation.order_id && <p>Order #{shortOrderId(reservation.order_id)}</p>}
      </div>
    </article>
  );
}

export function AccountOrders() {
  const userId = useAuthStore((state) => state.session?.user?.id);
  const { getPetById, loading: catalogLoading } = useCatalog();

  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);

  useEffect(() => {
    if (!userId) return undefined;
    let cancelled = false;

    async function load() {
      const [ordersResult, reservationsResult, giftsResult] = await Promise.all([
        supabase
          .from("orders")
          .select("id, order_type, status, total_amount, discount_amount, eta_date, tracking_number, created_at")
          .eq("customer_id", userId)
          .order("created_at", { ascending: false }),
        supabase
          .from("reservations")
          .select("id, pet_id, order_id, status, deposit_amount, final_sale_amount, expires_at, created_at")
          .eq("customer_id", userId)
          .order("created_at", { ascending: false }),
        supabase
          .from("gifts")
          .select("order_id, recipient_name, recipient_contact, message, delivery_status")
          .eq("sender_id", userId),
      ]);
      if (cancelled) return;

      const failure = ordersResult.error || reservationsResult.error || giftsResult.error;
      if (failure) {
        setError(failure.message);
        return;
      }
      setData({
        orders: ordersResult.data ?? [],
        reservations: reservationsResult.data ?? [],
        giftsByOrder: new Map((giftsResult.data ?? []).map((gift) => [gift.order_id, gift])),
      });
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [userId, reloadKey]);

  function retry() {
    setError("");
    setData(null);
    setReloadKey((key) => key + 1);
  }

  const header = (
    <AccountPageHeader
      title="My orders"
      description="Your purchases, gifts and pet reservations. The shop confirms pickup details with you after you order."
    />
  );

  if (error) {
    return (
      <div>
        {header}
        <ErrorNote message={error} onRetry={retry} />
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

  const { orders, reservations, giftsByOrder } = data;

  if (orders.length === 0 && reservations.length === 0) {
    return (
      <div>
        {header}
        <EmptyState
          title="No orders yet"
          description="When you reserve a pet or buy something, it will show up here."
          action={
            <Button to="/pets" size="sm">
              Browse pets
            </Button>
          }
        />
      </div>
    );
  }

  return (
    <div>
      {header}

      <section className="mt-8">
        <h2 className="font-display text-xl font-semibold text-ink">Orders</h2>
        {orders.length > 0 ? (
          <div className="mt-4 flex flex-col gap-3">
            {orders.slice(0, visibleCount).map((order) => (
              <OrderCard key={order.id} order={order} gift={giftsByOrder.get(order.id)} />
            ))}
            {orders.length > visibleCount && (
              <Button
                variant="outline"
                size="sm"
                className="self-center"
                onClick={() => setVisibleCount((count) => count + PAGE_SIZE)}
              >
                Show older orders
              </Button>
            )}
          </div>
        ) : (
          <p className="mt-4 text-[15px] text-ink-soft">No orders yet.</p>
        )}
      </section>

      <section className="mt-10">
        <h2 className="font-display text-xl font-semibold text-ink">Pet reservations</h2>
        {reservations.length > 0 ? (
          <div className="mt-4 flex flex-col gap-3">
            {reservations.map((reservation) => (
              <ReservationCard
                key={reservation.id}
                reservation={reservation}
                pet={getPetById(reservation.pet_id)}
                catalogLoading={catalogLoading}
              />
            ))}
          </div>
        ) : (
          <p className="mt-4 text-[15px] text-ink-soft">No pet reservations yet.</p>
        )}
      </section>
    </div>
  );
}
