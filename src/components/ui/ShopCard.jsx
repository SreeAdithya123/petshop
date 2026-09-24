import { MapPin } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { getPetsByShop } from "../../data/pets";
import { RatingStars } from "./RatingStars";

export function ShopCard({ shop }) {
  const availableCount = getPetsByShop(shop.id).filter((pet) => pet.status !== "sold").length;

  return (
    <Link
      to={`/sellers/${shop.id}`}
      className="block rounded-xl border border-border bg-surface p-5 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]"
    >
      <h3 className="font-display text-lg font-semibold text-ink">{shop.name}</h3>
      <RatingStars rating={shop.rating} reviewCount={shop.reviewCount} className="mt-1.5" />
      <p className="mt-2.5 flex items-center gap-1.5 text-sm text-ink-soft">
        <MapPin size={15} className="flex-none" />
        {shop.city}
      </p>
      <p className="mt-3 text-sm text-ink-soft">
        {availableCount > 0
          ? `${availableCount} ${availableCount === 1 ? "pet" : "pets"} listed`
          : "No pets listed right now"}
      </p>
      <p className="mt-1 text-xs text-ink-soft">License #{shop.licenseNumber}</p>
    </Link>
  );
}
