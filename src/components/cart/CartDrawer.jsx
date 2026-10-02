import { Trash, X } from "@phosphor-icons/react";
import { useEffect } from "react";
import { Link } from "react-router-dom";
import { formatPrice } from "../../lib/format";
import { useCartStore } from "../../store/cartStore";
import { useCatalog } from "../../store/catalogStore";
import { Button } from "../ui/Button";
import { EmptyState } from "../ui/EmptyState";
import { PetPhoto } from "../ui/PetPhoto";

function CartLineItem({ pet, shopName }) {
  const removeFromCart = useCartStore((state) => state.removeFromCart);

  return (
    <li className="flex gap-3 py-4">
      <Link to={`/pets/${pet.id}`} className="h-16 w-16 flex-none overflow-hidden rounded-lg">
        <PetPhoto
          src={pet.photos?.[0]}
          species={pet.species}
          alt={`${pet.name}, a ${pet.breed || pet.species}`}
          className="h-full w-full"
        />
      </Link>
      <div className="flex flex-1 flex-col justify-center">
        <Link to={`/pets/${pet.id}`} className="text-sm font-medium text-ink hover:underline">
          {pet.name}
        </Link>
        {shopName && <p className="text-xs text-ink-soft">Pickup at {shopName}</p>}
        <p className="mt-1 text-sm font-semibold text-accent">{formatPrice(pet.price)}</p>
      </div>
      <button
        type="button"
        onClick={() => removeFromCart(pet.id)}
        aria-label={`Remove ${pet.name} from cart`}
        className="h-8 w-8 flex-none self-start rounded-full text-ink-soft hover:bg-error/10 hover:text-error"
      >
        <Trash size={17} className="mx-auto" />
      </button>
    </li>
  );
}

function CartLineSkeleton() {
  return (
    <li aria-hidden="true" className="flex animate-pulse gap-3 py-4">
      <div className="h-16 w-16 flex-none rounded-lg bg-border/50" />
      <div className="flex-1 space-y-2 pt-1">
        <div className="h-4 w-2/3 rounded bg-border/50" />
        <div className="h-3 w-1/2 rounded bg-border/50" />
        <div className="h-4 w-1/4 rounded bg-border/50" />
      </div>
    </li>
  );
}

function EmptyCart({ onNavigate }) {
  return (
    <EmptyState
      title="Your cart is empty"
      description="Add a pet to your cart to hold it while you browse."
      action={
        <Button to="/pets" size="sm" onClick={onNavigate}>
          Browse pets
        </Button>
      }
    />
  );
}

/**
 * Cart lines are resolved from the live catalog (the cart only stores pet
 * ids), and any id the catalog no longer lists — sold, reserved, deleted — is
 * pruned once the catalog has loaded. Rendered only when the cart has items so
 * an empty cart never triggers a catalog fetch.
 */
function CartContents({ itemIds, onNavigate }) {
  const { getPetById, getShopById, pets, loading, error, reload } = useCatalog();
  const pruneCart = useCartStore((state) => state.pruneCart);

  useEffect(() => {
    if (loading || error) return;
    pruneCart(pets.map((pet) => pet.id));
  }, [loading, error, pets, pruneCart]);

  if (loading) {
    return (
      <div className="flex-1 overflow-y-auto px-5" role="status" aria-label="Loading your cart">
        <ul className="divide-y divide-border">
          {itemIds.map((id) => (
            <CartLineSkeleton key={id} />
          ))}
        </ul>
      </div>
    );
  }

  if (error) {
    return (
      <EmptyState
        title="We couldn't load your cart"
        description={error}
        action={
          <Button size="sm" onClick={reload}>
            Try again
          </Button>
        }
      />
    );
  }

  const items = itemIds.map((id) => getPetById(id)).filter(Boolean);
  if (items.length === 0) return <EmptyCart onNavigate={onNavigate} />;

  const subtotal = items.reduce((sum, pet) => sum + pet.price, 0);

  return (
    <>
      <ul className="flex-1 divide-y divide-border overflow-y-auto px-5">
        {items.map((pet) => (
          <CartLineItem key={pet.id} pet={pet} shopName={getShopById(pet.shopId)?.name} />
        ))}
      </ul>
      <div className="border-t border-border px-5 py-4">
        <div className="flex items-center justify-between text-[15px]">
          <span className="text-ink-soft">Subtotal</span>
          <span className="font-display font-semibold text-ink">{formatPrice(subtotal)}</span>
        </div>
        <p className="mt-1 text-xs text-ink-soft">
          Pickup and final payment happen at each shop — nothing ships.
        </p>
        <Button to="/checkout" variant="accent" size="lg" onClick={onNavigate} className="mt-4 w-full">
          Proceed to Checkout
        </Button>
      </div>
    </>
  );
}

/**
 * Right-side drawer on tablet/desktop, bottom sheet on mobile — one
 * component, two transform axes gated by the `md:` breakpoint (translateY
 * for the sheet, translateX for the drawer), both GPU-safe transform-only
 * transitions. See /docs/decisions.md.
 */
export function CartDrawer() {
  const isOpen = useCartStore((state) => state.isDrawerOpen);
  const closeDrawer = useCartStore((state) => state.closeDrawer);
  const itemIds = useCartStore((state) => state.items);

  return (
    <>
      {isOpen && (
        <button
          type="button"
          aria-label="Close cart"
          onClick={closeDrawer}
          className="fixed inset-0 z-40 bg-ink/40"
        />
      )}

      <aside
        aria-hidden={!isOpen}
        className={`fixed inset-x-0 bottom-0 z-50 flex max-h-[85vh] flex-col rounded-t-2xl bg-surface shadow-2xl transition-transform duration-300 ease-out md:inset-y-0 md:bottom-auto md:left-auto md:right-0 md:h-full md:max-h-none md:w-full md:max-w-md md:rounded-l-2xl md:rounded-t-none ${
          isOpen ? "translate-y-0 md:translate-x-0" : "translate-y-full md:translate-y-0 md:translate-x-full"
        }`}
      >
        <div className="flex items-center justify-between border-b border-border px-5 py-4">
          <h2 className="font-display text-lg font-semibold text-ink">
            Your cart{itemIds.length > 0 ? ` (${itemIds.length})` : ""}
          </h2>
          <button
            type="button"
            onClick={closeDrawer}
            aria-label="Close cart"
            className="flex h-9 w-9 items-center justify-center rounded-full text-ink-soft hover:bg-primary/5"
          >
            <X size={20} />
          </button>
        </div>

        {itemIds.length === 0 ? (
          <EmptyCart onNavigate={closeDrawer} />
        ) : (
          <CartContents itemIds={itemIds} onNavigate={closeDrawer} />
        )}
      </aside>
    </>
  );
}
