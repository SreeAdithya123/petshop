import {
  Bathtub,
  Bed,
  GraduationCap,
  PawPrint,
  PersonSimpleWalk,
  Phone,
  Scissors,
  Sparkle,
  Stethoscope,
  Storefront,
  Sun,
  VideoCamera,
} from "@phosphor-icons/react";
import { toDateInputValue } from "../../lib/format";

export const SERVICE_CATEGORIES = [
  { value: "vet", label: "Vet", icon: Stethoscope },
  { value: "grooming", label: "Grooming", icon: Sparkle },
  { value: "trimming", label: "Trimming", icon: Scissors },
  { value: "bathing", label: "Bathing", icon: Bathtub },
  { value: "training", label: "Training", icon: GraduationCap },
  { value: "walking", label: "Walking", icon: PersonSimpleWalk },
  { value: "daycare", label: "Daycare", icon: Sun },
  { value: "boarding", label: "Boarding", icon: Bed },
];

export const OTHER_CATEGORY = { value: "other", label: "Other", icon: PawPrint };

/** Label + icon for a services.category value; unknown values still render. */
export function categoryMeta(value) {
  return (
    SERVICE_CATEGORIES.find((category) => category.value === value) ?? {
      ...OTHER_CATEGORY,
      value,
      label: value ? value.charAt(0).toUpperCase() + value.slice(1) : OTHER_CATEGORY.label,
    }
  );
}

export const DELIVERY_MODES = {
  in_person: { label: "In person", icon: Storefront },
  video: { label: "Video call", icon: VideoCamera },
  phone: { label: "Phone call", icon: Phone },
};

/** Only vet services can be delivered remotely. */
export function modesForCategory(category) {
  return category === "vet" ? ["in_person", "video", "phone"] : ["in_person"];
}

export const PET_SPECIES_OPTIONS = ["Dog", "Cat", "Bird", "Rabbit", "Small pet", "Other"];

// 09:00 through 18:00 in 30 minute steps, as 'HH:MM'.
export const TIME_SLOTS = Array.from({ length: 19 }, (_, index) => {
  const minutes = 9 * 60 + index * 30;
  const hours = String(Math.floor(minutes / 60)).padStart(2, "0");
  return `${hours}:${String(minutes % 60).padStart(2, "0")}`;
});

/** "09:30" or "09:30:00" -> "9:30 AM". */
export function formatTime(value) {
  if (!value) return "";
  const [hours, minutes] = value.split(":").map(Number);
  const suffix = hours >= 12 ? "PM" : "AM";
  return `${hours % 12 || 12}:${String(minutes).padStart(2, "0")} ${suffix}`;
}

/** 45 -> "45 min", 90 -> "1 hr 30 min". */
export function formatDuration(totalMinutes) {
  const minutes = Number(totalMinutes);
  if (!minutes) return "";
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest ? `${hours} hr ${rest} min` : `${hours} hr`;
}

export function tomorrowInputValue() {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  return toDateInputValue(tomorrow);
}

/** Video links are typed in by the clinic; only ever link to http(s) URLs. */
export function safeExternalUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:" ? url.href : null;
  } catch {
    return null;
  }
}
