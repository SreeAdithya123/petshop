import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { PRODUCT_PUBLIC_COLUMNS } from "../lib/columns";
import { formatPrice } from "../lib/format";
import { supabase } from "../lib/supabaseClient";

const categoryTabs = [
  { value: "all", label: "All" },
  { value: "medicine", label: "Medicine" },
  { value: "store", label: "Store" },
];

const GRID_CLASS = "mt-8 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4";

function ProductCardSkeleton() {
  return (
    <div aria-hidden="true" className="animate-pulse rounded-xl border border-border bg-surface p-4">
      <div className="h-3 w-1/4 rounded bg-border/50" />
      <div className="mt-2 h-4 w-3/4 rounded bg-border/50" />
      <div className="mt-2 h-3.5 w-1/2 rounded bg-border/50" />
      <div className="mt-3 h-5 w-1/3 rounded bg-border/50" />
    </div>
  );
}

export function Store() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [category, setCategory] = useState("all");
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    async function loadProducts() {
      setLoading(true);
      setError("");
      const { data, error: queryError } = await supabase
        .from("products")
        .select(`${PRODUCT_PUBLIC_COLUMNS}, shops(name)`)
        .eq("status", "available")
        .order("created_at", { ascending: false });
      if (cancelled) return;
      if (queryError) setError(queryError.message || "Couldn't load products.");
      else setProducts(data ?? []);
      setLoading(false);
    }
    loadProducts();
    return () => {
      cancelled = true;
    };
  }, [attempt]);

  const filteredProducts =
    category === "all" ? products : products.filter((product) => product.category === category);

  return (
    <Container className="py-10 lg:py-12">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Store</h1>
      <p className="mt-2 text-[15px] text-ink-soft">Medicine and everyday supplies from shops near you.</p>

      <div className="mt-6 flex gap-2">
        {categoryTabs.map((tab) => (
          <button
            key={tab.value}
            type="button"
            onClick={() => setCategory(tab.value)}
            className={`rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
              category === tab.value
                ? "bg-primary text-white"
                : "border border-border text-ink hover:bg-primary/5"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className={GRID_CLASS} role="status" aria-label="Loading products">
          {Array.from({ length: 8 }).map((_, index) => (
            <ProductCardSkeleton key={index} />
          ))}
        </div>
      ) : error ? (
        <EmptyState
          title="We couldn't load the store"
          description={error}
          action={
            <Button size="sm" onClick={() => setAttempt((count) => count + 1)}>
              Try again
            </Button>
          }
        />
      ) : filteredProducts.length > 0 ? (
        <div className={GRID_CLASS}>
          {filteredProducts.map((product) => (
            <Link
              key={product.id}
              to={`/store/${product.id}`}
              className="flex flex-col rounded-xl border border-border bg-surface p-4 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]"
            >
              <p className="text-xs capitalize text-ink-soft">{product.category}</p>
              <h3 className="mt-1 text-[15px] font-medium text-ink">{product.name}</h3>
              <p className="mt-1 truncate text-sm text-ink-soft">{product.shops?.name}</p>
              <p className="mt-2 font-display text-lg font-semibold text-accent">
                {formatPrice(product.price)}
              </p>
              <p className="mt-1 text-xs text-ink-soft">
                {product.stock_quantity > 0 ? `${product.stock_quantity} in stock` : "Out of stock"}
              </p>
            </Link>
          ))}
        </div>
      ) : (
        <EmptyState
          title="No products found"
          description="Try a different category, or check back later."
        />
      )}
    </Container>
  );
}
