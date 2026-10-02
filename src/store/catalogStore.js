import { useEffect, useMemo } from "react";
import { create } from "zustand";
import { PET_PUBLIC_COLUMNS, SHOP_PUBLIC_COLUMNS } from "../lib/columns";
import { supabase } from "../lib/supabaseClient";

/**
 * The customer-facing catalog, read from the real Supabase tables (the same
 * rows shop owners manage in their dashboard) and mapped to the shape the
 * storefront components already use.
 *
 * Deliberately excludes: pets.cost_price (seller margin) and shops.address /
 * shops.phone (shop contact details are never shown to customers).
 * RLS already limits anonymous/customer reads to "available" pets in
 * approved shops.
 */
export function formatAge(months) {
  if (months === null || months === undefined) return "";
  if (months < 1) return "Under 1 month";
  if (months < 12) return `${months} ${months === 1 ? "month" : "months"}`;
  const years = Math.floor(months / 12);
  const rest = months % 12;
  if (rest === 0) return `${years} ${years === 1 ? "year" : "years"}`;
  return `${years} yr ${rest} mo`;
}

export function mapPet(row) {
  return {
    id: row.id,
    name: row.name || row.breed,
    species: row.species,
    breed: row.breed,
    gender: row.gender || null,
    ageLabel: formatAge(row.age_months),
    ageMonths: row.age_months,
    price: Number(row.price),
    shopId: row.shop_id,
    status: row.status,
    listedDate: row.created_at,
    photos: row.photo_urls?.length ? row.photo_urls : null,
    description: row.description || "",
    certification: row.certification || null,
  };
}

export function mapShop(row, stats) {
  return {
    id: row.id,
    name: row.name,
    description: row.description || "",
    bannerUrl: row.banner_url || null,
    licenseNumber: row.license_number,
    rating: stats?.average ?? 0,
    reviewCount: stats?.count ?? 0,
  };
}

export const useCatalogStore = create((set, get) => ({
  pets: [],
  shops: [],
  status: "idle", // idle | loading | ready | error
  error: "",

  load: async ({ force = false } = {}) => {
    const { status } = get();
    if (!force && (status === "loading" || status === "ready")) return;
    set({ status: "loading", error: "" });

    let petsResult;
    let shopsResult;
    let reviewsResult;
    try {
      [petsResult, shopsResult, reviewsResult] = await Promise.all([
        supabase.from("pets").select(PET_PUBLIC_COLUMNS).eq("status", "available").order("created_at", { ascending: false }),
        supabase.from("shops").select(SHOP_PUBLIC_COLUMNS).eq("status", "approved").order("name", { ascending: true }),
        supabase.from("shop_reviews").select("shop_id, rating").eq("hidden", false),
      ]);
    } catch (thrown) {
      set({ status: "error", error: thrown?.message || "Couldn't load the catalog." });
      return;
    }

    const failure = petsResult.error || shopsResult.error;
    if (failure) {
      set({ status: "error", error: failure.message || "Couldn't load the catalog." });
      return;
    }

    const totals = new Map();
    for (const review of reviewsResult.data ?? []) {
      const entry = totals.get(review.shop_id) ?? { sum: 0, count: 0 };
      entry.sum += review.rating;
      entry.count += 1;
      totals.set(review.shop_id, entry);
    }

    const shops = (shopsResult.data ?? []).map((row) => {
      const entry = totals.get(row.id);
      return mapShop(row, entry ? { average: entry.sum / entry.count, count: entry.count } : null);
    });
    const shopIds = new Set(shops.map((shop) => shop.id));
    const pets = (petsResult.data ?? []).filter((row) => shopIds.has(row.shop_id)).map(mapPet);

    set({ pets, shops, status: "ready" });
  },
}));

/**
 * Loads the catalog once (shared across pages) and exposes lookups.
 * Components should treat `loading` as "don't show not-found yet".
 */
export function useCatalog() {
  const pets = useCatalogStore((state) => state.pets);
  const shops = useCatalogStore((state) => state.shops);
  const status = useCatalogStore((state) => state.status);
  const error = useCatalogStore((state) => state.error);
  const load = useCatalogStore((state) => state.load);

  useEffect(() => {
    load();
  }, [load]);

  const derived = useMemo(
    () => ({
      getPetById: (id) => pets.find((pet) => pet.id === id),
      getShopById: (id) => shops.find((shop) => shop.id === id),
      getPetsByShop: (shopId) => pets.filter((pet) => pet.shopId === shopId),
      speciesList: [...new Set(pets.map((pet) => pet.species))].sort(),
      breedList: [...new Set(pets.map((pet) => pet.breed))].sort(),
    }),
    [pets, shops],
  );

  return {
    pets,
    shops,
    loading: status === "idle" || status === "loading",
    error: status === "error" ? error : "",
    reload: () => load({ force: true }),
    ...derived,
  };
}
