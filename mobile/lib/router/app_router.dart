import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_provider.dart';
import '../screens/account/account_addresses_screen.dart';
import '../screens/account/account_demos_screen.dart';
import '../screens/account/account_orders_screen.dart';
import '../screens/account/account_profile_screen.dart';
import '../screens/account/account_refunds_screen.dart';
import '../screens/account/account_wishlist_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/checkout_screen.dart';
import '../screens/gifting_screen.dart';
import '../screens/health_screen.dart';
import '../screens/home_screen.dart';
import '../screens/learn_screen.dart';
import '../screens/login_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/pet_detail_screen.dart';
import '../screens/pets_list_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/reserve_screen.dart';
import '../screens/sell_screen.dart';
import '../screens/services_screen.dart';
import '../screens/shop_detail_screen.dart';
import '../screens/shops_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/store_screen.dart';
import '../screens/support_screen.dart';
import '../screens/admin/admin_contracts_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_orders_screen.dart';
import '../screens/admin/admin_services_screen.dart';
import '../screens/admin/admin_shops_screen.dart';
import '../screens/admin/admin_support_screen.dart';
import '../screens/admin/admin_videos_screen.dart';
import '../screens/seller/seller_analytics_screen.dart';
import '../screens/seller/seller_contract_screen.dart';
import '../screens/seller/seller_dashboard_screen.dart';
import '../screens/seller/seller_demos_screen.dart';
import '../screens/seller/seller_orders_screen.dart';
import '../screens/seller/seller_pets_screen.dart';
import '../screens/seller/seller_products_screen.dart';
import '../screens/seller/seller_refunds_screen.dart';
import '../screens/seller/seller_services_screen.dart';
import '../screens/seller/seller_store_profile_screen.dart';
import '../screens/seller/seller_support_screen.dart';

const _sellerPaths = [
  '/seller/dashboard',
  '/seller/analytics',
  '/seller/store',
  '/seller/pets',
  '/seller/products',
  '/seller/orders',
  '/seller/services',
  '/seller/demos',
  '/seller/refunds',
  '/seller/support',
  '/seller/contract',
];

const _adminPaths = [
  '/admin/dashboard',
  '/admin/shops',
  '/admin/services',
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
      GoRoute(path: '/services', builder: (context, state) => const ServicesScreen()),
      GoRoute(path: '/health', builder: (context, state) => const HealthScreen()),
      GoRoute(path: '/gifting', builder: (context, state) => const GiftingScreen()),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/reserve/:petId',
        builder: (context, state) => ReserveScreen(petId: state.pathParameters['petId']!),
      ),
      GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),

      // Learn and "Sell on PETSTA" now live inside My account.
      GoRoute(path: '/learn', redirect: (context, state) => '/account/learn'),
      GoRoute(path: '/for-store-owners', redirect: (context, state) => '/account/sell'),

      // My account (section chips act as the sidebar).
      GoRoute(path: '/account', builder: (context, state) => const AccountProfileScreen()),
      GoRoute(path: '/account/orders', builder: (context, state) => const AccountOrdersScreen()),
      GoRoute(path: '/account/wishlist', builder: (context, state) => const AccountWishlistScreen()),
      GoRoute(
        path: '/account/refunds',
        builder: (context, state) => AccountRefundsScreen(orderId: state.uri.queryParameters['order']),
      ),
      GoRoute(path: '/account/addresses', builder: (context, state) => const AccountAddressesScreen()),
      GoRoute(path: '/account/demos', builder: (context, state) => const AccountDemosScreen()),
      GoRoute(path: '/account/learn', builder: (context, state) => const LearnScreen()),
      GoRoute(path: '/account/sell', builder: (context, state) => const SellScreen()),

      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      GoRoute(path: '/seller/dashboard', builder: (context, state) => const SellerDashboardScreen()),
      GoRoute(path: '/seller/analytics', builder: (context, state) => const SellerAnalyticsScreen()),
      GoRoute(path: '/seller/store', builder: (context, state) => const SellerStoreProfileScreen()),
      GoRoute(path: '/seller/pets', builder: (context, state) => const SellerPetsScreen()),
      GoRoute(path: '/seller/products', builder: (context, state) => const SellerProductsScreen()),
      GoRoute(path: '/seller/orders', builder: (context, state) => const SellerOrdersScreen()),
      GoRoute(path: '/seller/services', builder: (context, state) => const SellerServicesScreen()),
      GoRoute(path: '/seller/demos', builder: (context, state) => const SellerDemosScreen()),
      GoRoute(path: '/seller/refunds', builder: (context, state) => const SellerRefundsScreen()),
      GoRoute(path: '/seller/support', builder: (context, state) => const SellerSupportScreen()),
      GoRoute(path: '/seller/contract', builder: (context, state) => const SellerContractScreen()),

      GoRoute(path: '/admin/dashboard', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/shops', builder: (context, state) => const AdminShopsScreen()),
      GoRoute(path: '/admin/services', builder: (context, state) => const AdminServicesScreen()),
      GoRoute(path: '/admin/orders', builder: (context, state) => const AdminOrdersScreen()),
      GoRoute(path: '/admin/videos', builder: (context, state) => const AdminVideosScreen()),
      GoRoute(path: '/admin/support', builder: (context, state) => const AdminSupportScreen()),
      GoRoute(path: '/admin/contracts', builder: (context, state) => const AdminContractsScreen()),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
}

final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));
