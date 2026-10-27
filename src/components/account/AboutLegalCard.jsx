import { ArrowRight, FileText, Headset, ShieldCheck } from "@phosphor-icons/react";
import { Link } from "react-router-dom";

const LINKS = [
  { to: "/legal/privacy", label: "Privacy policy", icon: ShieldCheck },
  { to: "/legal/terms", label: "Terms of service", icon: FileText },
  { to: "/support", label: "Contact support", icon: Headset },
];

/** "About & legal" card on the profile page: the privacy policy, terms and a way to reach support. */
export function AboutLegalCard() {
  return (
    <ul className="mt-4 divide-y divide-border overflow-hidden rounded-xl border border-border bg-surface">
      {LINKS.map(({ to, label, icon: Icon }) => (
        <li key={to}>
          <Link to={to} className="group flex items-center gap-3 px-4 py-3.5 transition-colors hover:bg-primary/5">
            <Icon size={20} className="flex-none text-primary" />
            <span className="min-w-0 flex-1 text-[15px] text-ink">{label}</span>
            <ArrowRight
              size={16}
              className="flex-none text-ink-soft transition-transform group-hover:translate-x-0.5"
            />
          </Link>
        </li>
      ))}
    </ul>
  );
}
