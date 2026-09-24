import { Funnel } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { FilterSidebar } from "../components/ui/FilterSidebar";
import { PetCard } from "../components/ui/PetCard";
import { SortSelect } from "../components/ui/SortSelect";
import { pets } from "../data/pets";
import { applyPetFilters, sortPets } from "../lib/petFilters";

function readArrayParam(searchParams, key) {
  const raw = searchParams.get(key);
  return raw ? raw.split(",").filter(Boolean) : [];
}

export function PetsList() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [filtersOpen, setFiltersOpen] = useState(false);

  const species = readArrayParam(searchParams, "species");
  const shopIds = readArrayParam(searchParams, "shop");
  const breeds = readArrayParam(searchParams, "breed");
  const minPrice = searchParams.get("minPrice") ?? "";
  const maxPrice = searchParams.get("maxPrice") ?? "";
  const sort = searchParams.get("sort") || "newest";

  const hasActiveFilters =
    species.length > 0 || shopIds.length > 0 || breeds.length > 0 || minPrice !== "" || maxPrice !== "";

  function updateParams(mutate) {
    const next = new URLSearchParams(searchParams);
    mutate(next);
    setSearchParams(next, { replace: true });
  }

  function toggleArrayParam(key, value) {
    updateParams((next) => {
      const current = readArrayParam(next, key);
      const updated = current.includes(value)
        ? current.filter((item) => item !== value)
        : [...current, value];
      if (updated.length) next.set(key, updated.join(","));
      else next.delete(key);
    });
  }

  function setPriceParam(key, value) {
    updateParams((next) => {
      if (value) next.set(key, value);
      else next.delete(key);
    });
  }

  function setSort(value) {
    updateParams((next) => {
      if (value && value !== "newest") next.set("sort", value);
      else next.delete("sort");
    });
  }

  function clearFilters() {
    updateParams((next) => {
      ["species", "shop", "breed", "minPrice", "maxPrice"].forEach((key) => next.delete(key));
    });
  }

  const filteredPets = useMemo(() => {
    const filtered = applyPetFilters(pets, {
      species,
      shops: shopIds,
      breeds,
      minPrice: minPrice ? Number(minPrice) : undefined,
      maxPrice: maxPrice ? Number(maxPrice) : undefined,
    });
    return sortPets(filtered, sort);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams.toString()]);

  return (
    <Container className="py-10 lg:py-12">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Shop pets</h1>
          <p className="mt-2 text-[15px] text-ink-soft">
            {filteredPets.length} {filteredPets.length === 1 ? "pet" : "pets"} across every shop
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => setFiltersOpen(true)}
            className="flex items-center gap-2 rounded-lg border border-border px-4 py-2.5 text-sm text-ink lg:hidden"
          >
            <Funnel size={17} />
            Filters
          </button>
          <SortSelect value={sort} onChange={setSort} />
        </div>
      </div>

      <div className="mt-8 lg:grid lg:grid-cols-[240px_1fr] lg:items-start lg:gap-10">
        <FilterSidebar
          species={species}
          shopIds={shopIds}
          breeds={breeds}
          minPrice={minPrice}
          maxPrice={maxPrice}
          onToggleSpecies={(value) => toggleArrayParam("species", value)}
          onToggleShop={(value) => toggleArrayParam("shop", value)}
          onToggleBreed={(value) => toggleArrayParam("breed", value)}
          onPriceChange={setPriceParam}
          onClear={clearFilters}
          open={filtersOpen}
          onClose={() => setFiltersOpen(false)}
          hasActiveFilters={hasActiveFilters}
        />

        {filteredPets.length > 0 ? (
          <div className="grid grid-cols-1 gap-3 xs:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 lg:gap-5 xl:grid-cols-5">
            {filteredPets.map((pet) => (
              <PetCard key={pet.id} pet={pet} />
            ))}
          </div>
        ) : (
          <EmptyState
            title="No pets match these filters"
            description="Try widening your price range or clearing a filter."
            action={
              <Button variant="outline" size="sm" onClick={clearFilters}>
                Clear filters
              </Button>
            }
          />
        )}
      </div>
    </Container>
  );
}
