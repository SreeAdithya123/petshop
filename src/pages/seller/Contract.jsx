import { useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { useMyShop } from "../../hooks/useMyShop";
import { supabase } from "../../lib/supabaseClient";

export function SellerContract() {
  const { shop, loading, refetch } = useMyShop();
  const [accepting, setAccepting] = useState(false);
  const [error, setError] = useState(null);

  async function handleAccept() {
    if (!shop || shop.contract_accepted_at) return;
    setAccepting(true);
    setError(null);

    const update = { contract_accepted_at: new Date().toISOString() };
    if (!shop.contract_version) update.contract_version = "1.0";

    const { error: updateError } = await supabase.from("shops").update(update).eq("id", shop.id);

    if (updateError) setError(updateError.message);
    else await refetch();
    setAccepting(false);
  }

  if (loading) {
    return (
      <Container className="py-12">
        <p className="text-[15px] text-ink-soft">Loading contract…</p>
      </Container>
    );
  }

  if (!shop) {
    return (
      <Container className="py-12">
        <EmptyState
          title="You haven't set up your shop yet"
          description="Create your shop profile first."
          action={
            <Button to="/seller/store" size="sm">
              Set up your shop
            </Button>
          }
        />
      </Container>
    );
  }

  const isAccepted = Boolean(shop.contract_accepted_at);

  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-bold text-ink">Seller contract</h1>
      <p className="mt-2 text-[15px] text-ink-soft">The terms your shop operates under on Paws Nearby.</p>

      <div className="mt-8 max-w-2xl rounded-xl border border-border bg-surface p-6">
        <dl className="flex flex-col gap-3">
          <div className="flex justify-between text-sm">
            <dt className="text-ink-soft">Contract version</dt>
            <dd className="text-ink">{shop.contract_version || "No contract version on file yet"}</dd>
          </div>
          <div className="flex justify-between text-sm">
            <dt className="text-ink-soft">Accepted on</dt>
            <dd className="text-ink">
              {isAccepted ? new Date(shop.contract_accepted_at).toLocaleDateString() : "Not yet accepted"}
            </dd>
          </div>
        </dl>

        {isAccepted ? (
          <p className="mt-6 flex items-center gap-2 text-sm font-medium text-trust">
            <span className="h-2 w-2 rounded-full bg-trust" />
            You've accepted the current seller contract.
          </p>
        ) : (
          <div className="mt-6 border-t border-border pt-6">
            <p className="text-[15px] text-ink">
              By accepting this contract, you agree to list only pets and products you're licensed to sell,
              to keep your inventory and pricing accurate, to fulfill paid orders promptly, and to respond to
              customer support requests in good faith. Paws Nearby may suspend shops that violate these terms.
            </p>
            {error && <p className="mt-3 text-sm text-error">{error}</p>}
            <Button variant="accent" size="md" onClick={handleAccept} disabled={accepting} className="mt-5">
              {accepting ? "Accepting…" : "Accept contract"}
            </Button>
          </div>
        )}
      </div>
    </Container>
  );
}
