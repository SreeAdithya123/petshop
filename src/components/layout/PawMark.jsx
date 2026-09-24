export function PawMark({ size = 28 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <rect width="64" height="64" rx="14" fill="var(--primary)" />
      <g fill="var(--paper)">
        <ellipse cx="32" cy="40" rx="13" ry="11" />
        <ellipse cx="16" cy="24" rx="6" ry="7.5" />
        <ellipse cx="48" cy="24" rx="6" ry="7.5" />
        <ellipse cx="22" cy="14" rx="5" ry="6.5" transform="rotate(-18 22 14)" />
        <ellipse cx="42" cy="14" rx="5" ry="6.5" transform="rotate(18 42 14)" />
      </g>
      <circle cx="46" cy="46" r="9" fill="var(--accent)" />
    </svg>
  );
}
