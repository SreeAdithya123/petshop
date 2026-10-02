import { useEffect } from "react";
import { useLocation } from "react-router-dom";

/**
 * Scrolls to the element named by the URL hash (/services#my-bookings).
 * React Router doesn't, and the target often only exists once data has
 * loaded, so pass `ready` to wait for it.
 */
export function useHashScroll(ready = true) {
  const { hash } = useLocation();

  useEffect(() => {
    if (!hash || !ready) return;
    document.getElementById(hash.slice(1))?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [hash, ready]);
}
