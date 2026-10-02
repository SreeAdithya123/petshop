import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_provider.dart';
import '../screens/account_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/checkout_screen.dart';
import '../screens/gifting_screen.dart';
import '../screens/home_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/login_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/pet_detail_screen.dart';
import '../screens/pets_list_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/reserve_screen.dart';
import '../screens/sell_screen.dart';
import '../screens/shop_detail_screen.dart';
import '../screens/shops_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/store_screen.dart';
import '../screens/support_screen.dart';
import '../screens/admin/admin_contracts_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_orders_screen.dart';
import '../screens/admin/admin_shops_screen.dart';
import '../screens/admin/admin_support_screen.dart';
import '../screens/admin/admin_videos_screen.dart';
import '../screens/seller/seller_contract_screen.dart';
import '../screens/seller/seller_dashboard_screen.dart';
import '../screens/seller/seller_orders_screen.dart';
import '../screens/seller/seller_pets_screen.dart';
import '../screens/seller/seller_products_screen.dart';
import '../screens/seller/seller_store_profile_screen.dart';
import '../screens/seller/seller_support_screen.dart';

const _sellerPaths = [
  '/seller/dashboard',
  '/seller/store',
  '/seller/pets',
  '/seller/products',
  '/seller/orders',
  '/seller/support',
  '/seller/contract',
];

const _adminPaths = [
  '/admin/dashboard',
  '/admin/shops',
  '/admin/orders',
  '/admin/videos',
  '/admin/support',
  '/admin/contracts',
];

/// Mirrors src/App.jsx's route table + src/components/auth/ProtectedRoute.jsx's
/// redirect behaviour: signed-out visitor hitting a /seller or /admin route
/// bounces to /login; wrong-role visitor bounces to their own role home.
GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: ref.watch(authControllerProvider),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;
      final needsSeller = _sellerPaths.any((p) => path.startsWith(p));
      final needsAdmin = _adminPaths.any((p) => path.startsWith(p));
      if (!needsSeller && !needsAdmin) return null;

      if (auth.status == AuthStatus.loading) return null;
      if (auth.status != AuthStatus.signedIn || auth.profile == null) return '/login';

      final role = auth.profile!.role;
      if (needsSeller && role != 'shop_owner') return roleHomePath(role);
      if (needsAdmin && role != 'admin') return roleHomePath(role);
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/pets', builder: (context, state) => const PetsListScreen()),
      GoRoute(
        path: '/pets/:id',
        builder: (context, state) => PetDetailScreen(petId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/store', builder: (context, state) => const StoreScreen()),
      GoRoute(
        path: '/store/:id',
        builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/sellers', builder: (context, state) => const ShopsScreen()),
      GoRoute(
        path: '/sellers/:id',
        builder: (context, state) => ShopDetailScreen(shopId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/gifting', builder: (context, state) => const GiftingScreen()),
      GoRoute(path: '/learn', builder: (context, state) => const LearnScreen()),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/reserve/:petId',
        builder: (context, state) => ReserveScreen(petId: state.pathParameters['petId']!),
      ),
      GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
      GoRoute(path: '/account', builder: (context, state) => const AccountScreen()),
      GoRoute(path: '/for-store-owners', builder: (context, state) => const SellScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      GoRoute(path: '/seller/dashboard', builder: (context, state) => const SellerDashboardScreen()),
      GoRoute(path: '/seller/store', builder: (context, state) => const SellerStoreProfileScreen()),
      GoRoute(path: '/seller/pets', builder: (context, state) => const SellerPetsScreen()),
      GoRoute(path: '/seller/products', builder: (context, state) => const SellerProductsScreen()),
      GoRoute(path: '/seller/orders', builder: (context, state) => const SellerOrdersScreen()),
      GoRoute(path: '/seller/support', builder: (context, state) => const SellerSupportScreen()),
      GoRoute(path: '/seller/contract', builder: (context, state) => const SellerContractScreen()),

      GoRoute(path: '/admin/dashboard', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/shops', builder: (context, state) => const AdminShopsScreen()),
      GoRoute(path: '/admin/orders', builder: (context, state) => const AdminOrdersScreen()),
      GoRoute(path: '/admin/videos', builder: (context, state) => const AdminVideosScreen()),
      GoRoute(path: '/admin/support', builder: (context, state) => const AdminSupportScreen()),
      GoRoute(path: '/admin/contracts', builder: (context, state) => const AdminContractsScreen()),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
}

final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));
