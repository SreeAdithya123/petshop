import { useEffect, useState } from "react";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { formatOrderDate, formatPrice } from "../lib/format";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";

const orderTypeLabels = {
  product_purchase: "Product purchase",
  pet_reservation: "Pet reservation",
  gift: "Gift",
};

const orderStatusLabels = {
  pending: "Pending",
  paid: "Paid",
  fulfilled: "Fulfilled",
  cancelled: "Cancelled",
};

const reservationStatusLabels = {
  pending: "Pending",
  confirmed: "Confirmed",
  expired: "Expired",
  cancelled: "Cancelled",
};

function ProfileSection({ profile }) {
  return (
    <section>
      <h2 className="font-display text-xl font-semibold text-ink">Profile</h2>
      <div className="mt-4 grid grid-cols-1 gap-3 text-[15px] sm:grid-cols-2">
        <div>
          <p className="text-sm text-ink-soft">Name</p>
          <p className="mt-0.5 text-ink">{profile.name}</p>
        </div>
        <div>
          <p className="text-sm text-ink-soft">Email</p>
          <p className="mt-0.5 text-ink">{profile.email}</p>
        </div>
        <div>
          <p className="text-sm text-ink-soft">Phone</p>
          <p className="mt-0.5 text-ink">{profile.phone}</p>
        </div>
        <div>
          <p className="text-sm text-ink-soft">Role</p>
          <p className="mt-0.5 capitalize text-ink">{profile.role?.replace("_", " ")}</p>
        </div>
      </div>
    </section>
  );
}

function OrdersSection({ userId }) {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    supabase
      .from("orders")
      .select("*")
      .eq("customer_id", userId)
      .order("created_at", { ascending: false })
      .then(({ data }) => {
        if (!cancelled) {
          setOrders(data ?? []);
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [userId]);

  return (
    <section>
      <h2 className="font-display text-xl font-semibold text-ink">Orders</h2>
      {loading ? (
        <p className="mt-4 text-ink-soft">Loading…</p>
      ) : orders.length > 0 ? (
        <div className="mt-4 flex flex-col gap-3">
          {orders.map((order) => (
            <div key={order.id} className="rounded-xl border border-border bg-surface p-4">
              <div className="flex items-center justify-between gap-3">
                <p className="text-[15px] font-medium text-ink">
                  {orderTypeLabels[order.order_type] ?? order.order_type}
                </p>
                <p className="font-display text-[15px] font-semibold text-accent">
                  {formatPrice(order.total_amount)}
                </p>
              </div>
              <div className="mt-1 flex items-center justify-between gap-3 text-sm text-ink-soft">
                <span>{orderStatusLabels[order.status] ?? order.status}</span>
                <span>{formatOrderDate(order.created_at)}</span>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="mt-4">
          <EmptyState
            title="No orders yet"
            action={
              <Button to="/pets" size="sm">
                Browse pets
              </Button>
            }
          />
        </div>
      )}
    </section>
  );
}

function ReservationsSection({ userId }) {
  const [reservations, setReservations] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    supabase
      .from("reservations")
      .select("*, pets(species, breed)")
      .eq("customer_id", userId)
      .order("created_at", { ascending: false })
      .then(({ data }) => {
        if (!cancelled) {
          setReservations(data ?? []);
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [userId]);

  return (
    <section>
      <h2 className="font-display text-xl font-semibold text-ink">Reservations</h2>
      {loading ? (
        <p className="mt-4 text-ink-soft">Loading…</p>
      ) : reservations.length > 0 ? (
        <div className="mt-4 flex flex-col gap-3">
          {reservations.map((reservation) => (
            <div key={reservation.id} className="rounded-xl border border-border bg-surface p-4">
              <div className="flex items-center justify-between gap-3">
                <p className="text-[15px] font-medium text-ink">
                  {reservation.pets
                    ? `${reservation.pets.species} · ${reservation.pets.breed}`
                    : "Pet"}
                </p>
                <p className="font-display text-[15px] font-semibold text-accent">
                  {formatPrice(reservation.deposit_amount)} deposit
                </p>
              </div>
              <div className="mt-1 flex items-center justify-between gap-3 text-sm text-ink-soft">
                <span>{reservationStatusLabels[reservation.status] ?? reservation.status}</span>
                {reservation.expires_at && <span>Expires {formatOrderDate(reservation.expires_at)}</span>}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="mt-4">
          <EmptyState title="No reservations yet" />
        </div>
      )}
    </section>
  );
}

function WishlistSection({ userId }) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  async function loadWishlist() {
    setLoading(true);
    const { data: rows } = await supabase.from("wishlists").select("*").eq("customer_id", userId);

    const wishlistRows = rows ?? [];
    const petIds = wishlistRows.filter((row) => row.item_type === "pet").map((row) => row.item_id);
    const productIds = wishlistRows
      .filter((row) => row.item_type === "product")
      .map((row) => row.item_id);

    const [petsResult, productsResult] = await Promise.all([
      petIds.length
        ? supabase.from("pets").select("id, species, breed").in("id", petIds)
        : Promise.resolve({ data: [] }),
      productIds.length
        ? supabase.from("products").select("id, name, price").in("id", productIds)
        : Promise.resolve({ data: [] }),
    ]);

    const petsById = new Map((petsResult.data ?? []).map((pet) => [pet.id, pet]));
    const productsById = new Map((productsResult.data ?? []).map((product) => [product.id, product]));

    const resolved = wishlistRows.map((row) => {
      if (row.item_type === "pet") {
        const pet = petsById.get(row.item_id);
        return { ...row, label: pet ? `${pet.species} · ${pet.breed}` : "Pet no longer listed" };
      }
      const product = productsById.get(row.item_id);
      return {
        ...row,
        label: product ? `${product.name} — ${formatPrice(product.price)}` : "Product no longer listed",
      };
    });

    setItems(resolved);
    setLoading(false);
  }

  useEffect(() => {
    loadWishlist();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  async function handleRemove(row) {
    await supabase
      .from("wishlists")
      .delete()
      .eq("customer_id", row.customer_id)
      .eq("item_type", row.item_type)
      .eq("item_id", row.item_id);
    await loadWishlist();
  }

  return (
    <section>
      <h2 className="font-display text-xl font-semibold text-ink">Wishlist</h2>
      {loading ? (
        <p className="mt-4 text-ink-soft">Loading…</p>
      ) : items.length > 0 ? (
        <div className="mt-4 flex flex-col gap-3">
          {items.map((item) => (
            <div
              key={`${item.item_type}-${item.item_id}`}
              className="flex items-center justify-between gap-3 rounded-xl border border-border bg-surface p-4"
            >
              <p className="text-[15px] text-ink">{item.label}</p>
              <Button variant="outline" size="sm" onClick={() => handleRemove(item)}>
                Remove
              </Button>
            </div>
          ))}
        </div>
      ) : (
        <div className="mt-4">
          <EmptyState title="No wishlist items yet" />
        </div>
      )}
    </section>
  );
}

export function Account() {
  const status = useAuthStore((state) => state.status);
  const session = useAuthStore((state) => state.session);
  const profile = useAuthStore((state) => state.profile);

  if (status === "loading") {
    return (
      <Container className="py-16">
        <p className="text-ink-soft">Loading…</p>
      </Container>
    );
  }

  if (!session || !profile) {
    return (
      <Container className="py-16">
        <EmptyState
          title="Log in to see your account"
          action={
            <Button to="/login" size="sm">
              Log in
            </Button>
          }
        />
      </Container>
    );
  }

  return (
    <Container className="py-10 lg:py-12">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Your account</h1>

      <div className="mt-8 flex flex-col gap-10">
        <ProfileSection profile={profile} />
        <OrdersSection userId={session.user.id} />
        <ReservationsSection userId={session.user.id} />
        <WishlistSection userId={session.user.id} />
      </div>
    </Container>
  );
}
