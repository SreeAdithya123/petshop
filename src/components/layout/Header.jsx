import { List, ShoppingCartSimple, X } from "@phosphor-icons/react";
import { useState } from "react";
import { Link, NavLink, useNavigate } from "react-router-dom";
import { roleHomePath, useAuthStore } from "../../store/authStore";
import { useCartStore } from "../../store/cartStore";
import { PawMark } from "./PawMark";

const customerNavItems = [
  { to: "/pets", label: "Shop pets" },
  { to: "/store", label: "Store" },
  { to: "/sellers", label: "Shops" },
  { to: "/services", label: "Services" },
  { to: "/health", label: "Health" },
  { to: "/gifting", label: "Gifting" },
  { to: "/support", label: "Support" },
];

// The full seller menu lives in the dashboard sidebar; the header keeps the essentials.
const sellerNavItems = [
  { to: "/seller/dashboard", label: "Dashboard" },
  { to: "/seller/orders", label: "Orders" },
  { to: "/seller/services", label: "Services" },
  { to: "/seller/demos", label: "Demo requests" },
  { to: "/seller/refunds", label: "Refunds" },
];

const adminNavItems = [
  { to: "/admin/dashboard", label: "Dashboard" },
  { to: "/admin/shops", label: "Shops" },
  { to: "/admin/services", label: "Services" },
  { to: "/admin/orders", label: "Orders" },
  { to: "/admin/videos", label: "Videos" },
  { to: "/admin/support", label: "Support" },
  { to: "/admin/contracts", label: "Contracts" },
];

export function Header() {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  const itemCount = useCartStore((state) => state.items.length);
  const openDrawer = useCartStore((state) => state.openDrawer);

  const status = useAuthStore((state) => state.status);
  const profile = useAuthStore((state) => state.profile);
  const signOut = useAuthStore((state) => state.signOut);
  const isSignedIn = status === "signed-in" && profile;
  const accountLabel = profile?.role === "customer" ? "My account" : profile?.name || "Account";

  const navItems =
    isSignedIn && profile.role === "shop_owner"
      ? sellerNavItems
      : isSignedIn && profile.role === "admin"
        ? adminNavItems
        : customerNavItems;

  async function handleSignOut() {
    setOpen(false);
    await signOut();
    navigate("/");
  }

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-surface">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:h-[72px] lg:px-8">
        <div className="flex items-center gap-8">
          <Link to="/" className="flex items-center gap-2.5" onClick={() => setOpen(false)}>
            <PawMark />
            <span className="font-display text-xl font-black italic tracking-tighter text-ink">
              PETSTA<span className="text-primary">.</span>
            </span>
          </Link>

          <nav className="hidden items-center gap-6 lg:flex" aria-label="Primary">
            {navItems.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  `whitespace-nowrap text-[15px] transition-colors ${
                    isActive ? "font-medium text-primary" : "text-ink-soft hover:text-ink"
                  }`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </div>

        <div className="flex items-center gap-3">
          <div className="hidden items-center gap-4 lg:flex">
            {isSignedIn ? (
              <>
                <Link to={roleHomePath(profile.role)} className="text-sm text-ink-soft hover:text-ink">
                  {accountLabel}
                </Link>
                <button type="button" onClick={handleSignOut} className="text-sm text-ink-soft hover:text-ink">
                  Log out
                </button>
              </>
            ) : (
              <>
                <Link to="/login" className="text-sm text-ink-soft hover:text-ink">
                  Log in
                </Link>
                <Link to="/signup" className="text-sm font-medium text-primary hover:opacity-80">
                  Sign up
                </Link>
              </>
            )}
          </div>

          <button
            type="button"
            onClick={openDrawer}
            aria-label={`Open cart${itemCount ? `, ${itemCount} items` : ""}`}
            className="relative flex h-10 w-10 items-center justify-center rounded-full text-ink hover:bg-primary/5"
          >
            <ShoppingCartSimple size={22} />
            {itemCount > 0 && (
              <span className="absolute -right-0.5 -top-0.5 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-accent px-1 text-[11px] font-medium text-white">
                {itemCount}
              </span>
            )}
          </button>

          <button
            type="button"
            onClick={() => setOpen((value) => !value)}
            className="flex h-10 w-10 items-center justify-center rounded-full text-ink lg:hidden"
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
          >
            {open ? <X size={24} /> : <List size={24} />}
          </button>
        </div>
      </div>

      {open && (
        <nav className="border-t border-border px-4 pb-5 pt-2 lg:hidden" aria-label="Primary">
          <ul className="flex flex-col gap-1">
            {navItems.map((item) => (
              <li key={item.to}>
                <NavLink
                  to={item.to}
                  onClick={() => setOpen(false)}
                  className={({ isActive }) =>
                    `block rounded-lg px-3 py-2.5 text-[15px] ${
                      isActive ? "bg-primary/5 font-medium text-primary" : "text-ink-soft"
                    }`
                  }
                >
                  {item.label}
                </NavLink>
              </li>
            ))}
          </ul>

          <div className="mt-3 flex flex-col gap-1 border-t border-border pt-3">
            {isSignedIn ? (
              <>
                <Link
                  to={roleHomePath(profile.role)}
                  onClick={() => setOpen(false)}
                  className="block rounded-lg px-3 py-2.5 text-[15px] text-ink-soft"
                >
                  {accountLabel}
                </Link>
                <button
                  type="button"
                  onClick={handleSignOut}
                  className="block rounded-lg px-3 py-2.5 text-left text-[15px] text-ink-soft"
                >
                  Log out
                </button>
              </>
            ) : (
              <>
                <Link
                  to="/login"
                  onClick={() => setOpen(false)}
                  className="block rounded-lg px-3 py-2.5 text-[15px] text-ink-soft"
                >
                  Log in
                </Link>
                <Link
                  to="/signup"
                  onClick={() => setOpen(false)}
                  className="block rounded-lg px-3 py-2.5 text-[15px] font-medium text-primary"
                >
                  Sign up
                </Link>
              </>
            )}
          </div>
        </nav>
      )}
    </header>
  );
}
