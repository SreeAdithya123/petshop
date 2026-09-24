import { MapPin, Phone } from "@phosphor-icons/react";
import { useParams } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { PetCard } from "../components/ui/PetCard";
import { RatingStars } from "../components/ui/RatingStars";
import { getShopById } from "../data/shops";
import { getPetsByShop } from "../data/pets";

export function ShopDetail() {
  const { id } = useParams();
  const shop = getShopById(id);

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
        <div className="flex h-40 items-end rounded-xl bg-primary p-6 md:h-52 md:p-8">
          <h1 className="font-display text-2xl font-bold text-paper md:text-3xl">{shop.name}</h1>
        </div>
      </Container>

      <Container className="py-8">
        <RatingStars rating={shop.rating} reviewCount={shop.reviewCount} />
        <p className="mt-3 flex items-center gap-1.5 text-sm text-ink-soft">
          <MapPin size={16} className="flex-none" />
          {shop.address}
        </p>
        <p className="mt-1.5 flex items-center gap-1.5 text-sm text-ink-soft">
          <Phone size={16} className="flex-none" />
          {shop.phone}
        </p>
        <p className="mt-1.5 text-sm text-ink-soft">License #{shop.licenseNumber}</p>

        <h2 className="mt-10 font-display text-xl font-semibold text-ink">Pets at {shop.name}</h2>

        {shopPets.length > 0 ? (
          <div className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 lg:gap-5">
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
