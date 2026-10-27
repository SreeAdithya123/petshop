import { supabase } from "../../lib/supabaseClient";

export const NOTHING_CHANGED =
  "Nothing was updated. This item may have changed or been removed; refresh the page and try again.";

const NOT_AVAILABLE_YET = "This action isn't available yet. Please try again later.";
const GENERIC_FAILURE = "Something went wrong. Please try again.";

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

/**
 * Calls a Postgres function and resolves to an error message, or null on
 * success. The functions raise readable exceptions ("This pet was put back on
 * sale..."), so the server's message is passed straight through; a function
 * that isn't deployed (PostgREST PGRST202) gets a friendly message instead.
 */
export async function callRpc(name, params) {
  try {
    const { error } = await supabase.rpc(name, params);
    if (!error) return null;
    if (error.code === "PGRST202") return NOT_AVAILABLE_YET;
    return error.message || GENERIC_FAILURE;
  } catch (thrown) {
    return thrown?.message || GENERIC_FAILURE;
  }
}
