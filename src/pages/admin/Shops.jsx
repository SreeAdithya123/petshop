import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";

const STATUS_STYLES = {
  approved: "text-trust",
  pending: "text-ink-soft",
  suspended: "text-error",
};

export function AdminShops() {
  const [shops, setShops] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);

  async function loadShops() {
    setLoading(true);
    const { data } = await supabase
      .from("shops")
      .select("*, profiles(name,email)")
      .order("created_at", { ascending: false });
    setShops(data ?? []);
    setLoading(false);
  }

  useEffect(() => {
    loadShops();
  }, []);

  async function updateStatus(shop, nextStatus, { confirmMessage } = {}) {
    if (confirmMessage && !window.confirm(confirmMessage)) return;
    setBusyId(shop.id);
    await supabase.from("shops").update({ status: nextStatus }).eq("id", shop.id);
    await loadShops();
    setBusyId(null);
  }

  function renderActions(shop) {
    const disabled = busyId === shop.id;
    if (shop.status === "pending") {
      return (
        <div className="flex gap-2">
          <Button
            variant="primary"
            size="sm"
            disabled={disabled}
            onClick={() => updateStatus(shop, "approved")}
          >
            Approve
          </Button>
          <Button
            variant="outline"
            size="sm"
            disabled={disabled}
            onClick={() =>
              updateStatus(shop, "suspended", {
                confirmMessage: `Suspend ${shop.name}? This shop will not be approved.`,
              })
            }
          >
            Suspend
          </Button>
        </div>
      );
    }
    if (shop.status === "approved") {
      return (
        <Button
          variant="outline"
          size="sm"
          disabled={disabled}
          onClick={() =>
            updateStatus(shop, "suspended", {
              confirmMessage: `Suspend ${shop.name}? It will no longer be visible to customers.`,
            })
          }
        >
          Suspend
        </Button>
      );
    }
    return (
      <Button variant="primary" size="sm" disabled={disabled} onClick={() => updateStatus(shop, "approved")}>
        Reactivate
      </Button>
    );
  }

  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-bold text-ink">Manage shops</h1>
      <p className="mt-1 text-[15px] text-ink-soft">Approve, suspend, or reactivate shops on the platform.</p>

      {!loading && shops.length === 0 && (
        <div className="mt-8">
          <EmptyState title="No shops yet" description="Shops will appear here once sellers register." />
        </div>
      )}

      {shops.length > 0 && (
        <ul className="mt-8 divide-y divide-border rounded-xl border border-border bg-surface">
          {shops.map((shop) => (
            <li key={shop.id} className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <div className="font-display font-semibold text-ink">{shop.name}</div>
                <div className="mt-1 text-sm text-ink-soft">
                  {shop.profiles?.name ?? "Unknown owner"}
                  {shop.profiles?.email ? ` · ${shop.profiles.email}` : ""}
                </div>
                <div className="mt-1 text-sm text-ink-soft">
                  License {shop.license_number || "—"} · {shop.address || "No address on file"}
                </div>
                <div className={`mt-2 text-sm font-medium ${STATUS_STYLES[shop.status] ?? "text-ink-soft"}`}>
                  {shop.status}
                </div>
              </div>
              {renderActions(shop)}
            </li>
          ))}
        </ul>
      )}
    </Container>
  );
}
