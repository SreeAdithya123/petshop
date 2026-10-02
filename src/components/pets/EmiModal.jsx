import { Info, ShoppingCartSimple } from "@phosphor-icons/react";
import { useState } from "react";
import { formatPrice } from "../../lib/format";
import { useCartStore } from "../../store/cartStore";
import { Button } from "../ui/Button";
import { Field } from "../ui/FormField";
import { Modal } from "../ui/Modal";

// Indicative annual interest rates (%) per tenure. Illustration only — real
// terms come from the shop / the customer's lender.
const EMI_PLANS = [
  { months: 3, annualRate: 0 },
  { months: 6, annualRate: 12 },
  { months: 9, annualRate: 13 },
  { months: 12, annualRate: 14 },
];

const DEFAULT_MONTHS = 6;
const MAX_DOWN_PAYMENT_PERCENT = 50;

function rateLabel(plan) {
  return plan.annualRate === 0 ? "No-cost EMI" : `${plan.annualRate}% p.a.`;
}

/** Standard reducing-balance EMI; every figure is rounded to the rupee. */
function calculatePlan(price, downPayment, { months, annualRate }) {
  const loan = price - downPayment;
  const monthlyRate = annualRate / 12 / 100;

  let emi = 0;
  if (loan > 0) {
    emi =
      monthlyRate === 0
        ? loan / months
        : (loan * monthlyRate * (1 + monthlyRate) ** months) / ((1 + monthlyRate) ** months - 1);
  }
  const interest = loan > 0 ? emi * months - loan : 0;

  return {
    emi: Math.round(emi),
    interest: Math.max(0, Math.round(interest)),
    total: Math.round(price + Math.max(0, interest)),
  };
}

export function EmiModal({ open, onClose, pet }) {
  const [months, setMonths] = useState(DEFAULT_MONTHS);
  const [downPercent, setDownPercent] = useState(0);

  const inCart = useCartStore((state) => (pet ? state.items.includes(pet.id) : false));
  const addToCart = useCartStore((state) => state.addToCart);
  const openDrawer = useCartStore((state) => state.openDrawer);

  if (!pet) return null;

  const price = Number(pet.price) || 0;
  const downPayment = Math.round((price * downPercent) / 100);
  const plans = EMI_PLANS.map((plan) => ({ ...plan, ...calculatePlan(price, downPayment, plan) }));
  const selected = plans.find((plan) => plan.months === months) ?? plans[0];

  function handleClose() {
    setMonths(DEFAULT_MONTHS);
    setDownPercent(0);
    onClose();
  }

  function handleCartClick() {
    if (inCart) openDrawer();
    else addToCart(pet.id);
    handleClose();
  }

  return (
    <Modal
      open={open}
      onClose={handleClose}
      title="EMI options"
      description={`${pet.name} · ${formatPrice(price)}`}
      maxWidth="max-w-xl"
    >
      <div className="space-y-5">
        <div className="flex gap-2.5 rounded-lg border border-warning/50 bg-warning/10 p-3 text-sm text-ink">
          <Info size={18} weight="fill" className="mt-0.5 flex-none text-amber-700" />
          <p>
            <strong className="font-semibold">Indicative figures for illustration only.</strong> PETSTA shops take
            payment in person; EMI availability and final terms depend on the shop and your lender.
          </p>
        </div>

        <fieldset className="min-w-0">
          <legend className="text-sm text-ink">Tenure</legend>
          <div className="mt-1.5 grid grid-cols-4 gap-2">
            {plans.map((plan) => (
              <label
                key={plan.months}
                className="cursor-pointer rounded-lg border border-border px-1.5 py-2.5 text-center transition-colors has-[:checked]:border-primary has-[:checked]:bg-primary/5 has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-primary/40"
              >
                <input
                  type="radio"
                  name="emi-tenure"
                  value={plan.months}
                  checked={plan.months === months}
                  onChange={() => setMonths(plan.months)}
                  className="sr-only"
                />
                <span className="block text-sm font-medium text-ink">{plan.months} months</span>
                <span className="mt-0.5 block text-xs leading-tight text-ink-soft">{rateLabel(plan)}</span>
              </label>
            ))}
          </div>
        </fieldset>

        <Field
          label={`Down payment: ${downPercent}% (${formatPrice(downPayment)})`}
          htmlFor="emi-down-payment"
          hint={`Optional — up to ${MAX_DOWN_PAYMENT_PERCENT}% of the price.`}
        >
          <input
            id="emi-down-payment"
            type="range"
            min={0}
            max={MAX_DOWN_PAYMENT_PERCENT}
            step={5}
            value={downPercent}
            onChange={(event) => setDownPercent(Number(event.target.value))}
            className="mt-3 w-full accent-primary"
          />
        </Field>

        <div className="rounded-xl border border-primary bg-primary/5 p-4" aria-live="polite">
          <p className="text-xs uppercase tracking-wide text-ink-soft">
            Your plan · {selected.months} months · {rateLabel(selected)}
          </p>
          <p className="mt-1 font-display text-3xl font-bold text-ink">
            {formatPrice(selected.emi)} <span className="text-base font-medium text-ink-soft">/ month</span>
          </p>
          <dl className="mt-3 grid grid-cols-3 gap-3 text-sm">
            <div>
              <dt className="text-xs text-ink-soft">Down payment</dt>
              <dd className="mt-0.5 font-medium text-ink">{formatPrice(downPayment)}</dd>
            </div>
            <div>
              <dt className="text-xs text-ink-soft">Total interest</dt>
              <dd className="mt-0.5 font-medium text-ink">{formatPrice(selected.interest)}</dd>
            </div>
            <div>
              <dt className="text-xs text-ink-soft">Total payable</dt>
              <dd className="mt-0.5 font-medium text-ink">{formatPrice(selected.total)}</dd>
            </div>
          </dl>
        </div>

        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full min-w-[20rem] text-left text-sm">
            <caption className="sr-only">EMI comparison across all tenures</caption>
            <thead className="bg-paper text-xs text-ink-soft">
              <tr>
                <th scope="col" className="px-3 py-2 font-medium">
                  Tenure
                </th>
                <th scope="col" className="px-3 py-2 font-medium">
                  Monthly EMI
                </th>
                <th scope="col" className="px-3 py-2 font-medium">
                  Interest
                </th>
                <th scope="col" className="px-3 py-2 font-medium">
                  Total
                </th>
              </tr>
            </thead>
            <tbody>
              {plans.map((plan) => {
                const isSelected = plan.months === selected.months;
                return (
                  <tr
                    key={plan.months}
                    aria-current={isSelected ? "true" : undefined}
                    className={`border-t border-border ${isSelected ? "bg-primary/5 font-medium text-ink" : "text-ink-soft"}`}
                  >
                    <th scope="row" className="px-3 py-2.5 font-medium text-ink">
                      {plan.months} months
                      <span className="block text-xs font-normal text-ink-soft">{rateLabel(plan)}</span>
                    </th>
                    <td className="px-3 py-2.5">{formatPrice(plan.emi)}</td>
                    <td className="px-3 py-2.5">{formatPrice(plan.interest)}</td>
                    <td className="px-3 py-2.5">{formatPrice(plan.total)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <p className="text-xs text-ink-soft">
          This is a calculator only. No payment is taken and nothing you enter here is saved.
        </p>

        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button variant="outline" onClick={handleClose}>
            Close
          </Button>
          <Button variant={inCart ? "primary" : "accent"} onClick={handleCartClick}>
            <ShoppingCartSimple size={18} /> {inCart ? "View cart" : "Add to cart"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
