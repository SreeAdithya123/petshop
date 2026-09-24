import { Link } from "react-router-dom";
import { PawMark } from "./PawMark";

const footerLinks = [
  { to: "/pets", label: "Shop pets" },
  { to: "/sellers", label: "Shops" },
  { to: "/for-store-owners", label: "Sell on Paws Nearby" },
];

export function Footer() {
  return (
    <footer className="mt-20 border-t border-border bg-surface">
      <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="grid gap-10 sm:grid-cols-[1.4fr_1fr]">
          <div>
            <Link to="/" className="flex items-center gap-2.5">
              <PawMark />
              <span className="font-display text-xl font-semibold text-ink">Paws Nearby</span>
            </Link>
            <p className="mt-4 max-w-sm text-sm text-ink-soft">
              Pets in stock at licensed local pet stores, in one place. Shop online, then pick up and pay
              in person — nothing ships.
            </p>
          </div>
          <nav aria-label="Footer">
            <ul className="grid gap-2.5 text-sm">
              {footerLinks.map((item) => (
                <li key={item.to}>
                  <Link to={item.to} className="text-ink-soft hover:text-ink">
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
        </div>

        <div className="mt-10 flex flex-col gap-2 border-t border-border pt-6 text-xs text-ink-soft sm:flex-row sm:items-center sm:justify-between">
          <p>© {new Date().getFullYear()} Paws Nearby. Every listed shop is a licensed pet dealer.</p>
          <p>Orders are picked up and paid for in person at the shop.</p>
        </div>
      </div>
    </footer>
  );
}
