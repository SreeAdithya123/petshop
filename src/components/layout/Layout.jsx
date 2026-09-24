import { Outlet } from "react-router-dom";
import { CartDrawer } from "../cart/CartDrawer";
import { Footer } from "./Footer";
import { Header } from "./Header";

export function Layout() {
  return (
    <div className="flex min-h-dvh flex-col bg-paper text-ink">
      <Header />
      <main className="flex-1">
        <Outlet />
      </main>
      <Footer />
      <CartDrawer />
    </div>
  );
}
