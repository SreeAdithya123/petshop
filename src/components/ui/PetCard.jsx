import { Check, ShoppingCartSimple } from "@phosphor-icons/react";
import { useEffect } from "react";
import { Link } from "react-router-dom";
import { formatPrice } from "../../lib/format";
import { useCartStore } from "../../store/cartStore";
import { useCatalogStore } from "../../store/catalogStore";
import { PetPhoto } from "./PetPhoto";

/** Placeholder with the same footprint as a PetCard, shown while the catalog loads. */
export function PetCardSkeleton() {
  return (
    <div aria-hidden="true" className="animate-pulse overflow-hidden rounded-xl border border-border bg-surface">
      <div className="aspect-square bg-border/50" />
      <div className="space-y-2 p-3.5">
        <div className="h-4 w-2/3 rounded bg-border/50" />
        <div className="h-3.5 w-1/2 rounded bg-border/50" />
        <div className="h-5 w-1/3 rounded bg-border/50" />
        <div className="h-9 rounded-lg bg-border/50" />
      </div>
    </div>
  );
}

/**
 * The one product-card component used on every page that lists pets (home
 * strips, /pets grid, shop storefronts, related pets). Two sibling <Link>s
 * (photo, and name/price block) rather than one link wrapping everything,
 * so the shop-name link and the Add to Cart <button> never end up nested
 * inside another interactive element — invalid HTML and unreliable clicks.
 */
export function PetCard({ pet }) {
  // Only the shop name is shown (never contact details); it comes from the shared catalog.
  const shop = useCatalogStore((state) => state.shops.find((item) => item.id === pet.shopId));
  const inCart = useCartStore((state) => state.items.includes(pet.id));
  const addToCart = useCartStore((state) => state.addToCart);
  const openDrawer = useCartStore((state) => state.openDrawer);
  const unavailable = pet.status === "sold" || pet.status === "reserved";
  const unavailableLabel = pet.status === "reserved" ? "Reserved" : "Sold";

  // Cards can be rendered from pets fetched elsewhere; make sure shop names can resolve.
  useEffect(() => {
    const catalog = useCatalogStore.getState();
    if (catalog.status === "idle") catalog.load();
  }, []);

  function handleCartClick(event) {
    event.preventDefault();
    if (unavailable) return;
    if (inCart) openDrawer();
    else addToCart(pet.id);
  }

  return (
    <div className="group flex h-full flex-col overflow-hidden rounded-xl border border-border bg-surface transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]">
      <Link to={`/pets/${pet.id}`} className="relative block aspect-square overflow-hidden">
        <PetPhoto
          src={pet.photos?.[0]}
          species={pet.species}
          alt={`${pet.name}, a ${pet.breed || pet.species}`}
          className={`h-full w-full transition-transform duration-300 group-hover:scale-[1.04] ${
            unavailable ? "opacity-50 grayscale-[0.4]" : ""
          }`}
        />
        {unavailable && (
          <span className="absolute left-2.5 top-2.5 rounded-md bg-ink px-2.5 py-1 text-xs font-medium text-white">
            {unavailableLabel}
          </span>
        )}
      </Link>

      <div className="flex flex-1 flex-col p-3.5">
        <Link to={`/pets/${pet.id}`} className="block">
          <h3 className="truncate text-[15px] font-medium text-ink">{pet.name}</h3>
          <p className="mt-0.5 truncate text-sm text-ink-soft">{pet.breed || pet.species}</p>
          <p className="mt-0.5 min-h-4 truncate text-xs text-ink-soft">
            {pet.ageLabel}
            {pet.ageLabel && pet.gender ? " · " : ""}
            {pet.gender && <span className="capitalize">{pet.gender}</span>}
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

        <div className="mt-auto pt-3">
          <button
            type="button"
            onClick={handleCartClick}
            disabled={unavailable}
            className={`flex w-full items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
              unavailable
                ? "cursor-not-allowed bg-border/50 text-ink-soft"
                : inCart
                  ? "bg-trust/10 text-trust hover:bg-trust/15"
                  : "bg-accent text-white hover:opacity-90"
            }`}
          >
            {unavailable ? (
              unavailableLabel
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
    </div>
  );
}
