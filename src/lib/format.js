const currencyFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 0,
});

export function formatPrice(amount) {
  return currencyFormatter.format(amount);
}

/** Avoids a double period when a sentence ends right after a name like "...Pet Co." */
export function withPeriod(text) {
  if (!text) return text;
  return /[.!?]$/.test(text.trim()) ? text : `${text}.`;
}

const orderDateFormatter = new Intl.DateTimeFormat("en-US", {
  weekday: "short",
  month: "short",
  day: "numeric",
  hour: "numeric",
  minute: "2-digit",
});

export function formatOrderDate(isoString) {
  return orderDateFormatter.format(new Date(isoString));
}
