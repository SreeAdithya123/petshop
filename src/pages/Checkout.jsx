import { CheckCircle, Trash } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { LoginPrompt } from "../components/ui/LoginPrompt";
import { PetPhoto } from "../components/ui/PetPhoto";
import { formatPrice } from "../lib/format";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";
import { useCartStore } from "../store/cartStore";
import { useCatalog, useCatalogStore } from "../store/catalogStore";

/**
 * A pet's shop is fixed, never a buyer choice — "pickup shop confirmation
 * per item" means showing which shop each pet comes from. Only the shop's
 * name is shown; pickup details are confirmed by the shop after booking.
 */
function PetRow({ pet, shopName, onRemove }) {
  return (
    <li className="flex items-center gap-3 p-3">
      <div className="h-14 w-14 flex-none overflow-hidden rounded-lg">
        <PetPhoto src={pet.photos?.[0]} species={pet.species} alt="" className="h-full w-full" />
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium text-ink">{pet.name}</p>
        {shopName && <p className="truncate text-xs text-ink-soft">Pickup at {shopName}</p>}
      </div>
      <p className="flex-none text-sm font-semibold text-accent">{formatPrice(pet.price)}</p>
      {onRemove && (
        <button
          type="button"
          onClick={onRemove}
          aria-label={`Remove ${pet.name} from cart`}
          className="h-8 w-8 flex-none rounded-full text-ink-soft hover:bg-error/10 hover:text-error"
        >
          <Trash size={17} className="mx-auto" />
        </button>
      )}
    </li>
  );
}

/** Re-fetches the listings, then drops cart pets that are no longer available. Returns how many were removed. */
async function refreshCatalogAndPruneCart(pruneCart) {
  await useCatalogStore.getState().load({ force: true });
  const { status, pets } = useCatalogStore.getState();
  return status === "ready" ? pruneCart(pets.map((pet) => pet.id)) : 0;
}

function PageMessage({ children }) {
  return (
    <Container className="py-16">
      <p className="text-ink-soft">{children}</p>
    </Container>
  );
}

export function Checkout() {
  const authStatus = useAuthStore((state) => state.status);
  const session = useAuthStore((state) => state.session);
  const profile = useAuthStore((state) => state.profile);
  const itemIds = useCartStore((state) => state.items);
  const removeFromCart = useCartStore((state) => state.removeFromCart);
  const clearCart = useCartStore((state) => state.clearCart);
  const pruneCart = useCartStore((state) => state.pruneCart);
  const { getPetById, getShopById, loading, error } = useCatalog();

  const [refreshed, setRefreshed] = useState(false);
  const [removedCount, setRemovedCount] = useState(0);
  const [placing, setPlacing] = useState(false);
  const [placeError, setPlaceError] = useState("");
  const [placed, setPlaced] = useState(null); // { orderId, total, lines: [{ pet, shopName }] }

  // A cart can be days old: re-check availability against fresh listings before showing it, and
  // let sold, reserved or deleted pets drop out.
  useEffect(() => {
    let cancelled = false;
    refreshCatalogAndPruneCart(pruneCart).then((removed) => {
      if (cancelled) return;
      if (removed > 0) setRemovedCount((count) => count + removed);
      setRefreshed(true);
    });
    return () => {
      cancelled = true;
    };
  }, [pruneCart]);

  async function handleRetry() {
    const removed = await refreshCatalogAndPruneCart(pruneCart);
    if (removed > 0) setRemovedCount((count) => count + removed);
  }

  async function handlePlaceOrder(items) {
    if (placing || items.length === 0) return;
    setPlacing(true);
    setPlaceError("");
    const { data: orderId, error: rpcError } = await supabase.rpc("place_pet_order", {
      p_pet_ids: items.map((pet) => pet.id),
    });
    setPlacing(false);
    if (rpcError) {
      setPlaceError(rpcError.message || "We couldn't place your reservation. Please try again.");
      return;
    }
    setPlaced({
      orderId: String(orderId),
      total: items.reduce((sum, pet) => sum + pet.price, 0),
      lines: items.map((pet) => ({ pet, shopName: getShopById(pet.shopId)?.name })),
    });
    clearCart();
    // The reserved pets are no longer "available": refresh the listings behind us.
    useCatalogStore.getState().load({ force: true });
  }

  if (placed) {
    return (
      <Container className="py-16">
        <div className="mx-auto max-w-xl text-center">
          <CheckCircle size={48} weight="fill" className="mx-auto text-trust" />
          <h1 className="mt-5 font-display text-3xl font-bold text-ink">Reservation confirmed</h1>
          <p className="mt-3 text-[15px] text-ink-soft">
            Your pets are reserved. The shop will confirm pickup details with you; payment happens in person.
          </p>

          <div className="mt-8 rounded-xl border border-border bg-surface p-6 text-left">
            <div className="flex items-start justify-between gap-4 text-sm">
              <span className="text-ink-soft">Order</span>
              <span className="break-all text-right font-mono text-xs text-ink">{placed.orderId}</span>
            </div>
            <ul className="mt-4 divide-y divide-border rounded-xl border border-border">
              {placed.lines.map(({ pet, shopName }) => (
                <PetRow key={pet.id} pet={pet} shopName={shopName} />
              ))}
            </ul>
            <div className="mt-4 flex items-center justify-between border-t border-border pt-4 text-[15px]">
              <span className="text-ink-soft">Amount due at pickup</span>
              <span className="font-display font-semibold text-ink">{formatPrice(placed.total)}</span>
            </div>
          </div>

          <div className="mt-8 flex flex-wrap justify-center gap-3">
            <Button to="/account/orders">View my orders</Button>
            <Button to="/pets" variant="outline">
              Continue shopping
            </Button>
          </div>
        </div>
      </Container>
    );
  }

  if (authStatus === "loading") return <PageMessage>Loading…</PageMessage>;

  if (!session) {
    return (
      <Container className="py-16">
        <LoginPrompt
          title="Log in to reserve your pets"
          description="Sign in to confirm your reservation. Your cart will be waiting for you."
        />
      </Container>
    );
  }

  const emptyCart = (
    <Container className="py-20">
      <EmptyState
        title="Your cart is empty"
        description={
          removedCount > 0
            ? "The pets in your cart are no longer available, so they were removed."
            : "Add a pet to your cart before checking out."
        }
        action={
          <Button to="/pets" size="sm">
            Shop pets
          </Button>
        }
      />
    </Container>
  );

  if (itemIds.length === 0) return emptyCart;

  if (loading || !refreshed) {
    return (
      <Container className="py-10 lg:py-12">
        <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Checkout</h1>
        <div role="status" aria-label="Checking availability" className="mt-8 max-w-xl animate-pulse space-y-3">
          {itemIds.map((id) => (
            <div key={id} className="h-20 rounded-xl bg-border/50" />
          ))}
        </div>
      </Container>
    );
  }

  if (error) {
    return (
      <Container className="py-20">
        <EmptyState
          title="We couldn't check your pets"
          description={error}
          action={
            <Button size="sm" onClick={handleRetry}>
              Try again
            </Button>
          }
        />
      </Container>
    );
  }

  const items = itemIds.map((id) => getPetById(id)).filter(Boolean);
  if (items.length === 0) return emptyCart;

  const total = items.reduce((sum, pet) => sum + pet.price, 0);

  return (
    <Container className="py-10 lg:py-12">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Checkout</h1>
      <p className="mt-2 text-[15px] text-ink-soft">
        Reserve your pets now, then pick them up and pay in person at each shop. Nothing is charged online.
      </p>

      {removedCount > 0 && (
        <p role="status" className="mt-6 rounded-lg border border-border bg-surface px-4 py-3 text-sm text-ink-soft">
          {removedCount === 1
            ? "1 pet in your cart is no longer available and was removed."
            : `${removedCount} pets in your cart are no longer available and were removed.`}
        </p>
      )}

      <div className="mt-8 grid gap-10 lg:grid-cols-[1fr_360px] lg:gap-14">
        <div>
          <h2 className="font-display text-lg font-semibold text-ink">Pets to reserve</h2>
          <ul className="mt-4 divide-y divide-border rounded-xl border border-border bg-surface">
            {items.map((pet) => (
              <PetRow
                key={pet.id}
                pet={pet}
                shopName={getShopById(pet.shopId)?.name}
                onRemove={() => removeFromCart(pet.id)}
              />
            ))}
          </ul>
          <p className="mt-3 text-sm text-ink-soft">
            Each pet is collected from its own shop. The shop will confirm pickup details with you after you
            reserve.
          </p>

          <h2 className="mt-8 font-display text-lg font-semibold text-ink">Reserving as</h2>
          <p className="mt-1 text-sm text-ink-soft">
            {profile?.name ? `${profile.name} · ` : ""}
            {profile?.email ?? session.user.email}
          </p>
        </div>

        <div className="h-fit rounded-xl border border-border bg-surface p-5">
          <h2 className="font-display text-base font-semibold text-ink">Order summary</h2>
          <ul className="mt-3 divide-y divide-border">
            {items.map((pet) => (
              <li key={pet.id} className="flex items-center justify-between gap-3 py-2.5 text-sm">
                <span className="truncate text-ink">{pet.name}</span>
                <span className="flex-none font-medium text-ink">{formatPrice(pet.price)}</span>
              </li>
            ))}
          </ul>
          <div className="mt-3 flex items-center justify-between border-t border-border pt-3 text-[15px]">
            <span className="text-ink-soft">Total</span>
            <span className="font-display font-semibold text-ink">{formatPrice(total)}</span>
          </div>
          <p className="mt-2 text-xs text-ink-soft">Due at pickup — nothing is charged online.</p>

          {placeError && (
            <p role="alert" className="mt-4 text-sm text-error">
              {placeError}
            </p>
          )}
          <Button
            variant="accent"
            size="lg"
            onClick={() => handlePlaceOrder(items)}
            disabled={placing}
            className="mt-4 w-full"
          >
            {placing ? "Reserving…" : "Confirm reservation"}
          </Button>
        </div>
      </div>
    </Container>
  );
}
