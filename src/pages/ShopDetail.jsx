import { useState } from "react";
import { useParams } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { PetCard, PetCardSkeleton } from "../components/ui/PetCard";
import { RatingStars } from "../components/ui/RatingStars";
import { useCatalog } from "../store/catalogStore";

const GRID_CLASS = "mt-5 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 lg:gap-5";

/** Banner photo with the shop name on top; falls back to a plain colour block if there's no photo or it fails to load. */
function ShopBanner({ shop }) {
  const [failed, setFailed] = useState(false);
  const showImage = shop.bannerUrl && !failed;

  return (
    <div className="relative flex h-40 items-end overflow-hidden rounded-xl bg-primary p-6 md:h-52 md:p-8">
      {showImage && (
        <>
          <img
            src={shop.bannerUrl}
            alt=""
            onError={() => setFailed(true)}
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-ink/70 to-transparent" />
        </>
      )}
      <h1 className="relative font-display text-2xl font-bold text-paper md:text-3xl">{shop.name}</h1>
    </div>
  );
}

export function ShopDetail() {
  const { id } = useParams();
  const { getShopById, getPetsByShop, loading, error, reload } = useCatalog();
  const shop = getShopById(id);

  if (loading) {
    return (
      <Container className="py-8">
        <div role="status" aria-label="Loading shop" className="animate-pulse">
          <div className="h-40 rounded-xl bg-border/50 md:h-52" />
          <div className="mt-8 h-4 w-40 rounded bg-border/50" />
          <div className="mt-3 h-4 w-2/3 rounded bg-border/50" />
          <div className={GRID_CLASS}>
            {Array.from({ length: 4 }).map((_, index) => (
              <PetCardSkeleton key={index} />
            ))}
          </div>
        </div>
      </Container>
    );
  }

  if (error) {
    return (
      <Container className="py-20">
        <EmptyState
          title="We couldn't load this shop"
          description={error}
          action={
            <Button size="sm" onClick={reload}>
              Try again
            </Button>
          }
        />
      </Container>
    );
  }

  if (!shop) {
    return (
      <Container className="py-20">
        <EmptyState
          title="We couldn't find that shop"
          description="It may have closed, or the link is out of date."
          action={
            <Button to="/sellers" size="sm">
              Browse shops
            </Button>
          }
        />
      </Container>
    );
  }

  const shopPets = getPetsByShop(shop.id);

  return (
    <>
      <Container className="pt-8">
        <ShopBanner key={shop.id} shop={shop} />
      </Container>

      <Container className="py-8">
        {shop.reviewCount > 0 ? (
          <RatingStars rating={shop.rating} reviewCount={shop.reviewCount} />
        ) : (
          <p className="text-sm text-ink-soft">No reviews yet</p>
        )}
        {shop.licenseNumber && <p className="mt-1.5 text-sm text-ink-soft">License #{shop.licenseNumber}</p>}
        {shop.description && <p className="mt-4 max-w-2xl text-[15px] text-ink-soft">{shop.description}</p>}
        <p className="mt-4 text-sm text-ink-soft">
          Reserve a pet and the shop will confirm pickup details with you.
        </p>

        <h2 className="mt-10 font-display text-xl font-semibold text-ink">Pets at {shop.name}</h2>

        {shopPets.length > 0 ? (
          <div className={GRID_CLASS}>
            {shopPets.map((pet) => (
              <PetCard key={pet.id} pet={pet} />
            ))}
          </div>
        ) : (
          <div className="mt-5">
            <EmptyState
              title="No pets listed right now"
              description="Check back soon, or browse other shops."
              action={
                <Button to="/sellers" size="sm">
                  Browse shops
                </Button>
              }
            />
          </div>
        )}
      </Container>
    </>
  );
}
