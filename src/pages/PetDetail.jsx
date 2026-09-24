import { CheckCircle, Heart, Minus, Plus, MapPin, Phone, ShoppingCartSimple } from "@phosphor-icons/react";
import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { PetCard } from "../components/ui/PetCard";
import { PetPhoto } from "../components/ui/PetPhoto";
import { RatingStars } from "../components/ui/RatingStars";
import { getPetById, getPetsByShop } from "../data/pets";
import { getShopById } from "../data/shops";
import { formatPrice } from "../lib/format";
import { useCartStore } from "../store/cartStore";

const specRows = (pet) => [
  ["Species", pet.species],
  ["Breed", pet.breed],
  ["Age", pet.ageLabel],
  ["Gender", pet.gender],
];

export function PetDetail() {
  const { id } = useParams();
  const pet = getPetById(id);
  const [activeIndex, setActiveIndex] = useState(0);

  const inCart = useCartStore((state) => (pet ? state.items.includes(pet.id) : false));
  const addToCart = useCartStore((state) => state.addToCart);
  const openDrawer = useCartStore((state) => state.openDrawer);
  const inWishlist = useCartStore((state) => (pet ? state.wishlist.includes(pet.id) : false));
  const toggleWishlist = useCartStore((state) => state.toggleWishlist);

  if (!pet) {
    return (
      <Container className="py-20">
        <EmptyState
          title="We couldn't find that pet"
          description="It may have already sold, or the link is out of date."
          action={
            <Button to="/pets" size="sm">
              Shop pets
            </Button>
          }
        />
      </Container>
    );
  }

  const shop = getShopById(pet.shopId);
  const isSold = pet.status === "sold";
  const photos = pet.photos ?? [];
  const relatedPets = getPetsByShop(pet.shopId)
    .filter((candidate) => candidate.id !== pet.id)
    .slice(0, 4);

  function handleCartClick() {
    if (isSold) return;
    if (inCart) openDrawer();
    else addToCart(pet.id);
  }

  return (
    <Container className="py-10 lg:py-12">
      <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_420px] lg:gap-14">
        <div>
          <div className="relative aspect-square overflow-hidden rounded-xl bg-primary/[0.06]">
            <PetPhoto
              src={photos[activeIndex]}
              species={pet.species}
              alt={`${pet.name}, a ${pet.breed}`}
              className={`h-full w-full ${isSold ? "opacity-50 grayscale-[0.4]" : ""}`}
            />
            {isSold && (
              <span className="absolute left-3 top-3 rounded-md bg-ink px-2.5 py-1 text-xs font-medium text-white">
                Sold
              </span>
            )}
          </div>

          {photos.length > 1 && (
            <div className="mt-3 flex gap-3">
              {photos.map((photo, index) => (
                <button
                  key={photo}
                  type="button"
                  onClick={() => setActiveIndex(index)}
                  aria-label={`Show photo ${index + 1} of ${photos.length}`}
                  aria-current={index === activeIndex}
                  className={`h-16 w-16 flex-none overflow-hidden rounded-lg border-2 transition-colors ${
                    index === activeIndex ? "border-primary" : "border-transparent"
                  }`}
                >
                  <PetPhoto src={photo} species={pet.species} alt="" className="h-full w-full" />
                </button>
              ))}
            </div>
          )}
        </div>

        <div>
          <p className="text-sm text-ink-soft">
            {pet.species} · {pet.breed}
          </p>
          <h1 className="mt-1 font-display text-3xl font-bold text-ink">{pet.name}</h1>
          <p className="mt-3 font-display text-2xl font-semibold text-accent">{formatPrice(pet.price)}</p>

          <table className="mt-6 w-full border-t border-border text-sm">
            <tbody>
              {specRows(pet).map(([label, value]) => (
                <tr key={label} className="border-b border-border">
                  <td className="py-2.5 text-ink-soft">{label}</td>
                  <td className="py-2.5 text-right font-medium text-ink">{value}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="mt-6 flex items-center gap-3">
            <div className="flex items-center gap-1 rounded-lg border border-border px-1 py-1 opacity-50">
              <button
                type="button"
                disabled
                aria-label="Decrease quantity"
                className="flex h-8 w-8 items-center justify-center text-ink-soft"
              >
                <Minus size={15} />
              </button>
              <span className="w-5 text-center text-sm text-ink">1</span>
              <button
                type="button"
                disabled
                aria-label="Increase quantity"
                className="flex h-8 w-8 items-center justify-center text-ink-soft"
              >
                <Plus size={15} />
              </button>
            </div>
            <span className="text-xs text-ink-soft">Quantity is always 1 — each pet is a unique animal.</span>
          </div>

          <div className="mt-4 flex gap-3">
            <Button
              onClick={handleCartClick}
              disabled={isSold}
              variant={isSold ? "outline" : inCart ? "primary" : "accent"}
              size="lg"
              className="flex-1"
            >
              {isSold ? (
                "Sold"
              ) : inCart ? (
                <>
                  <CheckCircle size={18} weight="fill" /> In Cart
                </>
              ) : (
                <>
                  <ShoppingCartSimple size={18} /> Add to Cart
                </>
              )}
            </Button>
            <button
              type="button"
              onClick={() => toggleWishlist(pet.id)}
              aria-label={inWishlist ? "Remove from wishlist" : "Add to wishlist"}
              aria-pressed={inWishlist}
              className={`flex h-[52px] w-[52px] flex-none items-center justify-center rounded-lg border transition-colors ${
                inWishlist ? "border-primary text-primary" : "border-border text-ink-soft hover:text-primary"
              }`}
            >
              <Heart size={20} weight={inWishlist ? "fill" : "regular"} />
            </button>
          </div>

          {shop && (
            <Link
              to={`/sellers/${shop.id}`}
              className="mt-8 block rounded-xl border border-border bg-surface p-5 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]"
            >
              <h2 className="font-display text-base font-semibold text-ink">{shop.name}</h2>
              <RatingStars rating={shop.rating} reviewCount={shop.reviewCount} className="mt-1.5" />
              <p className="mt-2 flex items-center gap-1.5 text-sm text-ink-soft">
                <MapPin size={15} className="flex-none" />
                {shop.address}
              </p>
              <p className="mt-1 flex items-center gap-1.5 text-sm text-ink-soft">
                <Phone size={15} className="flex-none" />
                {shop.phone}
              </p>
              <p className="mt-1 text-sm text-ink-soft">License #{shop.licenseNumber}</p>
            </Link>
          )}
        </div>
      </div>

      {relatedPets.length > 0 && (
        <div className="mt-16">
          <h2 className="font-display text-2xl font-semibold text-ink">More from {shop?.name}</h2>
          <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 lg:gap-5">
            {relatedPets.map((related) => (
              <PetCard key={related.id} pet={related} />
            ))}
          </div>
        </div>
      )}
    </Container>
  );
}
