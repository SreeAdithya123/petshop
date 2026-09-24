import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";
import { Container } from "../../components/layout/Container";
import { EmptyState } from "../../components/ui/EmptyState";

const DEFAULT_VERSION = "1.0";

function mostCommonVersion(shops) {
  const counts = new Map();
  shops.forEach((shop) => {
    if (!shop.contract_version) return;
    counts.set(shop.contract_version, (counts.get(shop.contract_version) ?? 0) + 1);
  });

  let best = null;
  let bestCount = 0;
  counts.forEach((count, version) => {
    if (count > bestCount) {
      best = version;
      bestCount = count;
    }
  });
  return best ?? DEFAULT_VERSION;
}

export function AdminContracts() {
  const [shops, setShops] = useState([]);
  const [loading, setLoading] = useState(true);
  const [currentVersion, setCurrentVersion] = useState(DEFAULT_VERSION);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoading(true);
      const { data } = await supabase
        .from("shops")
        .select("id,name,contract_version,contract_accepted_at")
        .order("name", { ascending: true });
      if (cancelled) return;
      const list = data ?? [];
      setShops(list);
      setCurrentVersion(mostCommonVersion(list));
      setLoading(false);
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-bold text-ink">Contract compliance</h1>
      <p className="mt-1 text-[15px] text-ink-soft">
        Track which shops have accepted the current seller contract.
      </p>

      <div className="mt-6 rounded-xl border border-border bg-surface p-6">
        <h2 className="font-display text-2xl font-semibold text-ink">Contract version {currentVersion}</h2>
        <p className="mt-3 max-w-2xl text-[15px] leading-relaxed text-ink-soft">
          This agreement sets out the terms under which a shop lists pets and products on Paws Nearby,
          including listing standards, pricing responsibilities, and payment handling between the shop and
          its customers. It also confirms Paws Nearby's role as a marketplace connecting local buyers and
          sellers, rather than a party to any individual sale. Shop owners are expected to review and accept
          the current version to keep selling on the platform.
        </p>
      </div>

      <h2 className="mt-10 font-display text-xl font-semibold text-ink">Shop acceptance status</h2>
      <p className="mt-1 text-sm text-ink-soft">Whether each shop has accepted the current contract version.</p>

      {loading && <p className="mt-6 text-[15px] text-ink-soft">Loading shops…</p>}

      {!loading && shops.length === 0 && (
        <div className="mt-6">
          <EmptyState title="No shops yet" description="Shops will appear here once sellers register." />
        </div>
      )}

      {!loading && shops.length > 0 && (
        <ul className="mt-6 divide-y divide-border rounded-xl border border-border bg-surface">
          {shops.map((shop) => {
            const accepted = Boolean(shop.contract_accepted_at) && shop.contract_version === currentVersion;
            return (
              <li key={shop.id} className="flex items-center justify-between gap-4 p-5">
                <div>
                  <div className="font-display font-semibold text-ink">{shop.name}</div>
                  <div className="mt-1 text-sm text-ink-soft">
                    {shop.contract_version ? `Version ${shop.contract_version}` : "No version on file"}
                  </div>
                </div>
                <span className={`text-sm font-medium ${accepted ? "text-trust" : "text-error"}`}>
                  {accepted ? "Accepted" : "Not accepted"}
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </Container>
  );
}
