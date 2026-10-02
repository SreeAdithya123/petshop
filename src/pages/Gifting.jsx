import { useEffect, useState } from "react";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { Field } from "../components/ui/FormField";
import { LoginPrompt } from "../components/ui/LoginPrompt";
import { PRODUCT_PUBLIC_COLUMNS } from "../lib/columns";
import { formatPrice } from "../lib/format";
import { fieldClassName } from "../lib/styles";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";

const GRID_CLASS = "mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3";

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
        Gift order placed for {recipientName} — the shop will confirm pickup details with you.
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      noValidate
      className="mt-3 flex flex-col gap-3 rounded-lg border border-border bg-paper p-3"
    >
      <Field label="Recipient name" htmlFor={`name-${product.id}`} error={errors.recipientName}>
        <input
          id={`name-${product.id}`}
          type="text"
          value={recipientName}
          onChange={(event) => setRecipientName(event.target.value)}
          aria-invalid={Boolean(errors.recipientName)}
          className={fieldClassName(Boolean(errors.recipientName))}
        />
      </Field>

      <Field label="Recipient phone or email" htmlFor={`contact-${product.id}`} error={errors.recipientContact}>
        <input
          id={`contact-${product.id}`}
          type="text"
          value={recipientContact}
          onChange={(event) => setRecipientContact(event.target.value)}
          aria-invalid={Boolean(errors.recipientContact)}
          className={fieldClassName(Boolean(errors.recipientContact))}
        />
      </Field>

      <Field label="Message" htmlFor={`message-${product.id}`} optional>
        <textarea
          id={`message-${product.id}`}
          rows={2}
          value={message}
          onChange={(event) => setMessage(event.target.value)}
          className={fieldClassName(false)}
        />
      </Field>

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

function GiftCardSkeleton() {
  return (
    <div aria-hidden="true" className="animate-pulse rounded-xl border border-border bg-surface p-4">
      <div className="h-3 w-1/4 rounded bg-border/50" />
      <div className="mt-2 h-4 w-3/4 rounded bg-border/50" />
      <div className="mt-2 h-3.5 w-1/2 rounded bg-border/50" />
      <div className="mt-3 h-5 w-1/3 rounded bg-border/50" />
      <div className="mt-3 h-9 rounded-lg bg-border/50" />
    </div>
  );
}

export function Gifting() {
  const session = useAuthStore((state) => state.session);
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);
  const [activeProductId, setActiveProductId] = useState(null);

  useEffect(() => {
    let cancelled = false;
    async function loadProducts() {
      setLoading(true);
      setError("");
      const { data, error: queryError } = await supabase
        .from("products")
        .select(`${PRODUCT_PUBLIC_COLUMNS}, shops(name)`)
        .eq("status", "available");
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

  return (
    <Container className="py-10 lg:py-12">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Send a gift</h1>
      <p className="mt-2 text-[15px] text-ink-soft">
        Pick something from the store and send it to someone else — they pick it up at the shop.
      </p>

      {loading ? (
        <div className={GRID_CLASS} role="status" aria-label="Loading products">
          {Array.from({ length: 6 }).map((_, index) => (
            <GiftCardSkeleton key={index} />
          ))}
        </div>
      ) : error ? (
        <EmptyState
          title="We couldn't load gift ideas"
          description={error}
          action={
            <Button size="sm" onClick={() => setAttempt((count) => count + 1)}>
              Try again
            </Button>
          }
        />
      ) : products.length > 0 ? (
        <div className={GRID_CLASS}>
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
                  <div className="mt-3 rounded-lg border border-border bg-paper p-3">
                    <LoginPrompt compact description="to send this as a gift." />
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
