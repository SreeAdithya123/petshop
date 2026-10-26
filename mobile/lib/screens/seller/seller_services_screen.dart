import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../widgets/seller/bookings_tab.dart';
import '../../widgets/seller/requests_tab.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller/services_tab.dart';
import '../../widgets/seller_scaffold.dart';

/// Mirrors src/pages/seller/Services.jsx: the shop's services, the bookings
/// customers make and the custom requests it can quote on. `?tab=bookings` or
/// `?tab=requests` opens that tab directly (the dashboard counters use it).
class SellerServicesScreen extends StatelessWidget {
  const SellerServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    String? initialTab;
    try {
      initialTab = GoRouterState.of(context).uri.queryParameters['tab'];
    } catch (_) {
      initialTab = null;
    }
    return SellerScaffold(
      title: 'Services',
      subtitle: 'Manage the services your shop offers, the bookings customers make and their custom requests.',
      builder: (context, shop) => _ServicesWorkspace(shop: shop, initialTab: initialTab),
    );
  }
}

const _tabs = ['services', 'bookings', 'requests'];

// Custom requests are read without customer_id: shop owners never see who asked.
const _requestColumns =
    'id, title, description, category, pet_name, pet_species, preferred_date, budget, status, shop_id, quoted_price, response_message, responded_at, created_at';

Future<List<ServiceItem>> _fetchServices(String shopId) async {
  final data = await fetchAllRows(() => SupabaseService.client.from('services').select().eq('shop_id', shopId));
  final rows = data.map(ServiceItem.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return rows;
}

Future<WithCustomers<ServiceBooking>> _fetchBookings(String shopId) async {
  final data = await fetchAllRows(() => SupabaseService.client.from('service_bookings').select().eq('shop_id', shopId));
  final rows = data.map(ServiceBooking.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return attachCustomers<ServiceBooking>(rows, (booking) => booking.customerId);
}

// Every open request is visible to approved shop owners; the rest are the ones this shop quoted.
Future<List<CustomServiceRequest>> _fetchRequests(String shopId) async {
  final data = await fetchAllRows(
    () => SupabaseService.client
        .from('custom_service_requests')
        .select(_requestColumns)
        .or('status.eq.open,shop_id.eq.$shopId'),
  );
  final rows = data.map(CustomServiceRequest.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return rows;
}

class _ServicesWorkspace extends ConsumerStatefulWidget {
  final Shop shop;
  final String? initialTab;
  const _ServicesWorkspace({required this.shop, this.initialTab});

  @override
  ConsumerState<_ServicesWorkspace> createState() => _ServicesWorkspaceState();
}

class _ServicesWorkspaceState extends ConsumerState<_ServicesWorkspace> {
  late final SellerQuery<List<ServiceItem>> _services;
  late final SellerQuery<WithCustomers<ServiceBooking>> _bookings;
  late final SellerQuery<List<CustomServiceRequest>> _requests;
  late String _tab;

  @override
  void initState() {
    super.initState();
    final shopId = widget.shop.id;
    _tab = _tabs.contains(widget.initialTab) ? widget.initialTab! : 'services';
    _services = SellerQuery<List<ServiceItem>>(() => _fetchServices(shopId));
    _bookings = SellerQuery<WithCustomers<ServiceBooking>>(() => _fetchBookings(shopId));
    _requests = SellerQuery<List<CustomServiceRequest>>(() => _fetchRequests(shopId));
  }

  @override
  void dispose() {
    _services.dispose();
    _bookings.dispose();
    _requests.dispose();
    super.dispose();
  }

  void _reloadAll() {
    _services.reload();
    _bookings.reload();
    _requests.reload();
  }

  @override
  Widget build(BuildContext context) {
    listenForShopRefresh(ref, _reloadAll);
    final shopId = widget.shop.id;
    final readOnly = widget.shop.status != 'approved';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([_services, _bookings, _requests]),
          builder: (context, _) {
            final pendingBookings = _bookings.data?.rows.where((booking) => booking.status == 'pending').length;
            final openRequests = _requests.data?.where((request) => request.status == 'open').length;
            return SellerTabBar(
              tabs: [
                SellerTab('services', 'My services', count: _services.data?.length),
                SellerTab('bookings', 'Bookings', count: pendingBookings, attention: true),
                SellerTab('requests', 'Custom requests', count: openRequests, attention: true),
              ],
              selected: _tab,
              onSelected: (value) => setState(() => _tab = value),
            );
          },
        ),
        const SizedBox(height: 20),
        if (_tab == 'services')
          ServicesTab(key: const ValueKey('services'), shopId: shopId, readOnly: readOnly, query: _services)
        else if (_tab == 'bookings')
          BookingsTab(key: const ValueKey('bookings'), readOnly: readOnly, query: _bookings)
        else
          RequestsTab(key: const ValueKey('requests'), shopId: shopId, readOnly: readOnly, query: _requests),
      ],
    );
  }
}
