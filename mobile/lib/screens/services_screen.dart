import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/service_categories.dart';
import '../models/service_models.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/services/booking_sheet.dart';
import '../widgets/services/custom_service_sheet.dart';
import '../widgets/services/my_services_section.dart';
import '../widgets/services/service_card.dart';
import '../widgets/services/service_support.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

class _ServiceGroup {
  final ServiceCategory category;
  final List<ServiceItem> items;
  const _ServiceGroup(this.category, this.items);
}

/// Mirrors src/pages/Services.jsx: approved services from nearby shops grouped
/// by category, a booking sheet, a "Custom service" request sheet and the
/// customer's own bookings & requests.
///
/// Deep links: `/services#custom` opens the request sheet straight away and
/// `/services#my-bookings` / `#my-requests` scroll to the customer's lists.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _searchController = TextEditingController();
  final _mineKey = GlobalKey<MyServicesSectionState>();
  final _mineAnchor = GlobalKey();

  List<ServiceItem> _services = const [];
  bool _loading = true;
  String? _error;
  String _category = 'all';
  String _query = '';
  bool _fragmentHandled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fragmentHandled) return;
    _fragmentHandled = true;
    final fragment = _routeFragment();
    if (fragment == 'custom') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCustom();
      });
    } else if (fragment == 'my-bookings' || fragment == 'my-requests') {
      final tab = fragment == 'my-requests' ? MyServicesTab.requests : MyServicesTab.bookings;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMine(tab);
      });
    }
  }

  String _routeFragment() {
    try {
      return GoRouterState.of(context).uri.fragment;
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// [silent] keeps the current list on screen (pull-to-refresh).
  Future<void> _load({bool silent = false}) async {
    if (!silent || _services.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final services = await fetchApprovedServices();
      if (!mounted) return;
      setState(() {
        _services = services;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorText(error);
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final mine = _mineKey.currentState?.reloadAll();
    await _load(silent: true);
    if (mine != null) await mine;
  }

  List<ServiceItem> _filtered() {
    final needle = _query.trim().toLowerCase();
    return _services.where((service) {
      if (_category != 'all' && service.category != _category) return false;
      if (needle.isEmpty) return true;
      final haystack = '${service.name} ${service.description ?? ''} ${service.shopName ?? ''}'.toLowerCase();
      return haystack.contains(needle);
    }).toList();
  }

  List<_ServiceGroup> _groupByCategory(List<ServiceItem> services) {
    final byCategory = <String, List<ServiceItem>>{};
    for (final service in services) {
      byCategory.putIfAbsent(service.category, () => <ServiceItem>[]).add(service);
    }
    // Known categories in their display order, then anything unexpected.
    final known = serviceCategories.map((category) => category.key).toSet();
    final order = [
      ...serviceCategories.map((category) => category.key),
      ...byCategory.keys.where((key) => !known.contains(key)),
    ];
    return [
      for (final key in order)
        if (byCategory.containsKey(key)) _ServiceGroup(serviceCategoryFor(key), byCategory[key]!),
    ];
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _category = 'all';
      _query = '';
    });
  }

  Future<void> _book(ServiceItem service) async {
    final viewMine = await showBookingSheet(
      context,
      service: service,
      onBooked: () => _mineKey.currentState?.reloadBookings(),
    );
    if (viewMine == true && mounted) _showMine(MyServicesTab.bookings);
  }

  Future<void> _openCustom() async {
    final viewMine = await showCustomServiceSheet(
      context,
      onSent: () => _mineKey.currentState?.reloadRequests(),
    );
    if (viewMine == true && mounted) _showMine(MyServicesTab.requests);
  }

  void _showMine(MyServicesTab tab) {
    _mineKey.currentState?.showTab(tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _mineAnchor.currentContext;
      if (!mounted || anchor == null) return;
      Scrollable.ensureVisible(anchor, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = ServiceAccess.from(ref.watch(authControllerProvider));
    final filtered = _filtered();

    return RoleShell(
      title: 'Services',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: kScreenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
              const SizedBox(height: 16),
              _buildFilters(),
              const SizedBox(height: 16),
              _buildServices(filtered),
              const SizedBox(height: 28),
              _buildCustomBanner(),
              const SizedBox(height: 28),
              _buildMine(access),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.secondary.withValues(alpha: 0.1),
            AppColors.tertiary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pet services', style: AppTheme.display(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            'Vets, grooming, training and more from approved local shops. Pick a slot and the shop confirms it.',
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/health#vet'),
            icon: const Icon(Icons.medical_services_outlined, size: 18),
            label: const Text('Need a vet? Book a video consult'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              textStyle: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openCustom,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Custom service'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search services',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        FilterChipBar<String>(
          options: [
            const FilterOption<String>('all', 'All'),
            for (final category in serviceCategories) FilterOption<String>(category.key, category.label),
          ],
          selected: _category,
          onSelected: (value) => setState(() => _category = value),
        ),
      ],
    );
  }

  Widget _buildServices(List<ServiceItem> filtered) {
    if (_loading) {
      return const LoadingView(label: 'Loading services…');
    }
    final error = _error;
    if (error != null) {
      return InlineErrorNotice(message: "Couldn't load services: $error", onRetry: () => _load());
    }
    if (_services.isEmpty) {
      return const EmptyState(
        title: 'No services listed yet',
        description: 'Shops are still getting set up. Need something specific? Send a custom request below and shops will quote.',
      );
    }
    if (filtered.isEmpty) {
      return EmptyState(
        title: 'No services match',
        description: 'Try a different category or search term.',
        action: OutlinedButton(onPressed: _clearFilters, child: const Text('Clear filters')),
      );
    }

    final count = filtered.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count ${count == 1 ? 'service' : 'services'}',
          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 12),
        ...(_category == 'all' ? _groupedCards(filtered) : _cardsFor(filtered)),
      ],
    );
  }

  /// "All" view: services grouped under a heading per category.
  List<Widget> _groupedCards(List<ServiceItem> services) {
    final widgets = <Widget>[];
    for (final group in _groupByCategory(services)) {
      widgets.add(_CategoryHeading(category: group.category, count: group.items.length));
      widgets.add(const SizedBox(height: 12));
      widgets.addAll(_cardsFor(group.items));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  List<Widget> _cardsFor(List<ServiceItem> services) {
    final widgets = <Widget>[];
    for (final service in services) {
      widgets.add(CatalogServiceCard(service: service, onBook: () => _book(service)));
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _buildCustomBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Can't find what you need?", style: AppTheme.display(fontSize: 22, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            "Describe the service you're after — a special grooming style, a home visit, anything — and nearby "
            'approved shops will reply with a quote.',
            style: AppTheme.body(color: Colors.white.withValues(alpha: 0.92)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openCustom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                textStyle: AppTheme.body(fontWeight: FontWeight.w800),
              ),
              child: const Text('Request a custom service'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMine(ServiceAccess access) {
    // Sellers and admins don't book services, so they get no section at all.
    if (access.loading || (access.signedIn && !access.canBook)) return const SizedBox.shrink();
    final userId = access.userId;

    return Column(
      key: _mineAnchor,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My bookings & requests', style: AppTheme.display(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          "Track the slots you've booked and the quotes on your custom requests.",
          style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        if (userId == null)
          const LoginPromptCard(
            compact: true,
            title: 'Log in to continue',
            description: 'Log in to see your bookings and custom requests.',
          )
        else
          MyServicesSection(key: _mineKey, userId: userId),
      ],
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  final ServiceCategory category;
  final int count;
  const _CategoryHeading({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(category.icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(category.label, style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text('($count)', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
      ],
    );
  }
}
