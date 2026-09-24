import { Trash, X } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { getPetById } from "../../data/pets";
import { getShopById } from "../../data/shops";
import { formatPrice } from "../../lib/format";
import { useCartStore } from "../../store/cartStore";
import { Button } from "../ui/Button";
import { EmptyState } from "../ui/EmptyState";
import { PetPhoto } from "../ui/PetPhoto";

function CartLineItem({ pet }) {
  const removeFromCart = useCartStore((state) => state.removeFromCart);
  const shop = getShopById(pet.shopId);

  return (
    <li className="flex gap-3 py-4">
      <Link to={`/pets/${pet.id}`} className="h-16 w-16 flex-none overflow-hidden rounded-lg">
        <PetPhoto
          src={pet.photos?.[0]}
          species={pet.species}
          alt={`${pet.name}, a ${pet.breed}`}
          className="h-full w-full"
        />
      </Link>
      <div className="flex flex-1 flex-col justify-center">
        <Link to={`/pets/${pet.id}`} className="text-sm font-medium text-ink hover:underline">
          {pet.name}
        </Link>
        {shop && <p className="text-xs text-ink-soft">Pickup at {shop.name}</p>}
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

  const items = itemIds.map((id) => getPetById(id)).filter(Boolean);
  const subtotal = items.reduce((sum, pet) => sum + pet.price, 0);

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
            Your cart{items.length > 0 ? ` (${items.length})` : ""}
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

        {items.length === 0 ? (
          <EmptyState
            title="Your cart is empty"
            description="Add a pet to your cart to hold it while you browse."
            action={
              <Button to="/pets" size="sm" onClick={closeDrawer}>
                Browse pets
              </Button>
            }
          />
        ) : (
          <>
            <ul className="flex-1 divide-y divide-border overflow-y-auto px-5">
              {items.map((pet) => (
                <CartLineItem key={pet.id} pet={pet} />
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
              <Button
                to="/checkout"
                variant="accent"
                size="lg"
                onClick={closeDrawer}
                className="mt-4 w-full"
              >
                Proceed to Checkout
              </Button>
            </div>
          </>
        )}
      </aside>
    </>
  );
}
