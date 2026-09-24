import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { formatPrice } from "../lib/format";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

function GiftForm({ product, session, onDone }) {
  const [recipientName, setRecipientName] = useState("");
  const [recipientContact, setRecipientContact] = useState("");
  const [message, setMessage] = useState("");
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");
  const [sent, setSent] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    const validationErrors = {};
    if (!recipientName.trim()) validationErrors.recipientName = "Enter the recipient's name.";
    if (!recipientContact.trim()) {
      validationErrors.recipientContact = "Enter a phone number or email for the recipient.";
    }
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const { data: order, error: orderError } = await supabase
        .from("orders")
        .insert({
          customer_id: session.user.id,
          order_type: "gift",
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

      const { error: giftError } = await supabase.from("gifts").insert({
        order_id: order.id,
        sender_id: session.user.id,
        recipient_name: recipientName.trim(),
        recipient_contact: recipientContact.trim(),
        message: message.trim() || null,
        delivery_status: "pending",
      });
      if (giftError) throw giftError;

      setSent(true);
    } catch (error) {
      setFormError(error.message || "Couldn't send that gift. Try again.");
    } finally {
      setSubmitting(false);
    }
  }

  if (sent) {
    return (
      <div className="mt-3 rounded-lg border border-border bg-paper p-3 text-sm text-trust">
        Gift order placed for {recipientName} — pick up and pay at the shop.
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      noValidate
      className="mt-3 flex flex-col gap-3 rounded-lg border border-border bg-paper p-3"
    >
      <div>
        <label htmlFor={`name-${product.id}`} className="block text-sm text-ink">
          Recipient name
        </label>
        <input
          id={`name-${product.id}`}
          type="text"
          value={recipientName}
          onChange={(event) => setRecipientName(event.target.value)}
          aria-invalid={Boolean(errors.recipientName)}
          className={fieldClassName(Boolean(errors.recipientName))}
        />
        {errors.recipientName && <p className="mt-1.5 text-sm text-error">{errors.recipientName}</p>}
      </div>

      <div>
        <label htmlFor={`contact-${product.id}`} className="block text-sm text-ink">
          Recipient phone or email
        </label>
        <input
          id={`contact-${product.id}`}
          type="text"
          value={recipientContact}
          onChange={(event) => setRecipientContact(event.target.value)}
          aria-invalid={Boolean(errors.recipientContact)}
          className={fieldClassName(Boolean(errors.recipientContact))}
        />
        {errors.recipientContact && (
          <p className="mt-1.5 text-sm text-error">{errors.recipientContact}</p>
        )}
      </div>

      <div>
        <label htmlFor={`message-${product.id}`} className="block text-sm text-ink">
          Message (optional)
        </label>
        <textarea
          id={`message-${product.id}`}
          rows={2}
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          className={fieldClassName(false)}
        />
      </div>

      {formError && <p className="text-sm text-error">{formError}</p>}

      <div className="flex gap-2">
        <Button type="submit" variant="accent" size="sm" disabled={submitting}>
          {submitting ? "Sending…" : "Send gift"}
        </Button>
        <Button type="button" variant="ghost" size="sm" onClick={onDone}>
          Cancel
        </Button>
      </div>
    </form>
  );
}

export function Gifting() {
  const session = useAuthStore((state) => state.session);
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [activeProductId, setActiveProductId] = useState(null);

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

  if (loading) {
    return (
      <Container className="py-16">
        <p className="text-ink-soft">Loading…</p>
      </Container>
    );
  }

  return (
    <Container className="py-10 lg:py-12">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Send a gift</h1>
      <p className="mt-2 text-[15px] text-ink-soft">
        Pick something from the store and send it to someone else — they pick it up at the shop.
      </p>

      {error && <p className="mt-6 text-sm text-error">{error}</p>}

      {products.length > 0 ? (
        <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {products.map((product) => (
            <div key={product.id} className="rounded-xl border border-border bg-surface p-4">
              <p className="text-xs capitalize text-ink-soft">{product.category}</p>
              <h3 className="mt-1 text-[15px] font-medium text-ink">{product.name}</h3>
              <p className="mt-1 truncate text-sm text-ink-soft">{product.shops?.name}</p>
              <p className="mt-2 font-display text-lg font-semibold text-accent">
                {formatPrice(product.price)}
              </p>

              {activeProductId === product.id ? (
                session ? (
                  <GiftForm product={product} session={session} onDone={() => setActiveProductId(null)} />
                ) : (
                  <div className="mt-3 rounded-lg border border-border bg-paper p-3 text-sm text-ink-soft">
                    <Link to="/login" className="text-primary hover:underline">
                      Log in
                    </Link>{" "}
                    to send this as a gift.
                  </div>
                )
              ) : (
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-3 w-full"
                  onClick={() => setActiveProductId(product.id)}
                >
                  Send as gift
                </Button>
              )}
            </div>
          ))}
        </div>
      ) : (
        <EmptyState title="No products available to gift right now" />
      )}
    </Container>
  );
}
