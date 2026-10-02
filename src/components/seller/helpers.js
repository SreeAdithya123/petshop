import { formatDate } from "../../lib/format";

export const SERVICE_CATEGORIES = [
  { value: "vet", label: "Vet" },
  { value: "grooming", label: "Grooming" },
  { value: "training", label: "Training" },
  { value: "walking", label: "Walking" },
  { value: "daycare", label: "Daycare" },
  { value: "boarding", label: "Boarding" },
  { value: "trimming", label: "Trimming" },
  { value: "bathing", label: "Bathing" },
];

const CATEGORY_LABELS = Object.fromEntries(SERVICE_CATEGORIES.map((category) => [category.value, category.label]));

export function categoryLabel(value) {
  if (!value) return "";
  return CATEGORY_LABELS[value] ?? value;
}

const MODE_LABELS = { in_person: "In person", video: "Video call", phone: "Phone call" };

export function modeLabel(mode) {
  return MODE_LABELS[mode] ?? mode ?? "";
}

/** 90 -> "1 hr 30 min"; empty when no duration is set. */
export function formatDuration(minutes) {
  const total = Number(minutes);
  if (!total) return "";
  const hours = Math.floor(total / 60);
  const rest = total % 60;
  if (!hours) return `${rest} min`;
  return rest ? `${hours} hr ${rest} min` : `${hours} hr`;
}

const CLOCK_TIME = /^(\d{1,2}):(\d{2})(?::\d{2})?$/;

/** "14:30" or "14:30:00" -> "2:30 PM". Anything else (e.g. "Morning") is shown as written. */
export function formatTime(value) {
  if (!value) return "";
  const text = String(value).trim();
  const match = CLOCK_TIME.exec(text);
  if (!match) return text;
  const hours = Number(match[1]);
  return `${hours % 12 || 12}:${match[2]} ${hours >= 12 ? "PM" : "AM"}`;
}

/** "14:30:00" -> "14:30" for <input type="time">; empty when it isn't a clock time. */
export function toTimeInputValue(value) {
  const match = CLOCK_TIME.exec(String(value ?? "").trim());
  return match ? `${match[1].padStart(2, "0")}:${match[2]}` : "";
}

/** "5 Oct 2026 at 2:30 PM", dropping whichever half is missing. */
export function formatSlot(date, time) {
  return [formatDate(date), formatTime(time)].filter(Boolean).join(" at ");
}

export function isHttpsUrl(value) {
  try {
    const url = new URL(String(value).trim());
    return url.protocol === "https:" && Boolean(url.hostname);
  } catch {
    return false;
  }
}

/** "#1a2b3c4d": the first 8 characters of an order uuid. */
export function shortOrderId(id) {
  return `#${String(id ?? "").slice(0, 8)}`;
}

export function countByStatus(rows) {
  const counts = {};
  rows.forEach((row) => {
    counts[row.status] = (counts[row.status] ?? 0) + 1;
  });
  return counts;
}

/** Filter-chip options with a count each; "all" counts every row. */
export function withCounts(filters, rows) {
  const counts = countByStatus(rows);
  return filters.map((filter) => ({
    ...filter,
    count:
      filter.value === "all"
        ? rows.length
        : (filter.statuses ?? [filter.value]).reduce((sum, status) => sum + (counts[status] ?? 0), 0),
  }));
}

/** Rows matching a chip: "all", or any of the chip's statuses. */
export function applyFilter(filters, value, rows) {
  if (value === "all") return rows;
  const filter = filters.find((candidate) => candidate.value === value);
  const statuses = filter?.statuses ?? [value];
  return rows.filter((row) => statuses.includes(row.status));
}
