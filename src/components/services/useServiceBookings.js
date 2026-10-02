import { useCallback, useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";

const BOOKING_COLUMNS =
  "id, service_id, booking_date, booking_time, delivery_mode, video_room_url, status, price_at_booking, notes, created_at, service_name, service_category, shop_name";

/**
 * The signed-in customer's own service bookings, newest first, plus the one
 * action a customer may take on them (cancel). Pass `userId: null` while
 * signed out; `category` narrows the list (e.g. "vet" for consultations).
 */
export function useServiceBookings({ userId, category } = {}) {
  const [bookings, setBookings] = useState([]);
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
      let query = supabase.from("service_bookings").select(BOOKING_COLUMNS).eq("customer_id", userId);
      if (category) query = query.eq("service_category", category);
      const { data, error: loadError } = await query.order("created_at", { ascending: false });
      if (cancelled) return;
      if (loadError) setError(loadError.message);
      else setBookings(data ?? []);
      setLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [userId, category, reloadKey]);

  const reload = useCallback(() => setReloadKey((key) => key + 1), []);

  const cancelBooking = useCallback(
    async (id) => {
      setBusyId(id);
      setActionError("");
      // .select() so a row filtered out by RLS / the status guard is noticed.
      const { data, error: updateError } = await supabase
        .from("service_bookings")
        .update({ status: "cancelled" })
        .eq("id", id)
        .in("status", ["pending", "confirmed"])
        .select("id");
      if (updateError) setActionError(updateError.message);
      else if (!data?.length) setActionError("That booking can't be cancelled any more. Its status may have changed.");
      reload();
      setBusyId(null);
    },
    [reload],
  );

  // Signed out: expose an empty, settled list without touching state.
  return {
    bookings: userId ? bookings : [],
    loading: userId ? loading : false,
    error: userId ? error : "",
    reload,
    cancelBooking,
    busyId,
    actionError,
  };
}
