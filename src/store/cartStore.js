import { create } from "zustand";
import { persist } from "zustand/middleware";

/**
 * Cart + wishlist state. Each line item is just a pet id — quantity is
 * always 1 (a pet is a unique animal, not a restockable SKU), so "add"
 * is idempotent and there is no quantity to track or increment.
 *
 * Persisted to localStorage via Zustand's `persist` middleware; the drawer
 * open/closed flag is deliberately excluded from persistence (a reload
 * should not resurrect an open drawer). No network calls anywhere here —
 * this is UI-only state for a phase with no backend.
 */
export const useCartStore = create(
  persist(
    (set, get) => ({
      items: [],
      wishlist: [],
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

      toggleWishlist: (petId) => {
        set((state) => ({
          wishlist: state.wishlist.includes(petId)
            ? state.wishlist.filter((id) => id !== petId)
            : [...state.wishlist, petId],
        }));
      },
      isInWishlist: (petId) => get().wishlist.includes(petId),

      openDrawer: () => set({ isDrawerOpen: true }),
      closeDrawer: () => set({ isDrawerOpen: false }),
    }),
    {
      name: "petstore.cart.v1",
      partialize: (state) => ({ items: state.items, wishlist: state.wishlist }),
    },
  ),
);
