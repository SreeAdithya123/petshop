import { useCallback, useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";

// Customer-facing: the shop embed is name-only, never address / phone / city.
const SERVICE_COLUMNS =
  "id, shop_id, category, name, description, price, duration_minutes, photo_urls, status, shops(name)";

/** Approved services (RLS already hides the rest), optionally for one category. */
export function useApprovedServices({ category } = {}) {
  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError("");
      let query = supabase.from("services").select(SERVICE_COLUMNS).eq("status", "approved");
      if (category) query = query.eq("category", category);
      const { data, error: loadError } = await query.order("category").order("name");
      if (cancelled) return;
      if (loadError) setError(loadError.message);
      else setServices(data ?? []);
      setLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [category, reloadKey]);

  const reload = useCallback(() => setReloadKey((key) => key + 1), []);

  return { services, loading, error, reload };
}
