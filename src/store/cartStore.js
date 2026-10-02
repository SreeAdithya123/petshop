import { create } from "zustand";
import { persist } from "zustand/middleware";

/**
 * Pet cart. Each line item is just a pet id — quantity is always 1 (a pet is
 * a unique animal, not a restockable SKU), so "add" is idempotent. Names,
 * prices and shops are resolved from the live catalog at render time and
 * never stored, so a sold or repriced pet can't leave a stale cart line;
 * `pruneCart` drops ids the catalog no longer lists.
 *
 * Persisted to localStorage via Zustand's `persist` middleware; the drawer
 * open/closed flag is deliberately excluded (a reload should not resurrect an
 * open drawer). The wishlist now lives in the database (see wishlistStore).
 */

/** Accepts ids or older `{ id }` objects; anything else is dropped. */
function cleanIds(value) {
  if (!Array.isArray(value)) return [];
  const ids = value.map((item) => (typeof item === "string" ? item : item?.id));
  return [...new Set(ids.filter((id) => typeof id === "string" && id))];
}

export const useCartStore = create(
  persist(
    (set, get) => ({
      items: [],
      isDrawerOpen: false,

      addToCart: (petId) => {
        if (get().items.includes(petId)) return;
        set((state) => ({ items: [...state.items, petId] }));
      },
      removeFromCart: (petId) => {
        set((state) => ({ items: state.items.filter((id) => id !== petId) }));
      },
      isInCart: (petId) => get().items.includes(petId),
      clearCart: () => set({ items: [] }),

      /** Drops cart pets that aren't in `validPetIds`. Returns how many were removed. */
      pruneCart: (validPetIds) => {
        const valid = new Set(validPetIds);
        const before = get().items;
        const after = before.filter((id) => valid.has(id));
        if (after.length === before.length) return 0;
        set({ items: after });
        return before.length - after.length;
      },

      openDrawer: () => set({ isDrawerOpen: true }),
      closeDrawer: () => set({ isDrawerOpen: false }),
    }),
    {
      name: "petstore.cart.v1",
      partialize: (state) => ({ items: state.items }),
      // Old persisted shapes (with a local wishlist, or malformed items) must never break hydration.
      merge: (persisted, current) => ({ ...current, items: cleanIds(persisted?.items) }),
    },
  ),
);
