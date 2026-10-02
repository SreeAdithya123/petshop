import { supabase } from "../../lib/supabaseClient";

/**
 * Takes a resolved Supabase list result whose rows have a `customer_id` and
 * resolves to { data: { rows, profiles, profilesError }, error }. Names and
 * phones come from a second query (there is no FK to embed); row-level
 * security only exposes the people who requested something from this shop.
 */
export async function attachCustomers({ data, error }) {
  if (error) return { data: null, error };

  const rows = data ?? [];
  const ids = [...new Set(rows.map((row) => row.customer_id).filter(Boolean))];
  const profiles = {};
  let profilesError = null;

  if (ids.length > 0) {
    const result = await supabase.from("profiles").select("id, name, phone").in("id", ids);
    if (result.error) profilesError = result.error.message;
    (result.data ?? []).forEach((profile) => {
      profiles[profile.id] = profile;
    });
  }

  return { data: { rows, profiles, profilesError }, error: null };
}
