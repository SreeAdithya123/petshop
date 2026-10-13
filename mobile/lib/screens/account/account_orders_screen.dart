import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../state/catalog_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/account/account_widgets.dart';
import '../../widgets/account/order_items.dart';
import '../../widgets/account_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

const _pageSize = 10;

class _OrderEntry {
  final String id;
  final String orderType;
  final String status;
  final num totalAmount;
  final num discountAmount;
  final DateTime? etaDate;
  final String? trackingNumber;
  final DateTime createdAt;

  const _OrderEntry({
    required this.id,
    required this.orderType,
    required this.status,
    required this.totalAmount,
    required this.discountAmount,
    required this.etaDate,
    required this.trackingNumber,
    required this.createdAt,
  });

  factory _OrderEntry.fromJson(Map<String, dynamic> json) => _OrderEntry(
        id: json['id'] as String,
        orderType: json['order_type'] as String? ?? '',
        status: json['status'] as String? ?? '',
        totalAmount: asNum(json['total_amount']),
        discountAmount: asNum(json['discount_amount']),
        etaDate: asDate(json['eta_date']),
        trackingNumber: json['tracking_number'] as String?,
        createdAt: asDate(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class _ReservationEntry {
  final String id;
  final String petId;
  final String orderId;
  final String status;
  final num depositAmount;
  final num finalSaleAmount;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const _ReservationEntry({
    required this.id,
    required this.petId,
    required this.orderId,
    required this.status,
    required this.depositAmount,
    required this.finalSaleAmount,
    required this.expiresAt,
    required this.createdAt,
  });

  factory _ReservationEntry.fromJson(Map<String, dynamic> json) => _ReservationEntry(
        id: json['id'] as String,
        petId: json['pet_id'] as String? ?? '',
        orderId: json['order_id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        depositAmount: asNum(json['deposit_amount']),
        finalSaleAmount: asNum(json['final_sale_amount']),
        expiresAt: asDate(json['expires_at']),
        createdAt: asDate(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get holdOpen => expiresAt != null && (status == 'pending' || status == 'confirmed');
}

class _GiftNote {
  final String recipientName;
  final String recipientContact;
  final String? message;
  final String? deliveryStatus;

  const _GiftNote({
    required this.recipientName,
    required this.recipientContact,
    required this.message,
    required this.deliveryStatus,
  });

  factory _GiftNote.fromJson(Map<String, dynamic> json) => _GiftNote(
        recipientName: json['recipient_name'] as String? ?? '',
        recipientContact: json['recipient_contact'] as String? ?? '',
        message: json['message'] as String?,
        deliveryStatus: json['delivery_status'] as String?,
      );
}

/// Mirrors src/pages/account/AccountOrders.jsx: the customer's orders (with
/// lazily loaded line items and a refund shortcut), gifts, and pet reservations.
class AccountOrdersScreen extends StatelessWidget {
  const AccountOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account/orders',
      title: 'My orders',
      subtitle: 'Your purchases, gifts and pet reservations. The shop confirms pickup details with you after you order.',
      builder: (context, profile) => _OrdersBody(key: ValueKey(profile.id), userId: profile.id),
    );
  }
}

class _OrdersBody extends ConsumerStatefulWidget {
  final String userId;
  const _OrdersBody({super.key, required this.userId});

  @override
  ConsumerState<_OrdersBody> createState() => _OrdersBodyState();
}

class _OrdersBodyState extends ConsumerState<_OrdersBody> {
  bool _loading = true;
  String? _error;
  List<_OrderEntry> _orders = const [];
  List<_ReservationEntry> _reservations = const [];
  Map<String, _GiftNote> _giftsByOrder = const {};
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _reload() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  Future<void> _load() async {
    final client = SupabaseService.client;
    final userId = widget.userId;
    try {
      final results = await Future.wait([
        client
            .from('orders')
            .select('id, order_type, status, total_amount, discount_amount, eta_date, tracking_number, created_at')
            .eq('customer_id', userId)
            .order('created_at', ascending: false),
        client
            .from('reservations')
            .select('id, pet_id, order_id, status, deposit_amount, final_sale_amount, expires_at, created_at')
            .eq('customer_id', userId)
            .order('created_at', ascending: false),
        client
            .from('gifts')
            .select('order_id, recipient_name, recipient_contact, message, delivery_status')
            .eq('sender_id', userId),
      ]);
      final orders = [
        for (final row in (results[0] as List).cast<Map<String, dynamic>>()) _OrderEntry.fromJson(row),
      ];
      final reservations = [
        for (final row in (results[1] as List).cast<Map<String, dynamic>>()) _ReservationEntry.fromJson(row),
      ];
      final gifts = <String, _GiftNote>{};
      for (final row in (results[2] as List).cast<Map<String, dynamic>>()) {
        final orderId = row['order_id'];
        if (orderId is String) gifts[orderId] = _GiftNote.fromJson(row);
      }
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _reservations = reservations;
        _giftsByOrder = gifts;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AccountLoadingNote();
    if (_error != null) return AccountErrorNote(message: _error!, onRetry: _reload);

    if (_orders.isEmpty && _reservations.isEmpty) {
      return EmptyState(
        title: 'No orders yet',
        description: 'When you reserve a pet or buy something, it will show up here.',
        action: ElevatedButton(
          onPressed: () => context.push('/pets'),
          child: const Text('Browse pets'),
        ),
      );
    }

    final catalog = ref.watch(catalogProvider);
    final catalogLoading = !catalog.hasValue && !catalog.hasError;
    final visible = _orders.take(_visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefreshHeading(title: 'Orders', onRefresh: _reload),
        const SizedBox(height: 12),
        if (_orders.isEmpty)
          Text('No orders yet.', style: AppTheme.body(color: AppColors.inkSoft))
        else ...[
          for (final order in visible) ...[
            _OrderCard(key: ValueKey(order.id), order: order, gift: _giftsByOrder[order.id]),
            const SizedBox(height: 12),
          ],
          if (_orders.length > _visibleCount)
            Center(
              child: OutlinedButton(
                onPressed: () => setState(() => _visibleCount += _pageSize),
                child: const Text('Show older orders'),
              ),
            ),
        ],
        const SizedBox(height: 28),
        const SectionTitle('Pet reservations'),
        const SizedBox(height: 12),
        if (_reservations.isEmpty)
          Text('No pet reservations yet.', style: AppTheme.body(color: AppColors.inkSoft))
        else
          for (final reservation in _reservations) ...[
            _ReservationCard(
              key: ValueKey(reservation.id),
              reservation: reservation,
              pet: catalog.value?.petById(reservation.petId),
              catalogLoading: catalogLoading,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _OrderCard extends StatefulWidget {
  final _OrderEntry order;
  final _GiftNote? gift;
  const _OrderCard({super.key, required this.order, required this.gift});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final gift = widget.gift;

    return CardBox(
      child: OrderItemsBuilder(
        orderId: order.id,
        enabled: _expanded,
        builder: (context, items, retry) {
          // Nothing to refund once we know none of the items belongs to a shop.
          final canRefund = isRefundableStatus(order.status) &&
              (items.status != OrderItemsStatus.ready || items.items.any((item) => item.shopId.isNotEmpty));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orderTypeLabel(order.orderType), style: AppTheme.body(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${formatOrderDate(order.createdAt)} · Order ${orderRef(order.id)}',
                          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: order.status),
                      const SizedBox(height: 6),
                      Text(
                        formatPrice(order.totalAmount),
                        style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
              if (gift != null) ...[
                const SizedBox(height: 12),
                _GiftNoteBox(gift: gift),
              ],
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                label: Text(_expanded ? 'Hide items' : 'View items'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
              ),
              if (_expanded) _ItemsList(state: items, onRetry: retry),
              if (order.discountAmount > 0 || order.etaDate != null || (order.trackingNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                if (order.discountAmount > 0)
                  Text(
                    'Discount applied: ${formatPrice(order.discountAmount)}',
                    style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                  ),
                if (order.etaDate != null)
                  Text(
                    'Expected by ${formatDate(order.etaDate!)}',
                    style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                  ),
                if ((order.trackingNumber ?? '').isNotEmpty)
                  Text(
                    'Tracking number: ${order.trackingNumber}',
                    style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                  ),
              ],
              if (canRefund) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/account/refunds?order=${order.id}'),
                    icon: const Icon(Icons.currency_exchange, size: 18),
                    label: const Text('Request refund'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  final OrderItemsState state;
  final VoidCallback onRetry;
  const _ItemsList({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (state.isBusy) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Loading items…', style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
      );
    }
    if (state.status == OrderItemsStatus.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(state.error, style: AppTheme.body(fontSize: 13.5, color: AppColors.error)),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No item details are available for this order.',
          style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < state.items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ItemRow(item: state.items[i]),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderLine item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (item.quantity > 1) 'Qty ${item.quantity}',
      if (item.shopName.isNotEmpty) 'Sold by ${item.shopName}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label.isEmpty ? 'Item' : item.label, style: AppTheme.body()),
                if (detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(detail, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatPrice(item.priceAtPurchase * item.quantity), style: AppTheme.body()),
        ],
      ),
    );
  }
}

class _GiftNoteBox extends StatelessWidget {
  final _GiftNote gift;
  const _GiftNoteBox({required this.gift});

  @override
  Widget build(BuildContext context) {
    final message = gift.message;
    final status = gift.deliveryStatus;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.card_giftcard_outlined, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Gift for ${gift.recipientName}',
                    style: AppTheme.body(fontSize: 14),
                    children: [
                      if (gift.recipientContact.isNotEmpty)
                        TextSpan(
                          text: ' (${gift.recipientContact})',
                          style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('“$message”', style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
          ],
          if (status != null && status.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Delivery: ${titleCase(status)}', style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final _ReservationEntry reservation;
  final Pet? pet;
  final bool catalogLoading;

  const _ReservationCard({
    super.key,
    required this.reservation,
    required this.pet,
    required this.catalogLoading,
  });

  @override
  Widget build(BuildContext context) {
    final pet = this.pet;
    // Reserved pets drop out of the public catalog, so fall back to the label
    // recorded on the order itself.
    return OrderItemsBuilder(
      orderId: reservation.orderId,
      enabled: pet == null && !catalogLoading && reservation.orderId.isNotEmpty,
      builder: (context, items, retry) {
        String? orderLabel;
        for (final item in items.items) {
          if (item.itemId == reservation.petId) {
            orderLabel = item.label;
            break;
          }
        }

        final Widget title;
        if (pet != null) {
          final petName = (pet.name ?? '').trim();
          title = InkWell(
            onTap: () => context.push('/pets/${pet.id}'),
            child: Text(
              petName.isEmpty ? pet.breed : '$petName · ${pet.breed}',
              style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          );
        } else {
          title = Text(
            (orderLabel != null && orderLabel.isNotEmpty) ? orderLabel : 'Pet',
            style: AppTheme.body(fontWeight: FontWeight.w600),
          );
        }

        return CardBox(
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
                        title,
                        const SizedBox(height: 2),
                        Text(
                          'Reserved ${formatOrderDate(reservation.createdAt)}',
                          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: reservation.status),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          text: formatPrice(reservation.depositAmount),
                          style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.accent),
                          children: [
                            TextSpan(
                              text: ' deposit',
                              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (reservation.finalSaleAmount > 0)
                Text(
                  'Final price: ${formatPrice(reservation.finalSaleAmount)}',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
              if (reservation.holdOpen)
                Text(
                  'Reservation held until ${formatOrderDate(reservation.expiresAt!)}',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
              if (reservation.orderId.isNotEmpty)
                Text(
                  'Order ${orderRef(reservation.orderId)}',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
            ],
          ),
        );
      },
    );
  }
}
