import { useEffect } from "react";
import { create } from "zustand";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "./authStore";

/**
 * Pet wishlist backed by the `wishlists` table (RLS: a customer only ever
 * sees/changes their own rows), so it survives devices and shows up in
 * My Account -> Wishlist.
 */
export const useWishlistStore = create((set, get) => ({
  petIds: [],
  loadedFor: null,

  load: async (userId) => {
    if (!userId) {
      set({ petIds: [], loadedFor: null });
      return;
    }
    if (get().loadedFor === userId) return;
    const { data } = await supabase
      .from("wishlists")
      .select("item_id")
      .eq("customer_id", userId)
      .eq("item_type", "pet");
    set({ petIds: (data ?? []).map((row) => row.item_id), loadedFor: userId });
  },

  /** Returns true when the change was saved. */
  toggle: async (userId, petId) => {
    if (!userId) return false;
    const has = get().petIds.includes(petId);
    set({ petIds: has ? get().petIds.filter((id) => id !== petId) : [...get().petIds, petId] });

    const request = has
      ? supabase.from("wishlists").delete().eq("customer_id", userId).eq("item_type", "pet").eq("item_id", petId)
      : supabase.from("wishlists").insert({ customer_id: userId, item_type: "pet", item_id: petId });
    const { error } = await request;
    if (error) {
      set({ petIds: has ? [...get().petIds, petId] : get().petIds.filter((id) => id !== petId) });
      return false;
    }
    return true;
  },
}));

/** { isWishlisted(petId), toggle(petId) -> Promise<boolean>, signedIn } */
export function useWishlist() {
  const userId = useAuthStore((state) => state.session?.user?.id ?? null);
  const petIds = useWishlistStore((state) => state.petIds);
  const load = useWishlistStore((state) => state.load);
  const toggleInStore = useWishlistStore((state) => state.toggle);

  useEffect(() => {
    load(userId);
  }, [userId, load]);

  return {
    signedIn: Boolean(userId),
    petIds,
    isWishlisted: (petId) => petIds.includes(petId),
    toggle: (petId) => toggleInStore(userId, petId),
  };
}
