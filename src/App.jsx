import { useEffect } from "react";
import { Route, Routes } from "react-router-dom";
import { ScrollToTop } from "./components/ScrollToTop";
import { ProtectedRoute } from "./components/auth/ProtectedRoute";
import { Layout } from "./components/layout/Layout";
import { Account } from "./pages/Account";
import { Cart } from "./pages/Cart";
import { Checkout } from "./pages/Checkout";
import { Gifting } from "./pages/Gifting";
import { Home } from "./pages/Home";
import { Learn } from "./pages/Learn";
import { Login } from "./pages/Login";
import { NotFound } from "./pages/NotFound";
import { PetDetail } from "./pages/PetDetail";
import { PetsList } from "./pages/PetsList";
import { ProductDetail } from "./pages/ProductDetail";
import { Reserve } from "./pages/Reserve";
import { Sell } from "./pages/Sell";
import { ShopDetail } from "./pages/ShopDetail";
import { Shops } from "./pages/Shops";
import { SignUp } from "./pages/SignUp";
import { Store } from "./pages/Store";
import { Support } from "./pages/Support";
import { AdminContracts } from "./pages/admin/Contracts";
import { AdminDashboard } from "./pages/admin/Dashboard";
import { AdminOrders } from "./pages/admin/Orders";
import { AdminShops } from "./pages/admin/Shops";
import { AdminSupport } from "./pages/admin/Support";
import { AdminVideos } from "./pages/admin/Videos";
import { SellerContract } from "./pages/seller/Contract";
import { SellerDashboard } from "./pages/seller/Dashboard";
import { SellerOrders } from "./pages/seller/Orders";
import { SellerPets } from "./pages/seller/Pets";
import { SellerProducts } from "./pages/seller/Products";
import { SellerStoreProfile } from "./pages/seller/StoreProfile";
import { SellerSupport } from "./pages/seller/Support";
import { useAuthStore } from "./store/authStore";

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
          <Route path="/gifting" element={<Gifting />} />
          <Route path="/learn" element={<Learn />} />
          <Route path="/cart" element={<Cart />} />
          <Route path="/checkout" element={<Checkout />} />
          <Route path="/reserve/:petId" element={<Reserve />} />
          <Route path="/support" element={<Support />} />
          <Route path="/account" element={<Account />} />
          <Route path="/for-store-owners" element={<Sell />} />
          <Route path="/signup" element={<SignUp />} />
          <Route path="/login" element={<Login />} />

          {/* Shop Owner dashboard */}
          <Route
            path="/seller/dashboard"
            element={
              <ProtectedRoute allowedRoles={["shop_owner"]}>
                <SellerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/store"
            element={
              <ProtectedRoute allowedRoles={["shop_owner"]}>
                <SellerStoreProfile />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/pets"
            element={
              <ProtectedRoute allowedRoles={["shop_owner"]}>
                <SellerPets />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/products"
            element={
              <ProtectedRoute allowedRoles={["shop_owner"]}>
                <SellerProducts />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/orders"
            element={
              <ProtectedRoute allowedRoles={["shop_owner"]}>
                <SellerOrders />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/support"
            element={
              <ProtectedRoute allowedRoles={["shop_owner"]}>
                <SellerSupport />
              </ProtectedRoute>
            }
          />
          <Route
            path="/seller/contract"
            element={
              <ProtectedRoute allowedRoles={["shop_owner"]}>
                <SellerContract />
              </ProtectedRoute>
            }
          />

          {/* Admin dashboard */}
          <Route
            path="/admin/dashboard"
            element={
              <ProtectedRoute allowedRoles={["admin"]}>
                <AdminDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/shops"
            element={
              <ProtectedRoute allowedRoles={["admin"]}>
                <AdminShops />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/orders"
            element={
              <ProtectedRoute allowedRoles={["admin"]}>
                <AdminOrders />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/videos"
            element={
              <ProtectedRoute allowedRoles={["admin"]}>
                <AdminVideos />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/support"
            element={
              <ProtectedRoute allowedRoles={["admin"]}>
                <AdminSupport />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/contracts"
            element={
              <ProtectedRoute allowedRoles={["admin"]}>
                <AdminContracts />
              </ProtectedRoute>
            }
          />

          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
    </>
  );
}
