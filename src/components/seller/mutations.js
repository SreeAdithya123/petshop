import { supabase } from "../../lib/supabaseClient";

const NOTHING_CHANGED =
  "Nothing was updated. This item may have changed or been removed; refresh the page and try again.";

/**
 * Updates one row and resolves to an error message, or null on success.
 * `match` adds extra equality filters (typically the status the row must still
 * be in) so a stale screen can't overwrite a newer state. Row-level security
 * filters rejected rows silently, so a zero-row result is reported as a failure.
 */
export async function updateRow(table, id, patch, match) {
  let query = supabase.from(table).update(patch, { count: "exact" }).eq("id", id);
  if (match) query = query.match(match);
  const { error, count } = await query;
  if (error) return error.message;
  if (count === 0) return NOTHING_CHANGED;
  return null;
}

/** Deletes one row and resolves to an error message, or null on success. */
export async function deleteRow(table, id) {
  const { error, count } = await supabase.from(table).delete({ count: "exact" }).eq("id", id);
  if (error) return error.message;
  if (count === 0) return NOTHING_CHANGED;
  return null;
}
