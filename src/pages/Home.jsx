import {
  ArrowRight,
  Envelope,
  HandHeart,
  Headset,
  Heartbeat,
  MapPin,
  PawPrint,
  Scissors,
  SealCheck,
  Stethoscope,
  Storefront,
  TrendUp,
} from "@phosphor-icons/react";
import { useEffect, useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { SpeciesIcon } from "../components/icons/SpeciesIcon";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { PetCard, PetCardSkeleton } from "../components/ui/PetCard";
import { PRODUCT_PUBLIC_COLUMNS } from "../lib/columns";
import { formatPrice } from "../lib/format";
import { sortPets } from "../lib/petFilters";
import { supabase } from "../lib/supabaseClient";
import { useCatalog } from "../store/catalogStore";

// Species are free text on the seller side, so look styles up case-insensitively.
const categoryStyle = {
  dog: { emoji: "🐶", color: "text-primary" },
  cat: { emoji: "🐱", color: "text-accent" },
  bird: { emoji: "🐦", color: "text-secondary" },
  rabbit: { emoji: "🐰", color: "text-trust" },
  fish: { emoji: "🐟", color: "text-primary" },
  hamster: { emoji: "🐹", color: "text-warning" },
  "guinea pig": { emoji: "🐹", color: "text-warning" },
  "small pet": { emoji: "🐹", color: "text-warning" },
  turtle: { emoji: "🐢", color: "text-trust" },
  reptile: { emoji: "🦎", color: "text-trust" },
};

const exploreLinks = [
  { to: "/services", icon: Scissors, title: "Services", desc: "Vets, grooming, training and more" },
  { to: "/health", icon: Heartbeat, title: "Health", desc: "Check-ups and everyday pet care" },
  { to: "/store", icon: Storefront, title: "Store", desc: "Medicine and supplies from local shops" },
];

const whyPetsta = [
  { icon: Stethoscope, title: "Health info included", desc: "Species, breed, and age up front" },
  { icon: MapPin, title: "Pickup nearby", desc: "Nothing ships — meet at the shop" },
  { icon: Headset, title: "Get help anytime", desc: "Raise a ticket, we'll follow up" },
  { icon: SealCheck, title: "Licensed shops only", desc: "Every seller is a verified dealer" },
];

function StatCounter({ target, label }) {
  const [value, setValue] = useState(0);
  const ref = useRef(null);

  // Counts up once the card scrolls into view; re-runs if the real total arrives later.
  useEffect(() => {
    const node = ref.current;
    if (!node || target === 0) return undefined;
    let frame = 0;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        observer.disconnect();
        const duration = 900;
        const start = performance.now();
        function tick(now) {
          const progress = Math.min((now - start) / duration, 1);
          setValue(Math.round(target * (1 - (1 - progress) ** 3)));
          if (progress < 1) frame = requestAnimationFrame(tick);
        }
        frame = requestAnimationFrame(tick);
      },
      { threshold: 0.4 },
    );
    observer.observe(node);
    return () => {
      observer.disconnect();
      cancelAnimationFrame(frame);
    };
  }, [target]);

  return (
    <div ref={ref} className="rounded-2xl border border-border bg-surface p-6 text-center shadow-sm">
      <div className="bg-gradient-to-br from-primary via-secondary to-tertiary bg-clip-text font-display text-4xl font-black text-transparent">
        {value.toLocaleString()}
      </div>
      <p className="mt-1.5 text-sm font-semibold text-ink-soft">{label}</p>
    </div>
  );
}

function GiftFeaturedCard({ product }) {
  return (
    <Link
      to={`/store/${product.id}`}
      className="w-[200px] flex-none rounded-2xl border border-border bg-surface p-4 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(15,23,42,0.2)]"
    >
      <p className="text-xs capitalize text-ink-soft">{product.category}</p>
      <h3 className="mt-1 truncate text-[15px] font-semibold text-ink">{product.name}</h3>
      <p className="mt-1 truncate text-xs text-ink-soft">{product.shops?.name}</p>
      <p className="mt-2 font-display text-base font-bold text-accent">{formatPrice(product.price)}</p>
    </Link>
  );
}

export function Home() {
  const { pets, shops, speciesList, breedList, getPetsByShop, loading, error, reload } = useCatalog();
  const [featuredProducts, setFeaturedProducts] = useState([]);
  const [newsletterEmail, setNewsletterEmail] = useState("");
  const [newsletterState, setNewsletterState] = useState("idle"); // idle | sending | done | error

  useEffect(() => {
    let cancelled = false;
    supabase
      .from("products")
      .select(`${PRODUCT_PUBLIC_COLUMNS}, shops(name)`)
      .eq("status", "available")
      .order("created_at", { ascending: false })
      .limit(8)
      .then(({ data }) => {
        // A supplementary strip: if the query fails it simply stays hidden.
        if (!cancelled) setFeaturedProducts(data ?? []);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const { trending, topPicks, featuredBreeds, featuredShops, shopsAreRated } = useMemo(() => {
    const ratedShops = shops.filter((shop) => shop.reviewCount > 0).sort((a, b) => b.rating - a.rating);
    return {
      trending: sortPets(pets, "newest").slice(0, 4),
      topPicks: sortPets(pets, "price-desc").slice(0, 4),
      featuredBreeds: breedList.slice(0, 8).map((breed) => ({
        breed,
        pet: pets.find((pet) => pet.breed === breed),
      })),
      shopsAreRated: ratedShops.length > 0,
      featuredShops: (ratedShops.length > 0 ? ratedShops : shops).slice(0, 3),
    };
  }, [pets, shops, breedList]);

  const showCatalog = !loading && !error && pets.length > 0;

  async function handleNewsletterSubmit(event) {
    event.preventDefault();
    const email = newsletterEmail.trim();
    if (!email) return;
    setNewsletterState("sending");
    const { error: insertError } = await supabase.from("newsletter_subscribers").insert({ email });
    if (insertError && !insertError.message?.toLowerCase().includes("duplicate")) {
      setNewsletterState("error");
      return;
    }
    setNewsletterState("done");
    setNewsletterEmail("");
  }

  return (
    <>
      {/* Hero */}
      <section className="pt-6 md:pt-10">
        <Container>
          <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary via-secondary to-tertiary p-8 text-white md:p-12">
            <div className="relative z-10">
              <div className="max-w-2xl">
                <div className="inline-flex items-center gap-2 rounded-full border border-white/20 bg-white/15 px-4 py-1.5 text-sm font-semibold backdrop-blur-sm">
                  <PawPrint size={16} weight="fill" />{" "}
                  {showCatalog
                    ? `${pets.length} ${pets.length === 1 ? "pet" : "pets"} across ${shops.length} local ${
                        shops.length === 1 ? "shop" : "shops"
                      }`
                    : "Pets from licensed local shops"}
                </div>
                <h1 className="mt-4 font-display text-4xl font-black leading-tight md:text-6xl">
                  The <span className="underline decoration-pink-400 underline-offset-8">smartest</span>{" "}
                  way<br className="hidden md:block" /> to find your best friend
                </h1>
                <p className="mt-4 max-w-xl text-lg opacity-90 md:text-xl">
                  From trusted local shops to your doorstep visit — browse, reserve, and pick up in person.
                  Nothing ships.
                </p>
                <div className="mt-7 flex flex-wrap gap-3">
                  <Button
                    to="/pets"
                    size="lg"
                    className="!bg-white !text-primary font-black shadow-lg hover:scale-[1.03]"
                  >
                    <PawPrint size={18} weight="fill" /> Explore pets
                  </Button>
                  <Button
                    to="/sellers"
                    size="lg"
                    className="!bg-tertiary !text-white font-black shadow-lg hover:scale-[1.03]"
                  >
                    Browse shops
                  </Button>
                </div>
              </div>
            </div>
            <div className="relative z-10 mt-8 flex flex-wrap justify-center gap-3 md:justify-start">
              <span className="rounded-full bg-white/15 px-3.5 py-1.5 text-xs font-semibold backdrop-blur-sm">
                ✅ Every shop is a licensed dealer
              </span>
              <span className="rounded-full bg-white/15 px-3.5 py-1.5 text-xs font-semibold backdrop-blur-sm">
                🏬 Pickup in person — nothing ships
              </span>
              <span className="rounded-full bg-white/15 px-3.5 py-1.5 text-xs font-semibold backdrop-blur-sm">
                🎧 Support when you need it
              </span>
            </div>
          </div>
        </Container>
      </section>

      {/* Why PETSTA */}
      <section className="mt-12 md:mt-16">
        <Container>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            {whyPetsta.map(({ icon: Icon, title, desc }) => (
              <div
                key={title}
                className="rounded-2xl border border-border bg-surface p-5 text-center shadow-sm"
              >
                <Icon size={30} weight="duotone" className="mx-auto text-primary" />
                <h4 className="mt-2 font-display text-sm font-bold text-ink">{title}</h4>
                <p className="mt-0.5 text-xs text-ink-soft">{desc}</p>
              </div>
            ))}
          </div>
        </Container>
      </section>

      {/* More than pets */}
      <section className="mt-12 md:mt-16">
        <Container>
          <div className="grid gap-4 sm:grid-cols-3">
            {exploreLinks.map(({ to, icon: Icon, title, desc }) => (
              <Link
                key={to}
                to={to}
                className="flex items-center gap-4 rounded-2xl border border-border bg-surface p-4 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(15,23,42,0.2)]"
              >
                <span className="flex h-11 w-11 flex-none items-center justify-center rounded-xl bg-primary/10 text-primary">
                  <Icon size={24} weight="duotone" />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block font-display text-base font-bold text-ink">{title}</span>
                  <span className="block truncate text-sm text-ink-soft">{desc}</span>
                </span>
                <ArrowRight size={16} weight="bold" className="flex-none text-ink-soft" />
              </Link>
            ))}
          </div>
        </Container>
      </section>

      {/* Catalog status: skeleton while loading, retry on error, friendly empty state */}
      {loading && (
        <section className="mt-12 md:mt-16">
          <Container>
            <div className="grid grid-cols-2 gap-4 md:grid-cols-4" role="status" aria-label="Loading pets">
              {Array.from({ length: 4 }).map((_, index) => (
                <PetCardSkeleton key={index} />
              ))}
            </div>
          </Container>
        </section>
      )}
      {!loading && error && (
        <section className="mt-12 md:mt-16">
          <Container>
            <EmptyState
              title="We couldn't load pets right now"
              description={error}
              action={
                <Button size="sm" onClick={reload}>
                  Try again
                </Button>
              }
            />
          </Container>
        </section>
      )}
      {!loading && !error && pets.length === 0 && (
        <section className="mt-12 md:mt-16">
          <Container>
            <EmptyState
              title="No pets listed right now"
              description="Shops haven't listed any pets yet. Check back soon."
              action={
                <Button to="/sellers" size="sm">
                  Browse shops
                </Button>
              }
            />
          </Container>
        </section>
      )}

      {/* Stats */}
      {showCatalog && (
        <section className="mt-12 md:mt-16">
          <Container>
            <div className="grid grid-cols-3 gap-4">
              <StatCounter target={pets.length} label="Pets listed" />
              <StatCounter target={shops.length} label="Local shops" />
              <StatCounter target={speciesList.length} label="Species available" />
            </div>
          </Container>
        </section>
      )}

      {/* Featured products */}
      {featuredProducts.length > 0 && (
        <section className="mt-12 md:mt-16">
          <Container>
            <div className="mb-4 flex items-center justify-between">
              <h2 className="font-display text-2xl font-black text-ink">🔥 Featured products</h2>
              <Link to="/store" className="text-sm font-bold text-primary hover:underline">
                View all
              </Link>
            </div>
          </Container>
          <div className="scrollbar-none flex gap-4 overflow-x-auto px-4 sm:px-6 lg:mx-auto lg:max-w-7xl lg:px-8">
            {featuredProducts.map((product) => (
              <GiftFeaturedCard key={product.id} product={product} />
            ))}
          </div>
        </section>
      )}

      {showCatalog && (
        <>
          {/* Popular breeds */}
          <section className="mt-12 md:mt-16">
            <Container>
              <div className="mb-4 flex items-center justify-between">
                <h2 className="font-display text-2xl font-black text-ink">🐾 Popular breeds</h2>
                <Link to="/pets" className="text-sm font-bold text-primary hover:underline">
                  Explore all
                </Link>
              </div>
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                {featuredBreeds.map(({ breed, pet }) => (
                  <Link
                    key={breed}
                    to={`/pets?breed=${encodeURIComponent(breed)}`}
                    className="group overflow-hidden rounded-2xl border border-border bg-surface transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(15,23,42,0.2)]"
                  >
                    <div className="aspect-square overflow-hidden bg-primary/[0.06]">
                      {pet?.photos?.[0] ? (
                        <img
                          src={pet.photos[0]}
                          alt={breed}
                          className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-[1.05]"
                        />
                      ) : (
                        <SpeciesIcon species={pet?.species} className="h-full w-full" />
                      )}
                    </div>
                    <p className="truncate px-3 py-2.5 text-sm font-semibold text-ink">{breed}</p>
                  </Link>
                ))}
              </div>
            </Container>
          </section>

          {/* Trending & top picks */}
          <section className="mt-12 md:mt-16">
            <Container>
              <div className="grid grid-cols-1 gap-8 md:grid-cols-2">
                <div>
                  <h2 className="mb-4 flex items-center gap-2 font-display text-2xl font-black text-ink">
                    <TrendUp size={24} weight="bold" className="text-trust" /> Trending now
                  </h2>
                  <div className="grid grid-cols-2 gap-4">
                    {trending.map((pet) => (
                      <PetCard key={pet.id} pet={pet} />
                    ))}
                  </div>
                </div>
                <div>
                  <h2 className="mb-4 flex items-center gap-2 font-display text-2xl font-black text-ink">
                    <HandHeart size={24} weight="bold" className="text-accent" /> Top picks
                  </h2>
                  <div className="grid grid-cols-2 gap-4">
                    {topPicks.map((pet) => (
                      <PetCard key={pet.id} pet={pet} />
                    ))}
                  </div>
                </div>
              </div>
            </Container>
          </section>

          {/* Top-rated shops (or just the shops, until reviews come in) */}
          {featuredShops.length > 0 && (
            <section className="mt-12 md:mt-16">
              <Container>
                <h2 className="font-display text-2xl font-black text-ink">
                  {shopsAreRated ? "⭐ Top-rated shops" : "🏬 Local shops"}
                </h2>
                <div className="mt-6 grid gap-5 sm:grid-cols-3">
                  {featuredShops.map((shop) => {
                    const petCount = getPetsByShop(shop.id).length;
                    return (
                      <Link
                        key={shop.id}
                        to={`/sellers/${shop.id}`}
                        className="rounded-2xl border border-border bg-surface p-5 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(15,23,42,0.2)]"
                      >
                        <h3 className="font-display text-base font-bold text-ink">{shop.name}</h3>
                        <p className="mt-1 text-sm text-ink-soft">
                          {shop.reviewCount > 0 ? `⭐ ${shop.rating.toFixed(1)} (${shop.reviewCount})` : "No reviews yet"}
                        </p>
                        <p className="mt-2 flex items-center gap-1.5 text-sm text-ink-soft">
                          <PawPrint size={15} />
                          {petCount} {petCount === 1 ? "pet" : "pets"} listed
                        </p>
                      </Link>
                    );
                  })}
                </div>
              </Container>
            </section>
          )}

          {/* Category grid */}
          <section className="mt-12 md:mt-16">
            <Container>
              <div className="grid grid-cols-3 gap-4 sm:grid-cols-5">
                {speciesList.map((species) => {
                  const style = categoryStyle[species.toLowerCase()] ?? { emoji: "🐾", color: "text-primary" };
                  return (
                    <Link
                      key={species}
                      to={`/pets?species=${encodeURIComponent(species)}`}
                      className="flex flex-col items-center gap-2 rounded-2xl border border-border bg-surface p-4 text-center transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(15,23,42,0.2)]"
                    >
                      <span className={`text-4xl ${style.color}`}>{style.emoji}</span>
                      <p className="font-display text-sm font-bold text-ink">{species}</p>
                    </Link>
                  );
                })}
              </div>
            </Container>
          </section>
        </>
      )}

      {/* Newsletter */}
      <section className="mt-12 pb-20 md:mt-16">
        <Container>
          <div className="rounded-2xl bg-primary p-8 text-center text-white md:p-12">
            <h2 className="font-display text-3xl font-black">📬 Join the PETSTA community</h2>
            <p className="mt-2 opacity-90">Pet care tips and new listings near you, delivered occasionally.</p>
            {newsletterState === "done" ? (
              <p className="mt-6 flex items-center justify-center gap-2 font-semibold">
                <SealCheck size={20} weight="fill" /> You're subscribed — welcome to PETSTA.
              </p>
            ) : (
              <form onSubmit={handleNewsletterSubmit} className="mx-auto mt-6 flex max-w-lg flex-col gap-3 sm:flex-row">
                <div className="relative flex-1">
                  <Envelope
                    size={18}
                    className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-soft"
                  />
                  <input
                    type="email"
                    required
                    value={newsletterEmail}
                    onChange={(event) => setNewsletterEmail(event.target.value)}
                    placeholder="Your email address"
                    className="w-full rounded-xl py-3 pl-11 pr-4 text-ink outline-none"
                  />
                </div>
                <button
                  type="submit"
                  disabled={newsletterState === "sending"}
                  className="flex items-center justify-center gap-1.5 rounded-xl bg-white px-6 py-3 font-black text-primary transition-opacity hover:opacity-90 disabled:opacity-60"
                >
                  {newsletterState === "sending" ? "Subscribing…" : "Subscribe"} <ArrowRight size={16} weight="bold" />
                </button>
              </form>
            )}
            {newsletterState === "error" && (
              <p className="mt-3 text-sm text-rose-100">Couldn't subscribe right now — try again in a moment.</p>
            )}
          </div>
        </Container>
      </section>
    </>
  );
}
