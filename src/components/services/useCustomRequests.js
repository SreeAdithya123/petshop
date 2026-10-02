import { useCallback, useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";

// shop_name is the quoting shop's name; contact details are never part of the row.
const REQUEST_COLUMNS =
  "id, title, description, category, pet_name, pet_species, preferred_date, budget, status, shop_name, quoted_price, response_message, responded_at, created_at";

// Which current statuses a customer may move a request out of, per target status.
const ALLOWED_FROM = {
  cancelled: ["open", "quoted"],
  accepted: ["quoted"],
  declined: ["quoted"],
};

/** The signed-in customer's own custom service requests, with accept / decline / cancel. */
export function useCustomRequests({ userId } = {}) {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [busyId, setBusyId] = useState(null);
  const [actionError, setActionError] = useState("");

  useEffect(() => {
    if (!userId) return undefined;

    let cancelled = false;
    async function load() {
      setLoading(true);
      setError("");
      const { data, error: loadError } = await supabase
        .from("custom_service_requests")
        .select(REQUEST_COLUMNS)
        .eq("customer_id", userId)
        .order("created_at", { ascending: false });
      if (cancelled) return;
      if (loadError) setError(loadError.message);
      else setRequests(data ?? []);
      setLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [userId, reloadKey]);

  const reload = useCallback(() => setReloadKey((key) => key + 1), []);

  const changeStatus = useCallback(
    async (id, nextStatus) => {
      setBusyId(id);
      setActionError("");
      const { data, error: updateError } = await supabase
        .from("custom_service_requests")
        .update({ status: nextStatus })
        .eq("id", id)
        .in("status", ALLOWED_FROM[nextStatus])
        .select("id");
      if (updateError) setActionError(updateError.message);
      else if (!data?.length) setActionError("That request has changed since you loaded this page. Showing its latest status.");
      reload();
      setBusyId(null);
    },
    [reload],
  );

  // Signed out: expose an empty, settled list without touching state.
  return {
    requests: userId ? requests : [],
    loading: userId ? loading : false,
    error: userId ? error : "",
    reload,
    changeStatus,
    busyId,
    actionError,
  };
}
