/**
 * A simple flat SVG scene (a small street of shopfronts), not a 3D element
 * and not a single illustrated mascot character — per brief.
 */
export function HeroScene({ className = "" }) {
  return (
    <div className={`relative aspect-[6/5] w-full overflow-hidden rounded-xl bg-primary/[0.06] ${className}`}>
      <svg viewBox="0 0 480 400" className="h-full w-full" role="img" aria-label="Illustration of a row of pet shopfronts">
        <rect x="0" y="300" width="480" height="6" fill="var(--border)" />

        {/* shopfront 1 */}
        <rect x="24" y="180" width="96" height="120" rx="10" fill="var(--surface)" stroke="var(--border)" />
        <rect x="24" y="170" width="96" height="20" rx="6" fill="var(--primary)" />
        <rect x="56" y="240" width="32" height="60" rx="4" fill="var(--paper)" />
        <rect x="36" y="210" width="20" height="18" rx="3" fill="var(--paper)" />
        <rect x="88" y="210" width="20" height="18" rx="3" fill="var(--paper)" />

        {/* shopfront 2 (taller, center) */}
        <rect x="144" y="130" width="120" height="170" rx="10" fill="var(--paper)" stroke="var(--border)" />
        <rect x="144" y="118" width="120" height="22" rx="7" fill="var(--ink-soft)" />
        <rect x="184" y="230" width="40" height="70" rx="4" fill="var(--surface)" />
        <rect x="160" y="160" width="24" height="22" rx="3" fill="var(--surface)" />
        <rect x="224" y="160" width="24" height="22" rx="3" fill="var(--surface)" />

        {/* shopfront 3 */}
        <rect x="288" y="200" width="90" height="100" rx="10" fill="var(--surface)" stroke="var(--border)" />
        <rect x="288" y="190" width="90" height="18" rx="6" fill="var(--primary)" opacity="0.6" />
        <rect x="316" y="250" width="30" height="50" rx="4" fill="var(--paper)" />
        <rect x="300" y="222" width="18" height="16" rx="3" fill="var(--paper)" />
        <rect x="350" y="222" width="18" height="16" rx="3" fill="var(--paper)" />

        {/* shopfront 4 */}
        <rect x="392" y="160" width="70" height="140" rx="10" fill="var(--paper)" stroke="var(--border)" />
        <rect x="392" y="150" width="70" height="18" rx="6" fill="var(--primary)" />
        <rect x="414" y="230" width="26" height="70" rx="4" fill="var(--surface)" />
        <rect x="402" y="188" width="18" height="16" rx="3" fill="var(--surface)" />
        <rect x="436" y="188" width="18" height="16" rx="3" fill="var(--surface)" />

        {/* soft pet-silhouette accents */}
        <g opacity="0.16" fill="var(--primary)">
          <ellipse cx="200" cy="90" rx="18" ry="15" />
          <ellipse cx="188" cy="72" rx="8" ry="9" />
          <ellipse cx="212" cy="72" rx="8" ry="9" />
        </g>
        <g opacity="0.14" fill="var(--primary)">
          <ellipse cx="340" cy="150" rx="14" ry="11" />
          <path d="M328 138 320 122l14 8Z" />
          <path d="M352 138 360 122l-14 8Z" />
        </g>
        <g opacity="0.14" fill="var(--primary)">
          <ellipse cx="80" cy="140" rx="16" ry="13" />
          <path d="M96 136c6-1 10-1 10 2s-4 4-10 4" />
        </g>
      </svg>
    </div>
  );
}
