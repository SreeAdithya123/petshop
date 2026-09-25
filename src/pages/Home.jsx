import { Link } from "react-router-dom";
import { SpeciesIcon } from "../components/icons/SpeciesIcon";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { PetCard } from "../components/ui/PetCard";
import { ShopCard } from "../components/ui/ShopCard";
import { pets, speciesList } from "../data/pets";
import { shops } from "../data/shops";

const categoryLabels = {
  Dog: "Dogs",
  Cat: "Cats",
  Bird: "Birds",
  Rabbit: "Rabbits",
  "Small Pet": "Small Pets",
};

const justListed = [...pets]
  .filter((pet) => pet.status !== "sold")
  .sort((a, b) => new Date(b.listedDate) - new Date(a.listedDate))
  .slice(0, 8);

const topShops = [...shops]
  .filter((shop) => shop.reviewCount > 0)
  .sort((a, b) => b.rating - a.rating)
  .slice(0, 3);

export function Home() {
  return (
    <>
      <section className="pt-10 md:pt-14 lg:pt-16">
        <Container>
          <div className="grid items-center gap-10 lg:grid-cols-2 lg:gap-14">
            <div>
              <h1 className="max-w-[15ch] font-display text-4xl font-bold leading-[1.08] text-ink md:text-5xl">
                Pets from local shops, all in one place.
              </h1>
              <p className="mt-4 max-w-[46ch] text-base text-ink-soft md:text-lg">
                Browse pets across every licensed shop near you, add to cart, and pick up in person.
                Nothing ships.
              </p>
              <div className="mt-7 flex flex-wrap gap-3">
                <Button to="/pets" variant="accent" size="lg">
                  Shop pets
                </Button>
                <Button to="/sellers" variant="outline" size="lg">
                  Browse shops
                </Button>
              </div>
            </div>
            <div className="relative aspect-[6/5] w-full overflow-hidden rounded-xl bg-primary/[0.06]">
              <img
                src="https://images.dog.ceo/breeds/retriever-golden/n02099601_1010.jpg"
                alt="A golden retriever standing outdoors"
                className="h-full w-full object-cover"
                loading="eager"
              />
            </div>
          </div>
        </Container>
      </section>

      <section className="mt-14 md:mt-20">
        <Container>
          <div className="scrollbar-none flex gap-3 overflow-x-auto sm:grid sm:grid-cols-5 sm:gap-4">
            {speciesList.map((species) => (
              <Link
                key={species}
                to={`/pets?species=${encodeURIComponent(species)}`}
                className="flex w-24 flex-none flex-col items-center gap-2 rounded-xl border border-border bg-surface p-3 text-center transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_12px_24px_-14px_rgba(20,24,31,0.25)] sm:w-auto"
              >
                <SpeciesIcon species={species} className="h-12 w-12 rounded-full" />
                <span className="text-sm font-medium text-ink">{categoryLabels[species]}</span>
              </Link>
            ))}
          </div>
        </Container>
      </section>

      <section className="mt-14 md:mt-20">
        <Container>
          <div className="flex items-end justify-between gap-4">
            <h2 className="font-display text-2xl font-semibold text-ink md:text-3xl">Just listed</h2>
            <Link to="/pets" className="text-sm font-medium text-primary hover:opacity-80">
              View all pets
            </Link>
          </div>
        </Container>
        <div className="scrollbar-none mt-6 flex snap-x snap-mandatory gap-4 overflow-x-auto px-4 sm:px-6 lg:mx-auto lg:max-w-7xl lg:px-8">
          {justListed.map((pet) => (
            <div key={pet.id} className="w-[220px] flex-none snap-start sm:w-[240px]">
              <PetCard pet={pet} />
            </div>
          ))}
        </div>
      </section>

      <section className="mt-14 pb-20 md:mt-20">
        <Container>
          <h2 className="font-display text-2xl font-semibold text-ink md:text-3xl">Top-rated shops</h2>
          <div className="mt-6 grid gap-5 sm:grid-cols-3">
            {topShops.map((shop) => (
              <ShopCard key={shop.id} shop={shop} />
            ))}
          </div>
        </Container>
      </section>
    </>
  );
}
