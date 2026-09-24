import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { formatPrice } from "../lib/format";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";

export function ProductDetail() {
  const { id } = useParams();
  const session = useAuthStore((state) => state.session);

  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [purchasing, setPurchasing] = useState(false);
  const [purchaseError, setPurchaseError] = useState("");
  const [purchased, setPurchased] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function loadProduct() {
      setLoading(true);
      const { data, error } = await supabase
        .from("products")
        .select("*, shops(name, address, phone)")
        .eq("id", id)
        .single();
      if (cancelled) return;
      if (error || !data) setNotFound(true);
      else setProduct(data);
      setLoading(false);
    }
    loadProduct();
    return () => {
      cancelled = true;
    };
  }, [id]);

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
      <Container className="py-16">
        <p className="text-ink-soft">Loading…</p>
      </Container>
    );
  }

  if (notFound || !product) {
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

  return (
    <Container className="py-12">
      <div className="mx-auto max-w-2xl">
        <p className="text-sm capitalize text-ink-soft">{product.category}</p>
        <h1 className="mt-1 font-display text-3xl font-bold text-ink">{product.name}</h1>
        <p className="mt-3 font-display text-2xl font-semibold text-accent">{formatPrice(product.price)}</p>

        {product.description && <p className="mt-4 text-[15px] text-ink-soft">{product.description}</p>}

        <p className="mt-2 text-sm text-ink-soft">{product.stock_quantity} in stock</p>

        <div className="mt-6 rounded-xl border border-border bg-surface p-4 text-sm text-ink-soft">
          <p className="font-medium text-ink">{product.shops?.name}</p>
          {product.shops?.address && <p className="mt-1">{product.shops.address}</p>}
          {product.shops?.phone && <p className="mt-1">{product.shops.phone}</p>}
        </div>

        {purchased ? (
          <p className="mt-6 text-[15px] text-trust">
            Order placed — pick up and pay at {product.shops?.name}.
          </p>
        ) : session ? (
          <>
            <Button variant="accent" size="lg" className="mt-6" onClick={handlePurchase} disabled={purchasing}>
              {purchasing ? "Placing order…" : "Add to Cart"}
            </Button>
            {purchaseError && <p className="mt-2 text-sm text-error">{purchaseError}</p>}
          </>
        ) : (
          <Button to="/login" variant="accent" size="lg" className="mt-6">
            Log in to buy
          </Button>
        )}
      </div>
    </Container>
  );
}
