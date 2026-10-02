const currencyFormatter = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});

export function formatPrice(amount) {
  return currencyFormatter.format(Number(amount) || 0);
}

/** Avoids a double period when a sentence ends right after a name like "...Pet Co." */
export function withPeriod(text) {
  if (!text) return text;
  return /[.!?]$/.test(text.trim()) ? text : `${text}.`;
}

const orderDateFormatter = new Intl.DateTimeFormat("en-IN", {
  weekday: "short",
  month: "short",
  day: "numeric",
  hour: "numeric",
  minute: "2-digit",
});

export function formatOrderDate(isoString) {
  return orderDateFormatter.format(new Date(isoString));
}

const shortDateFormatter = new Intl.DateTimeFormat("en-IN", {
  day: "numeric",
  month: "short",
  year: "numeric",
});

/** Accepts a date-only string ("2026-10-05") or a full ISO timestamp. */
export function formatDate(value) {
  if (!value) return "";
  const date = /^\d{4}-\d{2}-\d{2}$/.test(value) ? new Date(`${value}T00:00:00`) : new Date(value);
  return shortDateFormatter.format(date);
}

/** "2026-10-05" for <input type="date"> min/value attributes, in local time. */
export function toDateInputValue(date = new Date()) {
  const offset = date.getTimezoneOffset() * 60000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 10);
}
