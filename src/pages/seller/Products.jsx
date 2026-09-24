import { useEffect, useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { supabase } from "../../lib/supabaseClient";
import { useMyShop } from "../../hooks/useMyShop";
import { formatPrice } from "../../lib/format";

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

const statusStyles = {
  available: "text-trust",
  unavailable: "text-ink-soft",
};

const emptyForm = {
  category: "medicine",
  name: "",
  description: "",
  price: "",
  stock_quantity: "",
  photo_urls: "",
};

function validate(form) {
  const errors = {};
  if (!form.name.trim()) errors.name = "Enter a product name.";
  if (!form.price.trim()) errors.price = "Enter a price.";
  else if (Number.isNaN(Number(form.price)) || Number(form.price) < 0) errors.price = "Enter a valid price.";
  if (!form.stock_quantity.trim()) errors.stock_quantity = "Enter a stock quantity.";
  else if (Number.isNaN(Number(form.stock_quantity)) || Number(form.stock_quantity) < 0) {
    errors.stock_quantity = "Enter a valid stock quantity.";
  }
  return errors;
}

export function SellerProducts() {
  const { shop, loading: shopLoading } = useMyShop();
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function loadProducts(shopId) {
    setLoading(true);
    const { data, error: queryError } = await supabase
      .from("products")
      .select("*")
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false });
    if (queryError) setError(queryError.message);
    else {
      setError(null);
      setProducts(data || []);
    }
    setLoading(false);
  }

  useEffect(() => {
    if (shop) loadProducts(shop.id);
    else setLoading(false);
  }, [shop]);

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    const validationErrors = validate(form);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const photoUrls = form.photo_urls
        .split(",")
        .map((url) => url.trim())
        .filter(Boolean);

      const { error: insertError } = await supabase.from("products").insert({
        shop_id: shop.id,
        category: form.category,
        name: form.name.trim(),
        description: form.description.trim() || null,
        price: Number(form.price),
        stock_quantity: Number(form.stock_quantity),
        photo_urls: photoUrls,
      });
      if (insertError) throw insertError;

      setForm(emptyForm);
      setErrors({});
      setFormOpen(false);
      await loadProducts(shop.id);
    } catch (submitError) {
      setFormError(submitError.message || "Something went wrong adding this product.");
    } finally {
      setSubmitting(false);
    }
  }

  async function toggleAvailability(product) {
    const nextStatus = product.status === "available" ? "unavailable" : "available";
    const { error: updateError } = await supabase
      .from("products")
      .update({ status: nextStatus })
      .eq("id", product.id);
    if (!updateError) await loadProducts(shop.id);
  }

  async function deleteProduct(productId) {
    if (!window.confirm("Delete this listing?")) return;
    const { error: deleteError } = await supabase.from("products").delete().eq("id", productId);
    if (!deleteError) await loadProducts(shop.id);
  }

  if (!shopLoading && !shop) {
    return (
      <Container className="py-12">
        <EmptyState
          title="You haven't set up your shop yet"
          description="Create your shop profile to start listing pets and products."
          action={
            <Button to="/seller/store" size="sm">
              Set up your shop
            </Button>
          }
        />
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <div className="flex items-center justify-between gap-4">
        <h1 className="font-display text-3xl font-bold text-ink">Products</h1>
        <Button type="button" variant="accent" size="sm" onClick={() => setFormOpen((open) => !open)}>
          {formOpen ? "Cancel" : "Add a product"}
        </Button>
      </div>

      {formOpen && (
        <form
          onSubmit={handleSubmit}
          noValidate
          className="mt-6 flex flex-col gap-5 rounded-xl border border-border bg-surface p-6"
        >
          <div className="grid gap-5 sm:grid-cols-2">
            <div>
              <label htmlFor="category" className="block text-sm text-ink">
                Category
              </label>
              <select
                id="category"
                value={form.category}
                onChange={(event) => updateField("category", event.target.value)}
                className="mt-1.5 w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
              >
                <option value="medicine">Medicine</option>
                <option value="store">Store</option>
              </select>
            </div>

            <div>
              <label htmlFor="name" className="block text-sm text-ink">
                Product name
              </label>
              <input
                id="name"
                type="text"
                value={form.name}
                onChange={(event) => updateField("name", event.target.value)}
                aria-invalid={Boolean(errors.name)}
                className={fieldClassName(Boolean(errors.name))}
              />
              {errors.name && <p className="mt-1.5 text-sm text-error">{errors.name}</p>}
            </div>

            <div>
              <label htmlFor="price" className="block text-sm text-ink">
                Price
              </label>
              <input
                id="price"
                type="number"
                min="0"
                step="0.01"
                value={form.price}
                onChange={(event) => updateField("price", event.target.value)}
                aria-invalid={Boolean(errors.price)}
                className={fieldClassName(Boolean(errors.price))}
              />
              {errors.price && <p className="mt-1.5 text-sm text-error">{errors.price}</p>}
            </div>

            <div>
              <label htmlFor="stock_quantity" className="block text-sm text-ink">
                Stock quantity
              </label>
              <input
                id="stock_quantity"
                type="number"
                min="0"
                value={form.stock_quantity}
                onChange={(event) => updateField("stock_quantity", event.target.value)}
                aria-invalid={Boolean(errors.stock_quantity)}
                className={fieldClassName(Boolean(errors.stock_quantity))}
              />
              {errors.stock_quantity && <p className="mt-1.5 text-sm text-error">{errors.stock_quantity}</p>}
            </div>
          </div>

          <div>
            <label htmlFor="description" className="block text-sm text-ink">
              Description
            </label>
            <textarea
              id="description"
              rows={3}
              value={form.description}
              onChange={(event) => updateField("description", event.target.value)}
              className={fieldClassName(false)}
            />
          </div>

          <div>
            <label htmlFor="photo_urls" className="block text-sm text-ink">
              Photo URLs
            </label>
            <input
              id="photo_urls"
              type="text"
              placeholder="https://example.com/photo1.jpg, https://example.com/photo2.jpg"
              value={form.photo_urls}
              onChange={(event) => updateField("photo_urls", event.target.value)}
              className={fieldClassName(false)}
            />
            <p className="mt-1.5 text-xs text-ink-soft">Separate multiple URLs with commas.</p>
          </div>

          {formError && <p className="text-sm text-error">{formError}</p>}

          <Button type="submit" variant="accent" size="md" disabled={submitting} className="sm:w-auto">
            {submitting ? "Adding…" : "Add product"}
          </Button>
        </form>
      )}

      {loading ? (
        <p className="mt-8 text-[15px] text-ink-soft">Loading…</p>
      ) : error ? (
        <p className="mt-8 text-sm text-error">{error}</p>
      ) : products.length === 0 && !formOpen ? (
        <div className="mt-8">
          <EmptyState
            title="No products listed yet"
            description="Add your first product to start reaching customers."
          />
        </div>
      ) : products.length > 0 ? (
        <div className="mt-8 divide-y divide-border rounded-xl border border-border bg-surface">
          {products.map((product) => (
            <div key={product.id} className="flex flex-wrap items-center justify-between gap-4 px-5 py-4">
              <div>
                <p className="text-[15px] font-medium text-ink">{product.name}</p>
                <p className="text-sm capitalize text-ink-soft">
                  {product.category} · {product.stock_quantity} in stock
                </p>
              </div>
              <p className="text-[15px] font-medium text-accent">{formatPrice(product.price)}</p>
              <p className={`text-sm font-medium capitalize ${statusStyles[product.status] ?? "text-ink-soft"}`}>
                {product.status}
              </p>
              <div className="flex items-center gap-3">
                <Button type="button" variant="outline" size="sm" onClick={() => toggleAvailability(product)}>
                  {product.status === "available" ? "Mark unavailable" : "Mark available"}
                </Button>
                <Button type="button" variant="ghost" size="sm" onClick={() => deleteProduct(product.id)}>
                  Delete
                </Button>
              </div>
            </div>
          ))}
        </div>
      ) : null}
    </Container>
  );
}
