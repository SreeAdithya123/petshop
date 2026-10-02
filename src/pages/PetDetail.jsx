import {
  CheckCircle,
  CreditCard,
  Gift,
  Heart,
  SealCheck,
  ShieldCheck,
  ShoppingCartSimple,
  VideoCamera,
} from "@phosphor-icons/react";
import { useState } from "react";
import { Link, useLocation, useNavigate, useParams } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { DemoRequestModal } from "../components/pets/DemoRequestModal";
import { EmiModal } from "../components/pets/EmiModal";
import { GiftPetModal } from "../components/pets/GiftPetModal";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { PetCard } from "../components/ui/PetCard";
import { PetPhoto } from "../components/ui/PetPhoto";
import { RatingStars } from "../components/ui/RatingStars";
import { formatPrice } from "../lib/format";
import { useCartStore } from "../store/cartStore";
import { useCatalog } from "../store/catalogStore";
import { useWishlist } from "../store/wishlistStore";

function factRows(pet) {
  const gender = pet.gender ? pet.gender.charAt(0).toUpperCase() + pet.gender.slice(1) : null;
  return [
    ["Species", pet.species],
    ["Breed", pet.breed],
    ["Gender", gender],
    ["Age", pet.ageLabel],
    ["Certification", pet.certification],
  ].filter(([, value]) => value);
}

function PetDetailSkeleton() {
  return (
    <Container className="py-10 lg:py-12">
      <div role="status" className="grid animate-pulse gap-10 lg:grid-cols-[minmax(0,1fr)_420px] lg:gap-14">
        <span className="sr-only">Loading pet…</span>
        <div className="aspect-square rounded-xl bg-primary/[0.06]" />
        <div className="space-y-4">
          <div className="h-4 w-32 rounded bg-primary/[0.06]" />
          <div className="h-9 w-3/4 rounded bg-primary/[0.06]" />
          <div className="h-7 w-28 rounded bg-primary/[0.06]" />
          <div className="h-40 rounded-lg bg-primary/[0.06]" />
          <div className="h-[52px] rounded-lg bg-primary/[0.06]" />
        </div>
      </div>
    </Container>
  );
}

function SecondaryAction({ icon: Icon, label, onClick, disabled }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className="flex flex-col items-center justify-center gap-1.5 rounded-lg border border-border bg-surface px-2 py-3 text-center text-xs font-medium text-ink transition-colors hover:bg-primary/5 disabled:pointer-events-none disabled:opacity-50 sm:text-sm"
    >
      <Icon size={22} className="text-primary" />
      {label}
    </button>
  );
}

export function PetDetail() {
  const { id } = useParams();
  // Keyed by id so gallery, modal and wishlist state reset when navigating between pets.
  return <PetDetailView key={id} id={id} />;
}

function PetDetailView({ id }) {
  const navigate = useNavigate();
  const location = useLocation();
  const { getPetById, getShopById, getPetsByShop, loading, error, reload } = useCatalog();
  const { signedIn, isWishlisted, toggle: toggleWishlist } = useWishlist();

  const pet = getPetById(id);
  const shop = pet ? getShopById(pet.shopId) : undefined;

  const [activeIndex, setActiveIndex] = useState(0);
  const [activeModal, setActiveModal] = useState(null); // "demo" | "gift" | "emi" | null
  const [giftPlaced, setGiftPlaced] = useState(false);
  const [wishlistBusy, setWishlistBusy] = useState(false);
  const [wishlistError, setWishlistError] = useState("");

  const inCart = useCartStore((state) => (pet ? state.items.includes(pet.id) : false));
  const addToCart = useCartStore((state) => state.addToCart);
  const openDrawer = useCartStore((state) => state.openDrawer);

  if (!pet) {
    if (giftPlaced) {
      return (
        <Container className="py-20">
          <EmptyState
            title="Gift reserved"
            description="The shop will arrange pickup with you and you pay in person. Follow it under My account → Orders."
            action={
              <div className="flex flex-wrap justify-center gap-2">
                <Button to="/account/orders" size="sm">
                  View my orders
                </Button>
                <Button to="/pets" variant="outline" size="sm">
                  Keep browsing
                </Button>
              </div>
            }
          />
        </Container>
      );
    }
    if (loading) return <PetDetailSkeleton />;
    if (error) {
      return (
        <Container className="py-20">
          <EmptyState
            title="We couldn't load this pet"
            description={error}
            action={
              <Button onClick={reload} size="sm">
                Try again
              </Button>
            }
          />
        </Container>
      );
    }
    return (
      <Container className="py-20">
        <EmptyState
          title="We couldn't find that pet"
          description="It may have already been reserved or sold, or the link is out of date."
          action={
            <Button to="/pets" size="sm">
              Shop pets
            </Button>
          }
        />
      </Container>
    );
  }

  const unavailable = pet.status !== "available";
  const photos = pet.photos ?? [];
  const wishlisted = isWishlisted(pet.id);
  const relatedPets = getPetsByShop(pet.shopId)
    .filter((candidate) => candidate.id !== pet.id)
    .slice(0, 4);

  function closeModal() {
    setActiveModal(null);
  }

  function closeGiftModal() {
    setActiveModal(null);
    // The gifted pet is reserved now, so refresh the catalog to drop it from sale.
    if (giftPlaced) reload();
  }

  function handleCartClick() {
    if (unavailable) return;
    if (inCart) openDrawer();
    else addToCart(pet.id);
  }

  async function handleWishlistClick() {
    if (!signedIn) {
      navigate("/login", { state: { from: location } });
      return;
    }
    if (wishlistBusy) return;
    setWishlistBusy(true);
    setWishlistError("");
    const saved = await toggleWishlist(pet.id);
    setWishlistBusy(false);
    if (!saved) setWishlistError("We couldn't update your wishlist. Please try again.");
  }

  return (
    <>
      <Container className="py-10 lg:py-12">
        <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_420px] lg:gap-x-14">
          <div className="lg:col-start-1 lg:row-start-1">
            <div className="relative aspect-square overflow-hidden rounded-xl bg-primary/[0.06]">
              <PetPhoto
                src={photos[activeIndex]}
                species={pet.species}
                alt={`${pet.name}, a ${pet.breed}`}
                className={`h-full w-full ${unavailable ? "opacity-50 grayscale-[0.4]" : ""}`}
              />
              {unavailable && (
                <span className="absolute left-3 top-3 rounded-md bg-ink px-2.5 py-1 text-xs font-medium capitalize text-white">
                  {pet.status}
                </span>
              )}
            </div>

            {photos.length > 1 && (
              <div className="mt-3 flex gap-3 overflow-x-auto">
                {photos.map((photo, index) => (
                  <button
                    key={`${index}-${photo}`}
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

          <div className="lg:col-start-2 lg:row-span-2 lg:row-start-1 lg:sticky lg:top-[92px] lg:self-start">
            <p className="text-sm text-ink-soft">
              {pet.species} · {pet.breed}
            </p>
            <h1 className="mt-1 font-display text-3xl font-bold text-ink">{pet.name}</h1>
            <p className="mt-3 font-display text-2xl font-semibold text-accent">{formatPrice(pet.price)}</p>

            <table className="mt-6 w-full border-t border-border text-sm">
              <tbody>
                {factRows(pet).map(([label, value]) => (
                  <tr key={label} className="border-b border-border">
                    <td className="py-2.5 text-ink-soft">{label}</td>
                    <td className="py-2.5 text-right font-medium text-ink">{value}</td>
                  </tr>
                ))}
              </tbody>
            </table>

            <div className="mt-6 flex gap-3">
              <Button
                onClick={handleCartClick}
                disabled={unavailable}
                variant={inCart ? "primary" : "accent"}
                size="lg"
                className="flex-1"
              >
                {unavailable ? (
                  <span className="capitalize">{pet.status}</span>
                ) : inCart ? (
                  <>
                    <CheckCircle size={18} weight="fill" /> In cart
                  </>
                ) : (
                  <>
                    <ShoppingCartSimple size={18} /> Add to cart
                  </>
                )}
              </Button>
              <button
                type="button"
                onClick={handleWishlistClick}
                disabled={wishlistBusy}
                aria-label={wishlisted ? "Remove from wishlist" : "Add to wishlist"}
                aria-pressed={wishlisted}
                className={`flex h-[52px] w-[52px] flex-none items-center justify-center rounded-lg border transition-colors disabled:opacity-50 ${
                  wishlisted ? "border-primary text-primary" : "border-border text-ink-soft hover:text-primary"
                }`}
              >
                <Heart size={20} weight={wishlisted ? "fill" : "regular"} />
              </button>
            </div>
            {wishlistError && (
              <p role="alert" className="mt-2 text-sm text-error">
                {wishlistError}
              </p>
            )}

            <div role="group" aria-label="More ways to decide" className="mt-4 rounded-xl border border-border bg-paper p-3">
              <p className="mb-2 text-xs font-medium text-ink-soft">Not ready to add it to your cart?</p>
              <div className="grid grid-cols-3 gap-2">
                <SecondaryAction
                  icon={VideoCamera}
                  label="Request demo"
                  disabled={unavailable}
                  onClick={() => setActiveModal("demo")}
                />
                <SecondaryAction
                  icon={Gift}
                  label="Send as gift"
                  disabled={unavailable}
                  onClick={() => setActiveModal("gift")}
                />
                <SecondaryAction icon={CreditCard} label="EMI options" onClick={() => setActiveModal("emi")} />
              </div>
            </div>
          </div>

          <div className="lg:col-start-1 lg:row-start-2">
            {pet.description && (
              <section>
                <h2 className="font-display text-2xl font-bold text-ink">About {pet.name}</h2>
                <p className="mt-3 whitespace-pre-line text-[15px] leading-relaxed text-ink-soft">
                  {pet.description}
                </p>
              </section>
            )}

            {shop && (
              <section
                aria-label="Seller"
                className={`rounded-xl border border-border bg-surface p-5 ${pet.description ? "mt-8" : ""}`}
              >
                <h2 className="font-display text-lg font-semibold text-ink">
                  <span className="block text-xs font-medium uppercase tracking-wide text-ink-soft">Sold by</span>
                  <Link to={`/sellers/${shop.id}`} className="hover:text-primary hover:underline">
                    {shop.name}
                  </Link>
                </h2>
                <RatingStars rating={shop.rating} reviewCount={shop.reviewCount} className="mt-1.5" />
                {shop.licenseNumber && (
                  <p className="mt-2 flex items-center gap-1.5 text-sm text-ink-soft">
                    <SealCheck size={16} weight="fill" className="flex-none text-trust" />
                    Licensed dealer · {shop.licenseNumber}
                  </p>
                )}
                <p className="mt-3 flex items-start gap-1.5 border-t border-border pt-3 text-sm text-ink-soft">
                  <ShieldCheck size={16} className="mt-0.5 flex-none" />
                  Pickup details are shared by the shop after you reserve — contact details stay private.
                </p>
              </section>
            )}
          </div>
        </div>

        {relatedPets.length > 0 && (
          <div className="mt-16">
            <h2 className="font-display text-2xl font-bold text-ink">More from {shop?.name ?? "this shop"}</h2>
            <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 lg:gap-5">
              {relatedPets.map((related) => (
                <PetCard key={related.id} pet={related} />
              ))}
            </div>
          </div>
        )}
      </Container>

      <DemoRequestModal open={activeModal === "demo"} onClose={closeModal} pet={pet} shop={shop} />
      <GiftPetModal
        open={activeModal === "gift"}
        onClose={closeGiftModal}
        onGifted={() => setGiftPlaced(true)}
        pet={pet}
        shop={shop}
      />
      <EmiModal open={activeModal === "emi"} onClose={closeModal} pet={pet} shop={shop} />
    </>
  );
}
