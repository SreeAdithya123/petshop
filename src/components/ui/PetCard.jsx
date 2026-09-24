import { Check, ShoppingCartSimple } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { getShopById } from "../../data/shops";
import { formatPrice } from "../../lib/format";
import { useCartStore } from "../../store/cartStore";
import { PetPhoto } from "./PetPhoto";

/**
 * The one product-card component used on every page that lists pets (home
 * strips, /pets grid, shop storefronts, related pets). Two sibling <Link>s
 * (photo, and name/price block) rather than one link wrapping everything,
 * so the shop-name link and the Add to Cart <button> never end up nested
 * inside another interactive element — invalid HTML and unreliable clicks.
 */
export function PetCard({ pet }) {
  const shop = getShopById(pet.shopId);
  const inCart = useCartStore((state) => state.items.includes(pet.id));
  const addToCart = useCartStore((state) => state.addToCart);
  const openDrawer = useCartStore((state) => state.openDrawer);
  const isSold = pet.status === "sold";

  function handleCartClick(event) {
    event.preventDefault();
    if (isSold) return;
    if (inCart) openDrawer();
    else addToCart(pet.id);
  }

  return (
    <div className="group flex h-full flex-col overflow-hidden rounded-xl border border-border bg-surface transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]">
      <Link to={`/pets/${pet.id}`} className="relative block aspect-square overflow-hidden">
        <PetPhoto
          src={pet.photos?.[0]}
          species={pet.species}
          alt={`${pet.name}, a ${pet.breed}`}
          className={`h-full w-full transition-transform duration-300 group-hover:scale-[1.04] ${
            isSold ? "opacity-50 grayscale-[0.4]" : ""
          }`}
        />
        {isSold && (
          <span className="absolute left-2.5 top-2.5 rounded-md bg-ink px-2.5 py-1 text-xs font-medium text-white">
            Sold
          </span>
        )}
      </Link>

      <div className="flex flex-1 flex-col p-3.5">
        <Link to={`/pets/${pet.id}`} className="block">
          <h3 className="truncate text-[15px] font-medium text-ink">{pet.name}</h3>
          <p className="mt-0.5 truncate text-sm text-ink-soft">
            {pet.breed} · {pet.ageLabel}
          </p>
          <p className="mt-2 font-display text-lg font-semibold text-accent">{formatPrice(pet.price)}</p>
        </Link>

        {shop && (
          <Link
            to={`/sellers/${shop.id}`}
            className="mt-1 truncate text-xs text-ink-soft hover:text-primary hover:underline"
          >
            {shop.name}
          </Link>
        )}

        <button
          type="button"
          onClick={handleCartClick}
          disabled={isSold}
          className={`mt-3 flex w-full items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
            isSold
              ? "cursor-not-allowed bg-border/50 text-ink-soft"
              : inCart
                ? "bg-trust/10 text-trust hover:bg-trust/15"
                : "bg-accent text-white hover:opacity-90"
          }`}
        >
          {isSold ? (
            "Sold"
          ) : inCart ? (
            <>
              <Check size={16} weight="bold" /> In Cart
            </>
          ) : (
            <>
              <ShoppingCartSimple size={16} /> Add to Cart
            </>
          )}
        </button>
      </div>
    </div>
  );
}
