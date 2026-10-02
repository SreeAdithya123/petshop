import { PawPrint } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { useCatalogStore } from "../../store/catalogStore";
import { RatingStars } from "./RatingStars";

/** Placeholder with the same footprint as a ShopCard, shown while the catalog loads. */
export function ShopCardSkeleton() {
  return (
    <div aria-hidden="true" className="animate-pulse rounded-xl border border-border bg-surface p-5">
      <div className="h-5 w-1/2 rounded bg-border/50" />
      <div className="mt-3 h-4 w-1/3 rounded bg-border/50" />
      <div className="mt-4 h-4 w-full rounded bg-border/50" />
      <div className="mt-2 h-4 w-3/4 rounded bg-border/50" />
    </div>
  );
}

export function ShopCard({ shop }) {
  const petCount = useCatalogStore((state) => state.pets.filter((pet) => pet.shopId === shop.id).length);

  return (
    <Link
      to={`/sellers/${shop.id}`}
      className="block rounded-xl border border-border bg-surface p-5 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]"
    >
      <h3 className="font-display text-lg font-semibold text-ink">{shop.name}</h3>
      {shop.reviewCount > 0 ? (
        <RatingStars rating={shop.rating} reviewCount={shop.reviewCount} className="mt-1.5" />
      ) : (
        <p className="mt-1.5 text-sm text-ink-soft">No reviews yet</p>
      )}
      {shop.description && <p className="mt-3 line-clamp-2 text-sm text-ink-soft">{shop.description}</p>}
      <p className="mt-3 flex items-center gap-1.5 text-sm text-ink-soft">
        <PawPrint size={15} className="flex-none" />
        {petCount > 0 ? `${petCount} ${petCount === 1 ? "pet" : "pets"} listed` : "No pets listed right now"}
      </p>
      {shop.licenseNumber && <p className="mt-1 text-xs text-ink-soft">License #{shop.licenseNumber}</p>}
    </Link>
  );
}
