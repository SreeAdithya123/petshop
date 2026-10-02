import { useEffect } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { ScrollToTop } from "./components/ScrollToTop";
import { ProtectedRoute } from "./components/auth/ProtectedRoute";
import { AccountLayout } from "./components/layout/AccountLayout";
import { Layout } from "./components/layout/Layout";
import { SellerLayout } from "./components/layout/SellerLayout";
import { Cart } from "./pages/Cart";
import { Checkout } from "./pages/Checkout";
import { Gifting } from "./pages/Gifting";
import { Health } from "./pages/Health";
import { Home } from "./pages/Home";
import { Learn } from "./pages/Learn";
import { Login } from "./pages/Login";
import { NotFound } from "./pages/NotFound";
import { PetDetail } from "./pages/PetDetail";
import { PetsList } from "./pages/PetsList";
import { ProductDetail } from "./pages/ProductDetail";
import { Reserve } from "./pages/Reserve";
import { Sell } from "./pages/Sell";
import { Services } from "./pages/Services";
import { ShopDetail } from "./pages/ShopDetail";
import { Shops } from "./pages/Shops";
import { SignUp } from "./pages/SignUp";
import { Store } from "./pages/Store";
import { Support } from "./pages/Support";
import { AccountAddresses } from "./pages/account/AccountAddresses";
import { AccountDemos } from "./pages/account/AccountDemos";
import { AccountOrders } from "./pages/account/AccountOrders";
import { AccountProfile } from "./pages/account/AccountProfile";
import { AccountRefunds } from "./pages/account/AccountRefunds";
import { AccountWishlist } from "./pages/account/AccountWishlist";
import { AdminContracts } from "./pages/admin/Contracts";
import { AdminDashboard } from "./pages/admin/Dashboard";
import { AdminOrders } from "./pages/admin/Orders";
import { AdminServices } from "./pages/admin/Services";
import { AdminShops } from "./pages/admin/Shops";
import { AdminSupport } from "./pages/admin/Support";
import { AdminVideos } from "./pages/admin/Videos";
import { SellerAnalytics } from "./pages/seller/Analytics";
import { SellerContract } from "./pages/seller/Contract";
import { SellerDashboard } from "./pages/seller/Dashboard";
import { SellerDemos } from "./pages/seller/Demos";
import { SellerOrders } from "./pages/seller/Orders";
import { SellerPets } from "./pages/seller/Pets";
import { SellerProducts } from "./pages/seller/Products";
import { SellerRefunds } from "./pages/seller/Refunds";
import { SellerServices } from "./pages/seller/Services";
import { SellerStoreProfile } from "./pages/seller/StoreProfile";
import { SellerSupport } from "./pages/seller/Support";
import { useAuthStore } from "./store/authStore";

function admin(element) {
  return <ProtectedRoute allowedRoles={["admin"]}>{element}</ProtectedRoute>;
}

export default function App() {
  const initialize = useAuthStore((state) => state.initialize);

  useEffect(() => {
    initialize();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      <ScrollToTop />
      <Routes>
        <Route element={<Layout />}>
          {/* Customer-facing */}
          <Route path="/" element={<Home />} />
          <Route path="/pets" element={<PetsList />} />
          <Route path="/pets/:id" element={<PetDetail />} />
          <Route path="/store" element={<Store />} />
          <Route path="/store/:id" element={<ProductDetail />} />
          <Route path="/sellers" element={<Shops />} />
          <Route path="/sellers/:id" element={<ShopDetail />} />
          <Route path="/services" element={<Services />} />
          <Route path="/health" element={<Health />} />
          <Route path="/gifting" element={<Gifting />} />
          <Route path="/cart" element={<Cart />} />
          <Route path="/checkout" element={<Checkout />} />
          <Route path="/reserve/:petId" element={<Reserve />} />
          <Route path="/support" element={<Support />} />
          <Route path="/signup" element={<SignUp />} />
          <Route path="/login" element={<Login />} />

          {/* Learn and "Sell on PETSTA" now live inside My account */}
          <Route path="/learn" element={<Navigate to="/account/learn" replace />} />
          <Route path="/for-store-owners" element={<Navigate to="/account/sell" replace />} />

          {/* My account (sidebar) */}
          <Route path="/account" element={<AccountLayout />}>
            <Route index element={<AccountProfile />} />
            <Route path="orders" element={<AccountOrders />} />
            <Route path="wishlist" element={<AccountWishlist />} />
            <Route path="refunds" element={<AccountRefunds />} />
            <Route path="addresses" element={<AccountAddresses />} />
            <Route path="demos" element={<AccountDemos />} />
            <Route path="learn" element={<Learn />} />
            <Route path="sell" element={<Sell />} />
          </Route>

          {/* Shop Owner dashboard (sidebar) */}
          <Route path="/seller" element={<Navigate to="/seller/dashboard" replace />} />
          <Route
            element={
              <ProtectedRoute allowedRoles={["shop_owner"]}>
                <SellerLayout />
              </ProtectedRoute>
            }
          >
            <Route path="/seller/dashboard" element={<SellerDashboard />} />
            <Route path="/seller/analytics" element={<SellerAnalytics />} />
            <Route path="/seller/orders" element={<SellerOrders />} />
            <Route path="/seller/pets" element={<SellerPets />} />
            <Route path="/seller/products" element={<SellerProducts />} />
            <Route path="/seller/services" element={<SellerServices />} />
            <Route path="/seller/demos" element={<SellerDemos />} />
            <Route path="/seller/refunds" element={<SellerRefunds />} />
            <Route path="/seller/support" element={<SellerSupport />} />
            <Route path="/seller/store" element={<SellerStoreProfile />} />
            <Route path="/seller/contract" element={<SellerContract />} />
          </Route>

          {/* Admin dashboard */}
          <Route path="/admin/dashboard" element={admin(<AdminDashboard />)} />
          <Route path="/admin/shops" element={admin(<AdminShops />)} />
          <Route path="/admin/services" element={admin(<AdminServices />)} />
          <Route path="/admin/orders" element={admin(<AdminOrders />)} />
          <Route path="/admin/videos" element={admin(<AdminVideos />)} />
          <Route path="/admin/support" element={admin(<AdminSupport />)} />
          <Route path="/admin/contracts" element={admin(<AdminContracts />)} />

          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
    </>
  );
}
