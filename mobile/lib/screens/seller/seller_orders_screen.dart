import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Mirrors src/pages/seller/Orders.jsx: orders that include at least one
/// pet or product belonging to the signed-in seller's shop.
class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

const _orderTypeLabels = {
  'product_purchase': 'Product purchase',
  'pet_reservation': 'Pet reservation',
  'gift': 'Gift',
};

class _OrderLineItem {
  final String name;
  final int quantity;
  final num price;

  const _OrderLineItem({required this.name, required this.quantity, required this.price});
}

class _OrderCard {
  final String id;
  final String orderType;
  final String status;
  final num totalAmount;
  final DateTime createdAt;
  final String customerName;
  final List<_OrderLineItem> items;

  const _OrderCard({
    required this.id,
    required this.orderType,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.customerName,
    required this.items,
  });
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen> {
  bool _loading = true;
  String? _error;
  Shop? _shop;
  List<_OrderCard> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final shop = await ShopsRepository().getByOwnerId(profile.id);
      if (shop == null) {
        if (!mounted) return;
        setState(() {
          _shop = null;
          _loading = false;
        });
        return;
      }

      final pets = await PetsRepository().listByShop(shop.id);
      final products = await ProductsRepository().listByShop(shop.id);

      final petIds = pets.map((pet) => pet.id).toList();
      final productIds = products.map((product) => product.id).toList();

      final names = <String, String>{};
      for (final pet in pets) {
        names[pet.id] = pet.breed.isNotEmpty ? '${pet.breed} (${pet.species})' : pet.species;
      }
      for (final product in products) {
        names[product.id] = product.name;
      }

      if (petIds.isEmpty && productIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _shop = shop;
          _orders = [];
          _loading = false;
        });
        return;
      }

      final orderItemsRepo = OrderItemsRepository();
      final petOrderIds = await orderItemsRepo.orderIdsForItems(itemType: 'pet', itemIds: petIds);
      final productOrderIds =
          await orderItemsRepo.orderIdsForItems(itemType: 'product', itemIds: productIds);
      final orderIds = <String>{...petOrderIds, ...productOrderIds}.toList();

      if (orderIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _shop = shop;
          _orders = [];
          _loading = false;
        });
        return;
      }

      final rawOrders = await OrdersRepository().listByIds(orderIds);

      final orders = <_OrderCard>[];
      for (final row in rawOrders) {
        final itemRows = await SupabaseService.client
            .from('order_items')
            .select()
            .eq('order_id', row['id']);
        final items = (itemRows as List)
            .cast<Map<String, dynamic>>()
            .map(
              (item) => _OrderLineItem(
                name: names[item['item_id']] ?? 'Item',
                quantity: item['quantity'] as int,
                price: item['price_at_purchase'] as num,
              ),
            )
            .toList();

        // OrdersRepository().listByIds doesn't join profiles, so the
        // customer name is unavailable here; fall back to a generic label.
        final profileJson = row['profiles'] as Map<String, dynamic>?;

        orders.add(
          _OrderCard(
            id: row['id'] as String,
            orderType: row['order_type'] as String,
            status: row['status'] as String,
            totalAmount: row['total_amount'] as num,
            createdAt: DateTime.parse(row['created_at'] as String),
            customerName: (profileJson?['name'] as String?) ?? 'Customer',
            items: items,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _shop = shop;
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
      case 'fulfilled':
        return AppColors.trust;
      case 'pending':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(title: 'Orders', child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(label: 'Loading orders…');
    }

    if (_shop == null) {
      return Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: "You haven't set up your shop yet",
          description: 'Create your shop profile first.',
          action: ElevatedButton(
            onPressed: () => context.push('/seller/store'),
            child: const Text('Set up your shop'),
          ),
        ),
      );
    }

    if (_error != null) {
      return ErrorView(message: "Couldn't load orders: $_error");
    }

    if (_orders.isEmpty) {
      return const Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: 'No orders yet',
          description: 'Orders for your pets and products will show up here.',
        ),
      );
    }

    return ListView(
      padding: kScreenPadding,
      children: [
        const ScreenHeader(
          title: 'Orders',
          subtitle: 'Orders that include items from your shop.',
        ),
        const SizedBox(height: 24),
        for (final order in _orders) ...[
          _OrderCardView(order: order, statusColor: _statusColor(order.status)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _OrderCardView extends StatelessWidget {
  final _OrderCard order;
  final Color statusColor;

  const _OrderCardView({required this.order, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final typeLabel = _orderTypeLabels[order.orderType] ?? order.orderType.replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.customerName} · ${formatOrderDate(order.createdAt)}',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(status: order.status, color: statusColor),
                  const SizedBox(height: 8),
                  Text(
                    formatPrice(order.totalAmount),
                    style: AppTheme.display(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTheme.body(fontSize: 14),
                          children: [
                            TextSpan(text: item.name),
                            if (item.quantity > 1)
                              TextSpan(
                                text: ' × ${item.quantity}',
                                style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      formatPrice(item.price),
                      style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
