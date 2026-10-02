import { useCallback, useEffect, useState } from "react";

/**
 * Runs `load` (async, resolving to a Supabase-style { data, error }) on mount
 * and whenever its identity changes, so wrap it in useCallback. `loading` is
 * true only until the first result; `reload()` refetches in the background and
 * keeps the previous data on screen if the refetch fails.
 */
export function useLoader(load) {
  const [state, setState] = useState({ data: null, error: null, loading: true });
  const [version, setVersion] = useState(0);

  useEffect(() => {
    let cancelled = false;

    async function run() {
      let result;
      try {
        result = await load();
      } catch (thrown) {
        result = { data: null, error: thrown };
      }
      if (cancelled) return;
      setState((previous) => ({
        data: result.error ? previous.data : result.data,
        error: result.error ? result.error.message || "Something went wrong." : null,
        loading: false,
      }));
    }

    run();
    return () => {
      cancelled = true;
    };
  }, [load, version]);

  const reload = useCallback(() => setVersion((current) => current + 1), []);

  return { ...state, reload };
}
