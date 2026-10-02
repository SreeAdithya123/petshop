import {
  ArrowCounterClockwise,
  BookOpen,
  CalendarCheck,
  Heart,
  MapPinLine,
  Package,
  Storefront,
  User,
} from "@phosphor-icons/react";
import { Outlet } from "react-router-dom";
import { useAuthStore } from "../../store/authStore";
import { LoginPrompt } from "../ui/LoginPrompt";
import { Container } from "./Container";
import { SidebarLayout } from "./SidebarLayout";

const baseItems = [
  { to: "/account", label: "Profile", icon: User, end: true },
  { to: "/account/orders", label: "My orders", icon: Package },
  { to: "/account/wishlist", label: "Wishlist", icon: Heart },
  { to: "/account/refunds", label: "Refunds", icon: ArrowCounterClockwise },
  { to: "/account/addresses", label: "Addresses", icon: MapPinLine },
  { to: "/account/demos", label: "Demo requests", icon: CalendarCheck },
  { to: "/account/learn", label: "Learn", icon: BookOpen },
];

const sellItem = { to: "/account/sell", label: "Sell on PETSTA", icon: Storefront };

/** Everything under /account: signed-in customers only, with a sidebar. */
export function AccountLayout() {
  const status = useAuthStore((state) => state.status);
  const profile = useAuthStore((state) => state.profile);

  if (status === "loading") {
    return (
      <Container className="py-16">
        <p className="text-ink-soft">Loading…</p>
      </Container>
    );
  }

  if (!profile) {
    return (
      <Container className="py-16">
        <LoginPrompt title="Log in to see your account" />
      </Container>
    );
  }

  // The seller application only makes sense for customers.
  const items = profile.role === "customer" ? [...baseItems, sellItem] : baseItems;

  return (
    <SidebarLayout heading="My account" subheading={profile.name || profile.email} items={items}>
      <Outlet />
    </SidebarLayout>
  );
}
