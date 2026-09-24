import { Check, CheckCircle, CreditCard, DeviceMobile } from "@phosphor-icons/react";
import { useState } from "react";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { PetPhoto } from "../components/ui/PetPhoto";
import { getPetById } from "../data/pets";
import { getShopById } from "../data/shops";
import { formatOrderDate, formatPrice } from "../lib/format";
import { useCartStore } from "../store/cartStore";

const STEPS = [
  { id: 1, label: "Details" },
  { id: 2, label: "Payment" },
  { id: 3, label: "Review" },
];

function validateBuyer(buyer) {
  const errors = {};
  if (!buyer.name.trim()) errors.name = "Enter your name.";
  if (!buyer.email.trim()) errors.email = "Enter an email address.";
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(buyer.email.trim())) {
    errors.email = "Enter a valid email address.";
  }
  if (!buyer.phone.trim()) errors.phone = "Enter a phone number.";
  else if (!/^[\d\s()+-]{7,}$/.test(buyer.phone.trim())) errors.phone = "Enter a valid phone number.";
  return errors;
}

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

function Stepper({ current }) {
  return (
    <ol className="flex items-center gap-3">
      {STEPS.map((step, index) => (
        <li key={step.id} className="flex items-center gap-3">
          <span
            className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-medium ${
              step.id < current
                ? "bg-trust text-white"
                : step.id === current
                  ? "bg-primary text-white"
                  : "bg-border/50 text-ink-soft"
            }`}
          >
            {step.id < current ? <Check size={16} weight="bold" /> : step.id}
          </span>
          <span className={`text-sm ${step.id === current ? "font-medium text-ink" : "text-ink-soft"}`}>
            {step.label}
          </span>
          {index < STEPS.length - 1 && <span className="mx-1 h-px w-8 bg-border sm:w-16" />}
        </li>
      ))}
    </ol>
  );
}

/**
 * A pet's shop is fixed, never a buyer choice — "pickup shop confirmation
 * per item" means showing which shop each item comes from, not letting the
 * buyer pick one.
 */
function PickupList({ items }) {
  return (
    <ul className="mt-4 divide-y divide-border rounded-xl border border-border">
      {items.map((pet) => {
        const shop = getShopById(pet.shopId);
        return (
          <li key={pet.id} className="flex items-center gap-3 p-3">
            <div className="h-12 w-12 flex-none overflow-hidden rounded-lg">
              <PetPhoto src={pet.photos?.[0]} species={pet.species} alt="" className="h-full w-full" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-ink">{pet.name}</p>
              <p className="truncate text-xs text-ink-soft">Pickup at {shop?.name}</p>
            </div>
            <p className="flex-none text-sm font-semibold text-accent">{formatPrice(pet.price)}</p>
          </li>
        );
      })}
    </ul>
  );
}

export function Checkout() {
  const itemIds = useCartStore((state) => state.items);
  const clearCart = useCartStore((state) => state.clearCart);
  const items = itemIds.map((id) => getPetById(id)).filter(Boolean);
  const subtotal = items.reduce((sum, pet) => sum + pet.price, 0);

  const [step, setStep] = useState(1);
  const [buyer, setBuyer] = useState({ name: "", email: "", phone: "" });
  const [errors, setErrors] = useState({});
  const [paymentMethod, setPaymentMethod] = useState("card");
  const [order, setOrder] = useState(null);

  function updateBuyerField(field, value) {
    setBuyer((prev) => ({ ...prev, [field]: value }));
  }

  function handleContinueFromDetails() {
    const validationErrors = validateBuyer(buyer);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;
    setStep(2);
  }

  function handlePlaceOrder() {
    // No network call: the "order" is just a local snapshot for the
    // confirmation screen, created before clearCart() empties the cart.
    setOrder({
      id: `PN-${Date.now().toString(36).toUpperCase()}`,
      items,
      subtotal,
      buyer,
      paymentMethod,
      placedAt: new Date().toISOString(),
    });
    clearCart();
    setStep("confirmed");
  }

  if (step !== "confirmed" && items.length === 0) {
    return (
      <Container className="py-20">
        <EmptyState
          title="Your cart is empty"
          description="Add a pet to your cart before checking out."
          action={
            <Button to="/pets" size="sm">
              Shop pets
            </Button>
          }
        />
      </Container>
    );
  }

  if (step === "confirmed" && order) {
    return (
      <Container className="py-16">
        <div className="mx-auto max-w-xl text-center">
          <CheckCircle size={48} weight="fill" className="mx-auto text-trust" />
          <h1 className="mt-5 font-display text-3xl font-bold text-ink">Order placed</h1>
          <p className="mt-3 text-[15px] text-ink-soft">
            Order <span className="font-medium text-ink">#{order.id}</span> is placed and pending pickup.
            No payment has been charged — you'll pay in person when you collect each pet from its shop.
          </p>

          <div className="mt-8 rounded-xl border border-border bg-surface p-6 text-left">
            <div className="flex items-center justify-between text-sm">
              <span className="text-ink-soft">Placed</span>
              <span className="text-ink">{formatOrderDate(order.placedAt)}</span>
            </div>
            <div className="mt-2 flex items-center justify-between text-sm">
              <span className="text-ink-soft">Confirmation sent to</span>
              <span className="text-ink">{order.buyer.email}</span>
            </div>
            <div className="mt-4 border-t border-border pt-4">
              <PickupList items={order.items} />
            </div>
            <div className="mt-4 flex items-center justify-between border-t border-border pt-4 text-[15px]">
              <span className="text-ink-soft">Amount due at pickup</span>
              <span className="font-display font-semibold text-ink">{formatPrice(order.subtotal)}</span>
            </div>
          </div>

          <Button to="/pets" className="mt-8">
            Continue shopping
          </Button>
        </div>
      </Container>
    );
  }

  return (
    <Container className="py-10 lg:py-12">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Checkout</h1>
      <div className="mt-6 overflow-x-auto">
        <Stepper current={step} />
      </div>

      <div className="mt-8 grid gap-10 lg:grid-cols-[1fr_360px] lg:gap-14">
        <div className="max-w-xl">
          {step === 1 && (
            <div>
              <h2 className="font-display text-lg font-semibold text-ink">Your details</h2>
              <p className="mt-1 text-sm text-ink-soft">
                No shipping address needed — these pets don't ship. You'll pick each one up in person.
              </p>

              <div className="mt-5 flex flex-col gap-5">
                <div>
                  <label htmlFor="buyerName" className="block text-sm text-ink">
                    Full name
                  </label>
                  <input
                    id="buyerName"
                    type="text"
                    autoComplete="name"
                    value={buyer.name}
                    onChange={(event) => updateBuyerField("name", event.target.value)}
                    aria-invalid={Boolean(errors.name)}
                    className={fieldClassName(Boolean(errors.name))}
                  />
                  {errors.name && <p className="mt-1.5 text-sm text-error">{errors.name}</p>}
                </div>
                <div>
                  <label htmlFor="buyerEmail" className="block text-sm text-ink">
                    Email address
                  </label>
                  <input
                    id="buyerEmail"
                    type="email"
                    autoComplete="email"
                    value={buyer.email}
                    onChange={(event) => updateBuyerField("email", event.target.value)}
                    aria-invalid={Boolean(errors.email)}
                    className={fieldClassName(Boolean(errors.email))}
                  />
                  {errors.email && <p className="mt-1.5 text-sm text-error">{errors.email}</p>}
                </div>
                <div>
                  <label htmlFor="buyerPhone" className="block text-sm text-ink">
                    Phone number
                  </label>
                  <input
                    id="buyerPhone"
                    type="tel"
                    autoComplete="tel"
                    value={buyer.phone}
                    onChange={(event) => updateBuyerField("phone", event.target.value)}
                    aria-invalid={Boolean(errors.phone)}
                    className={fieldClassName(Boolean(errors.phone))}
                  />
                  {errors.phone && <p className="mt-1.5 text-sm text-error">{errors.phone}</p>}
                </div>
              </div>

              <h2 className="mt-8 font-display text-lg font-semibold text-ink">Pickup by shop</h2>
              <PickupList items={items} />

              <Button variant="accent" size="lg" onClick={handleContinueFromDetails} className="mt-6 w-full">
                Continue to payment
              </Button>
            </div>
          )}

          {step === 2 && (
            <div>
              <h2 className="font-display text-lg font-semibold text-ink">Payment method</h2>
              <p className="mt-1 text-sm text-ink-soft">
                Choose how you'll pay at pickup. Nothing is charged now, and no payment details are
                collected on this site.
              </p>

              <div className="mt-5 flex flex-col gap-3">
                {[
                  { value: "card", label: "Card", icon: CreditCard },
                  { value: "upi", label: "UPI", icon: DeviceMobile },
                ].map((option) => (
                  <label
                    key={option.value}
                    className={`flex cursor-pointer items-center gap-3 rounded-lg border px-4 py-3.5 transition-colors ${
                      paymentMethod === option.value ? "border-primary bg-primary/5" : "border-border"
                    }`}
                  >
                    <input
                      type="radio"
                      name="paymentMethod"
                      value={option.value}
                      checked={paymentMethod === option.value}
                      onChange={() => setPaymentMethod(option.value)}
                      className="h-4 w-4 accent-primary"
                    />
                    <option.icon size={20} className="text-ink-soft" />
                    <span className="text-[15px] text-ink">{option.label}</span>
                  </label>
                ))}
              </div>

              <div className="mt-6 flex gap-3">
                <Button variant="outline" size="lg" onClick={() => setStep(1)}>
                  Back
                </Button>
                <Button variant="accent" size="lg" onClick={() => setStep(3)} className="flex-1">
                  Continue to review
                </Button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <h2 className="font-display text-lg font-semibold text-ink">Review your order</h2>

              <div className="mt-4 rounded-xl border border-border bg-surface p-5">
                <p className="text-sm font-medium text-ink">Buyer</p>
                <p className="mt-1 text-sm text-ink-soft">
                  {buyer.name} · {buyer.email} · {buyer.phone}
                </p>
              </div>

              <div className="mt-4 rounded-xl border border-border bg-surface p-5">
                <p className="text-sm font-medium text-ink">Payment method</p>
                <p className="mt-1 text-sm text-ink-soft">
                  {paymentMethod === "card" ? "Card" : "UPI"} — paid in person at pickup, not charged here.
                </p>
              </div>

              <h3 className="mt-6 text-sm font-medium text-ink">Items</h3>
              <PickupList items={items} />

              <div className="mt-4 flex gap-3">
                <Button variant="outline" size="lg" onClick={() => setStep(2)}>
                  Back
                </Button>
                <Button variant="accent" size="lg" onClick={handlePlaceOrder} className="flex-1">
                  Place order
                </Button>
              </div>
            </div>
          )}
        </div>

        <div className="h-fit rounded-xl border border-border bg-surface p-5">
          <h2 className="font-display text-base font-semibold text-ink">Order summary</h2>
          <ul className="mt-3 divide-y divide-border">
            {items.map((pet) => (
              <li key={pet.id} className="flex items-center justify-between gap-3 py-2.5 text-sm">
                <span className="truncate text-ink">{pet.name}</span>
                <span className="flex-none font-medium text-ink">{formatPrice(pet.price)}</span>
              </li>
            ))}
          </ul>
          <div className="mt-3 flex items-center justify-between border-t border-border pt-3 text-[15px]">
            <span className="text-ink-soft">Subtotal</span>
            <span className="font-display font-semibold text-ink">{formatPrice(subtotal)}</span>
          </div>
          <p className="mt-2 text-xs text-ink-soft">Due at pickup — nothing is charged online.</p>
        </div>
      </div>
    </Container>
  );
}
