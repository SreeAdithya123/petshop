/**
 * Hand-illustrated flat species icons. Used as the card image for species
 * without a reliable breed-photo API (Rabbit, Bird, Small Pet), and as the
 * universal fallback when any pet photo fails to load — see
 * /docs/decisions.md for the image-sourcing approach.
 *
 * Single family: a soft primary-tinted circle behind a flat navy silhouette,
 * differentiated only by shape. Deliberately monochrome — accent orange is
 * reserved for CTAs/price/active state only, so it never appears here.
 */

const shapes = {
  Dog: (
    <>
      <path
        d="M32 58c0-14 8-24 18-24s18 10 18 24-8 16-18 16-18-2-18-16Z"
        fill="var(--primary)"
      />
      <path d="M30 30c-6-2-10-9-8-14 6 0 12 5 13 11l-5 3Z" fill="var(--primary)" />
      <path d="M70 30c6-2 10-9 8-14-6 0-12 5-13 11l5 3Z" fill="var(--primary)" />
      <circle cx="43" cy="48" r="3" fill="var(--paper)" />
      <circle cx="57" cy="48" r="3" fill="var(--paper)" />
      <ellipse cx="50" cy="58" rx="5" ry="3.5" fill="var(--paper)" />
    </>
  ),
  Cat: (
    <>
      <path d="M50 34 34 62h32L50 34Z" fill="var(--primary)" opacity="0" />
      <path d="M28 24 40 42h20L72 24 64 46c8 3 12 10 12 18 0 12-11 18-26 18s-26-6-26-18c0-8 4-15 12-18L28 24Z" fill="var(--primary)" />
      <circle cx="42" cy="56" r="3" fill="var(--paper)" />
      <circle cx="58" cy="56" r="3" fill="var(--paper)" />
      <path d="M46 64h8l-4 4-4-4Z" fill="var(--paper)" />
    </>
  ),
  Bird: (
    <>
      <ellipse cx="46" cy="54" rx="22" ry="18" fill="var(--primary)" />
      <path d="M64 50c8-2 14-2 14 2s-6 6-14 6" fill="var(--primary)" />
      <path d="M68 52 82 48l-10 10-4-6Z" fill="var(--primary)" />
      <circle cx="34" cy="46" r="3" fill="var(--paper)" />
      <path d="M40 62c-6 6-14 8-20 6 4-6 10-10 16-12l4 6Z" fill="var(--primary)" />
    </>
  ),
  Rabbit: (
    <>
      <path d="M36 46c-4-14-2-28 4-30s10 10 8 24l-4 10-8-4Z" fill="var(--primary)" />
      <path d="M64 46c4-14 2-28-4-30s-10 10-8 24l4 10 8-4Z" fill="var(--primary)" />
      <circle cx="50" cy="58" r="20" fill="var(--primary)" />
      <circle cx="43" cy="54" r="3" fill="var(--paper)" />
      <circle cx="57" cy="54" r="3" fill="var(--paper)" />
      <ellipse cx="50" cy="63" rx="4" ry="3" fill="var(--paper)" />
    </>
  ),
  "Small Pet": (
    <>
      <ellipse cx="50" cy="56" rx="26" ry="18" fill="var(--primary)" />
      <ellipse cx="30" cy="42" rx="5" ry="6" fill="var(--primary)" />
      <ellipse cx="42" cy="38" rx="5" ry="6" fill="var(--primary)" />
      <circle cx="34" cy="52" r="2.6" fill="var(--paper)" />
      <circle cx="46" cy="50" r="2.6" fill="var(--paper)" />
      <ellipse cx="28" cy="58" rx="3.5" ry="2.5" fill="var(--paper)" />
    </>
  ),
};

export function SpeciesIcon({ species, className = "" }) {
  const shape = shapes[species] ?? shapes.Dog;
  return (
    <div className={`flex items-center justify-center bg-primary/[0.07] ${className}`}>
      <svg viewBox="0 0 100 100" className="h-2/3 w-2/3" role="img" aria-label={`${species} icon`}>
        {shape}
      </svg>
    </div>
  );
}
