import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { LoginPrompt } from "../components/ui/LoginPrompt";
import { PRODUCT_PUBLIC_COLUMNS } from "../lib/columns";
import { formatPrice } from "../lib/format";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";

export function ProductDetail() {
  const { id } = useParams();
  const session = useAuthStore((state) => state.session);

  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [attempt, setAttempt] = useState(0);
  const [purchasing, setPurchasing] = useState(false);
  const [purchaseError, setPurchaseError] = useState("");
  const [purchased, setPurchased] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function loadProduct() {
      setLoading(true);
      setLoadError("");
      setProduct(null);
      setPurchased(false);
      setPurchaseError("");
      // Public columns only, and just the shop's name: shop contact details are never shown to customers.
      const { data, error } = await supabase
        .from("products")
        .select(`${PRODUCT_PUBLIC_COLUMNS}, shops(name)`)
        .eq("id", id)
        .maybeSingle();
      if (cancelled) return;
      // 22P02: the id in the URL isn't a valid uuid, i.e. there's no such product.
      if (error && error.code !== "22P02") setLoadError(error.message || "Couldn't load this product.");
      else setProduct(data ?? null);
      setLoading(false);
    }
    loadProduct();
    return () => {
      cancelled = true;
    };
  }, [id, attempt]);

  async function handlePurchase() {
    if (!session || !product) return;
    setPurchasing(true);
    setPurchaseError("");
    try {
      const { data: order, error: orderError } = await supabase
        .from("orders")
        .insert({
          customer_id: session.user.id,
          order_type: "product_purchase",
          status: "pending",
          payment_type: "full",
          total_amount: product.price,
        })
        .select()
        .single();
      if (orderError) throw orderError;

      const { error: itemError } = await supabase.from("order_items").insert({
        order_id: order.id,
        item_type: "product",
        item_id: product.id,
        quantity: 1,
        price_at_purchase: product.price,
      });
      if (itemError) throw itemError;

      setPurchased(true);
    } catch (error) {
      setPurchaseError(error.message || "Couldn't place that order. Try again.");
    } finally {
      setPurchasing(false);
    }
  }

  if (loading) {
    return (
      <Container className="py-12">
        <div role="status" aria-label="Loading product" className="mx-auto max-w-2xl animate-pulse">
          <div className="h-4 w-20 rounded bg-border/50" />
          <div className="mt-3 h-8 w-2/3 rounded bg-border/50" />
          <div className="mt-4 h-7 w-28 rounded bg-border/50" />
          <div className="mt-6 h-4 w-full rounded bg-border/50" />
          <div className="mt-2 h-4 w-3/4 rounded bg-border/50" />
        </div>
      </Container>
    );
  }

  if (loadError) {
    return (
      <Container className="py-16">
        <EmptyState
          title="We couldn't load that product"
          description={loadError}
          action={
            <Button size="sm" onClick={() => setAttempt((count) => count + 1)}>
              Try again
            </Button>
          }
        />
      </Container>
    );
  }

  if (!product) {
    return (
      <Container className="py-16">
        <EmptyState
          title="We couldn't find that product"
          action={
            <Button to="/store" size="sm">
              Browse the store
            </Button>
          }
        />
      </Container>
    );
  }

  const outOfStock = product.stock_quantity <= 0;
  const unavailable = product.status !== "available" || outOfStock;

  return (
    <Container className="py-12">
      <div className="mx-auto max-w-2xl">
        <p className="text-sm capitalize text-ink-soft">{product.category}</p>
        <h1 className="mt-1 font-display text-3xl font-bold text-ink">{product.name}</h1>
        <p className="mt-3 font-display text-2xl font-semibold text-accent">{formatPrice(product.price)}</p>

        {product.description && <p className="mt-4 text-[15px] text-ink-soft">{product.description}</p>}

        <p className="mt-2 text-sm text-ink-soft">
          {outOfStock ? "Out of stock" : `${product.stock_quantity} in stock`}
        </p>

        <div className="mt-6 rounded-xl border border-border bg-surface p-4 text-sm text-ink-soft">
          <p className="font-medium text-ink">{product.shops?.name}</p>
          <p className="mt-1">The shop will confirm pickup details with you after you place the order.</p>
        </div>

        {purchased ? (
          <p className="mt-6 text-[15px] text-trust">
            Order placed — the shop will confirm pickup details with you. Pay in person at pickup.
          </p>
        ) : unavailable ? (
          <p className="mt-6 text-[15px] text-ink-soft">This product isn&apos;t available right now.</p>
        ) : session ? (
          <>
            <Button variant="accent" size="lg" className="mt-6" onClick={handlePurchase} disabled={purchasing}>
              {purchasing ? "Placing order…" : "Order for pickup"}
            </Button>
            {purchaseError && <p className="mt-2 text-sm text-error">{purchaseError}</p>}
          </>
        ) : (
          <div className="mt-6">
            <LoginPrompt compact description="to order this product." />
          </div>
        )}
      </div>
    </Container>
  );
}
