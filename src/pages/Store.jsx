import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { EmptyState } from "../components/ui/EmptyState";
import { formatPrice } from "../lib/format";
import { supabase } from "../lib/supabaseClient";

const categoryTabs = [
  { value: "all", label: "All" },
  { value: "medicine", label: "Medicine" },
  { value: "store", label: "Store" },
];

export function Store() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [category, setCategory] = useState("all");

  useEffect(() => {
    let cancelled = false;
    async function loadProducts() {
      setLoading(true);
      const { data, error } = await supabase
        .from("products")
        .select("*, shops(name)")
        .eq("status", "available");
      if (cancelled) return;
      if (error) setError(error.message);
      else setProducts(data ?? []);
      setLoading(false);
    }
    loadProducts();
    return () => {
      cancelled = true;
    };
  }, []);

  const filteredProducts =
    category === "all" ? products : products.filter((product) => product.category === category);

  if (loading) {
    return (
      <Container className="py-16">
        <p className="text-ink-soft">Loading…</p>
      </Container>
    );
  }

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

      {error && <p className="mt-6 text-sm text-error">{error}</p>}

      {filteredProducts.length > 0 ? (
        <div className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
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
              <p className="mt-1 text-xs text-ink-soft">{product.stock_quantity} in stock</p>
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
