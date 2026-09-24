import { Star, StarHalf } from "@phosphor-icons/react";

/** Always shows something — "New shop" text when there are no reviews yet, per spec. */
export function RatingStars({ rating, reviewCount, size = 15, className = "" }) {
  if (!reviewCount) {
    return <span className={`text-sm text-ink-soft ${className}`}>New shop</span>;
  }

  const full = Math.floor(rating);
  const hasHalf = rating - full >= 0.25 && rating - full < 0.75;
  const roundedFull = hasHalf ? full : Math.round(rating);

  return (
    <span className={`inline-flex items-center gap-1.5 text-sm ${className}`}>
      <span className="inline-flex items-center text-trust">
        {Array.from({ length: 5 }).map((_, index) => {
          if (index < roundedFull) return <Star key={index} size={size} weight="fill" />;
          if (index === roundedFull && hasHalf) return <StarHalf key={index} size={size} weight="fill" />;
          return <Star key={index} size={size} weight="regular" className="opacity-30" />;
        })}
      </span>
      <span className="text-ink-soft">
        {rating.toFixed(1)} ({reviewCount})
      </span>
    </span>
  );
}
