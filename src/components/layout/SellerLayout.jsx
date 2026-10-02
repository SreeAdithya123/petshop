import {
  ArrowCounterClockwise,
  CalendarCheck,
  ChartLineUp,
  ClipboardText,
  FileText,
  Headset,
  Package,
  PawPrint,
  Scissors,
  SquaresFour,
  Storefront,
} from "@phosphor-icons/react";
import { Outlet } from "react-router-dom";
import { SidebarLayout } from "./SidebarLayout";

const items = [
  { to: "/seller/dashboard", label: "Dashboard", icon: SquaresFour },
  { to: "/seller/analytics", label: "Analytics", icon: ChartLineUp },
  { to: "/seller/orders", label: "Orders", icon: ClipboardText },
  { to: "/seller/pets", label: "Pets", icon: PawPrint },
  { to: "/seller/products", label: "Products", icon: Package },
  { to: "/seller/services", label: "Services", icon: Scissors },
  { to: "/seller/demos", label: "Demo requests", icon: CalendarCheck },
  { to: "/seller/refunds", label: "Refunds", icon: ArrowCounterClockwise },
  { to: "/seller/support", label: "Support", icon: Headset },
  { to: "/seller/store", label: "My store", icon: Storefront },
  { to: "/seller/contract", label: "Contract", icon: FileText },
];

/** Shell for every /seller/* page. Wrap in <ProtectedRoute allowedRoles={["shop_owner"]}>. */
export function SellerLayout() {
  return (
    <SidebarLayout heading="Seller dashboard" items={items}>
      <Outlet />
    </SidebarLayout>
  );
}
