import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";

/**
 * The signed-in shop owner's own shop row, or null if they haven't
 * created one yet (a shop_owner account doesn't automatically get a shop
 * — /seller/store is where they self-apply, per the shops_insert_own RLS
 * policy). Every /seller/* page needs this to scope its own queries and
 * to handle "no shop yet" consistently.
 */
export function useMyShop() {
  const userId = useAuthStore((state) => state.session?.user?.id);
  const [shop, setShop] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const refetch = useCallback(async () => {
    if (!userId) {
      setShop(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    const { data, error: queryError } = await supabase
      .from("shops")
      .select("*")
      .eq("owner_id", userId)
      .maybeSingle();
    if (queryError) setError(queryError.message);
    else {
      setError(null);
      setShop(data);
    }
    setLoading(false);
  }, [userId]);

  useEffect(() => {
    refetch();
  }, [refetch]);

  return { shop, loading, error, refetch };
}
