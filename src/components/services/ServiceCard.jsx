import { Clock } from "@phosphor-icons/react";
import { useState } from "react";
import { formatPrice } from "../../lib/format";
import { Button } from "../ui/Button";
import { categoryMeta, formatDuration } from "./serviceCategories";

function ServicePhoto({ src, category, alt }) {
  const [failed, setFailed] = useState(false);
  const Icon = categoryMeta(category).icon;

  if (!src || failed) {
    return (
      <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-primary/10 via-secondary/10 to-tertiary/10 text-primary">
        <Icon size={44} weight="duotone" aria-hidden="true" />
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      loading="lazy"
      onError={() => setFailed(true)}
      className="h-full w-full object-cover"
    />
  );
}

/** One bookable service. Shop name only — never an address or phone number. */
export function ServiceCard({ service, onBook }) {
  const { icon: CategoryIcon, label } = categoryMeta(service.category);
  const duration = formatDuration(service.duration_minutes);

  return (
    <article className="flex flex-col overflow-hidden rounded-xl border border-border bg-surface transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]">
      <div className="aspect-[16/9] overflow-hidden">
        <ServicePhoto src={service.photo_urls?.[0]} category={service.category} alt={service.name} />
      </div>

      <div className="flex flex-1 flex-col p-4">
        <p className="flex items-center gap-1.5 text-xs text-ink-soft">
          <CategoryIcon size={14} aria-hidden="true" /> {label}
        </p>
        <h3 className="mt-1 text-[15px] font-medium text-ink">{service.name}</h3>
        {service.shops?.name && <p className="mt-0.5 truncate text-sm text-ink-soft">by {service.shops.name}</p>}
        {service.description && <p className="mt-2 line-clamp-2 text-sm text-ink-soft">{service.description}</p>}

        <div className="mt-auto flex items-end justify-between gap-3 pt-4">
          <div>
            <p className="font-display text-lg font-semibold text-accent">{formatPrice(service.price)}</p>
            {duration && (
              <p className="flex items-center gap-1 text-xs text-ink-soft">
                <Clock size={14} aria-hidden="true" /> {duration}
              </p>
            )}
          </div>
          <Button size="sm" onClick={() => onBook(service)} aria-label={`Book now: ${service.name}`}>
            Book now
          </Button>
        </div>
      </div>
    </article>
  );
}
