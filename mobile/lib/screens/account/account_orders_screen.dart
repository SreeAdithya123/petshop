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
import '../../widgets/account/order_timeline.dart';
import '../../widgets/account_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/ui_kit.dart';

const _pageSize = 10;

/// Rows of an order beyond this many are folded behind "Show all".
const _collapsedItemCount = 3;

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

/// One page of orders plus the gift notes that belong to them.
class _OrdersPage {
  final List<_OrderEntry> items;
  final bool hasMore;
  final Map<String, _GiftNote> gifts;
  const _OrdersPage(this.items, this.hasMore, this.gifts);
}

class _ReservationsPage {
  final List<_ReservationEntry> items;
  final bool hasMore;
  const _ReservationsPage(this.items, this.hasMore);
}

/// Deep link to the support screen with the shop and order pre-selected.
String _supportLink(String shopId, String orderId) =>
    '/support?shop=${Uri.encodeQueryComponent(shopId)}&order=${Uri.encodeQueryComponent(orderId)}';

/// Mirrors src/pages/account/AccountOrders.jsx: the customer's orders (with
/// their items, a refund shortcut and cancel while still pending), gifts, and
/// pet reservations. Everything is picked up and paid for in person, so each
/// order can open a support conversation with its shop.
class AccountOrdersScreen extends StatelessWidget {
  const AccountOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account/orders',
      title: 'My orders',
      subtitle: 'Your purchases, gifts and pet reservations. You pick up and pay in person: '
          'message the shop from an order to arrange it.',
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

class _OrdersBodyState extends ConsumerState<_OrdersBody> with AccountRefreshMixin<_OrdersBody> {
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  int _generation = 0;

  List<_OrderEntry> _orders = const [];
  Map<String, _GiftNote> _giftsByOrder = const {};
  bool _moreOrders = false;
  bool _loadingMoreOrders = false;
  String? _moreOrdersError;

  List<_ReservationEntry> _reservations = const [];
  bool _moreReservations = false;
  bool _loadingMoreReservations = false;
  String? _moreReservationsError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> refreshAccountData() {
    clearOrderItemsCache();
    return _load();
  }

  void _reload() {
    clearOrderItemsCache();
    _load(showSkeleton: true);
  }

  Future<_OrdersPage> _fetchOrders(int offset) async {
    final client = SupabaseService.client;
    // One row more than a page tells us whether there is another page.
    final rows = await client
        .from('orders')
        .select('id, order_type, status, total_amount, discount_amount, eta_date, tracking_number, created_at')
        .eq('customer_id', widget.userId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + _pageSize);
    final page = [for (final row in rows.take(_pageSize)) _OrderEntry.fromJson(row)];

    final gifts = <String, _GiftNote>{};
    if (page.isNotEmpty) {
      try {
        final giftRows = await client
            .from('gifts')
            .select('order_id, recipient_name, recipient_contact, message, delivery_status')
            .eq('sender_id', widget.userId)
            .inFilter('order_id', [for (final order in page) order.id]);
        for (final row in giftRows) {
          final orderId = row['order_id'];
          if (orderId is String) gifts[orderId] = _GiftNote.fromJson(row);
        }
      } catch (_) {
        // The gift note is a nicety: show the orders without it rather than not at all.
      }
    }
    return _OrdersPage(page, rows.length > _pageSize, gifts);
  }

  Future<_ReservationsPage> _fetchReservations(int offset) async {
    final rows = await SupabaseService.client
        .from('reservations')
        .select('id, pet_id, order_id, status, deposit_amount, final_sale_amount, expires_at, created_at')
        .eq('customer_id', widget.userId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + _pageSize);
    return _ReservationsPage(
      [for (final row in rows.take(_pageSize)) _ReservationEntry.fromJson(row)],
      rows.length > _pageSize,
    );
  }

  /// Loads the first page of everything. [showSkeleton] swaps the screen for
  /// placeholders (first load, retry); a pull-to-refresh keeps what is shown.
  Future<void> _load({bool showSkeleton = false}) async {
    final generation = ++_generation;
    if (showSkeleton) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([_fetchOrders(0), _fetchReservations(0)]);
      if (!mounted || generation != _generation) return;
      final orders = results[0] as _OrdersPage;
      final reservations = results[1] as _ReservationsPage;
      setState(() {
        _orders = orders.items;
        _giftsByOrder = orders.gifts;
        _moreOrders = orders.hasMore;
        _loadingMoreOrders = false;
        _moreOrdersError = null;
        _reservations = reservations.items;
        _moreReservations = reservations.hasMore;
        _loadingMoreReservations = false;
        _moreReservationsError = null;
        _hasLoaded = true;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      if (_hasLoaded) {
        // A refresh failed: keep the orders that are already on screen.
        setState(() => _loading = false);
        showSnack(context, errorText(error), error: true);
        return;
      }
      setState(() {
        _loading = false;
        _error = errorText(error);
      });
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_loadingMoreOrders || !_moreOrders) return;
    final generation = _generation;
    setState(() {
      _loadingMoreOrders = true;
      _moreOrdersError = null;
    });
    try {
      final page = await _fetchOrders(_orders.length);
      if (!mounted || generation != _generation) return;
      final known = {for (final order in _orders) order.id};
      setState(() {
        _orders = [..._orders, for (final order in page.items) if (!known.contains(order.id)) order];
        _giftsByOrder = {..._giftsByOrder, ...page.gifts};
        _moreOrders = page.hasMore;
        _loadingMoreOrders = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMoreOrders = false;
        _moreOrdersError = errorText(error);
      });
    }
  }

  Future<void> _loadMoreReservations() async {
    if (_loadingMoreReservations || !_moreReservations) return;
    final generation = _generation;
    setState(() {
      _loadingMoreReservations = true;
      _moreReservationsError = null;
    });
    try {
      final page = await _fetchReservations(_reservations.length);
      if (!mounted || generation != _generation) return;
      final known = {for (final reservation in _reservations) reservation.id};
      setState(() {
        _reservations = [
          ..._reservations,
          for (final reservation in page.items)
            if (!known.contains(reservation.id)) reservation,
        ];
        _moreReservations = page.hasMore;
        _loadingMoreReservations = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMoreReservations = false;
        _moreReservationsError = errorText(error);
      });
    }
  }

  /// An order changed on the server (cancelled): reload, and refresh the
  /// catalog because its pets are available again.
  Future<void> _afterOrderChanged() {
    ref.invalidate(catalogProvider);
    return _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AccountLoadingNote(count: 3, itemHeight: 140);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefreshHeading(title: 'Orders', onRefresh: () => _load()),
        const SizedBox(height: 12),
        if (_orders.isEmpty)
          Text('No orders yet.', style: AppTheme.body(color: AppColors.inkSoft))
        else ...[
          for (final order in _orders) ...[
            _OrderCard(
              key: ValueKey(order.id),
              order: order,
              gift: _giftsByOrder[order.id],
              onChanged: _afterOrderChanged,
            ),
            const SizedBox(height: 12),
          ],
          if (_moreOrders)
            LoadMoreButton(
              label: 'Load more orders',
              loading: _loadingMoreOrders,
              error: _moreOrdersError,
              onPressed: _loadMoreOrders,
            ),
        ],
        const SizedBox(height: 28),
        const SectionTitle('Pet reservations'),
        const SizedBox(height: 12),
        if (_reservations.isEmpty)
          Text('No pet reservations yet.', style: AppTheme.body(color: AppColors.inkSoft))
        else ...[
          for (final reservation in _reservations) ...[
            _ReservationCard(
              key: ValueKey(reservation.id),
              reservation: reservation,
              pet: catalog.value?.petById(reservation.petId),
              catalogLoading: catalogLoading,
            ),
            const SizedBox(height: 12),
          ],
          if (_moreReservations)
            LoadMoreButton(
              label: 'Load more reservations',
              loading: _loadingMoreReservations,
              error: _moreReservationsError,
              onPressed: _loadMoreReservations,
            ),
        ],
      ],
    );
  }
}

class _OrderCard extends StatefulWidget {
  final _OrderEntry order;
  final _GiftNote? gift;

  /// Called after the order changed on the server so the list can reload.
  final Future<void> Function() onChanged;

  const _OrderCard({super.key, required this.order, required this.gift, required this.onChanged});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _showAllItems = false;
  bool _cancelling = false;
  String _error = '';

  Future<void> _cancelOrder() async {
    if (_cancelling) return;
    final order = widget.order;
    final confirmed = await confirmAction(
      context,
      title: 'Cancel this order?',
      message: "Order ${orderRef(order.id)} will be cancelled and its items released back to the shop. "
          "This can't be undone.",
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep order',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _cancelling = true;
      _error = '';
    });
    try {
      await SupabaseService.client.rpc('cancel_my_order', params: {'p_order_id': order.id});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = rpcErrorText(error);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _cancelling = false);
    showSnack(context, 'Order cancelled.');
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final gift = widget.gift;

    return CardBox(
      child: OrderItemsBuilder(
        orderId: order.id,
        builder: (context, items, retry) {
          final ready = items.status == OrderItemsStatus.ready;
          final shopGroups = ready ? groupItemsByShop(items.items) : const <ShopRefundGroup>[];
          // Nothing to refund once we know none of the items belongs to a shop.
          final canRefund = isRefundableStatus(order.status) && (!ready || shopGroups.isNotEmpty);

          final actions = <Widget>[
            for (final group in shopGroups)
              OutlinedButton.icon(
                onPressed: () => context.push(_supportLink(group.shopId, order.id)),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(
                  shopGroups.length == 1 || group.shopName.isEmpty ? 'Message the shop' : 'Message ${group.shopName}',
                ),
              ),
            // No shop to address (items still loading is excluded): ask support instead.
            if (shopGroups.isEmpty && !items.isBusy)
              OutlinedButton.icon(
                onPressed: () => context.push('/support?order=${Uri.encodeQueryComponent(order.id)}'),
                icon: const Icon(Icons.support_agent_outlined, size: 18),
                label: const Text('Ask about this order'),
              ),
            if (canRefund)
              OutlinedButton.icon(
                onPressed: () => context.push('/account/refunds?order=${order.id}'),
                icon: const Icon(Icons.currency_exchange, size: 18),
                label: const Text('Request refund'),
              ),
            if (order.status == 'pending')
              OutlinedButton.icon(
                onPressed: _cancelling ? null : _cancelOrder,
                icon: _cancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: Text(_cancelling ? 'Cancelling…' : 'Cancel order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                ),
              ),
          ];

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
                        style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600, color: kAccountPriceColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OrderTimeline(status: order.status, orderType: order.orderType),
              const SizedBox(height: 10),
              Text(
                orderTimelineText(order.status, order.orderType),
                style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
              ),
              if (gift != null) ...[
                const SizedBox(height: 12),
                _GiftNoteBox(gift: gift),
              ],
              const SizedBox(height: 12),
              _buildItems(items, retry),
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
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                NoticeBox.error(message: _error),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildItems(OrderItemsState state, VoidCallback retry) {
    if (state.isBusy) {
      return Semantics(
        label: 'Loading items',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 14),
            SizedBox(height: 8),
            SkeletonBox(width: 140, height: 14),
          ],
        ),
      );
    }
    if (state.status == OrderItemsStatus.error) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(state.error, style: AppTheme.body(fontSize: 13.5, color: AppColors.error)),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      );
    }
    if (state.items.isEmpty) {
      return Text(
        'No item details are available for this order.',
        style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
      );
    }

    final items = state.items;
    final folded = items.length > _collapsedItemCount && !_showAllItems;
    final visible = folded ? items.take(_collapsedItemCount).toList() : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ItemRow(item: visible[i]),
              ],
            ],
          ),
        ),
        if (items.length > _collapsedItemCount)
          TextButton(
            onPressed: () => setState(() => _showAllItems = !_showAllItems),
            child: Text(_showAllItems ? 'Show fewer items' : 'Show all ${items.length} items'),
          ),
      ],
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
          title = TextButton(
            onPressed: () => context.push('/pets/${pet.id}'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 40),
              alignment: Alignment.centerLeft,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: Text(
              petName.isEmpty ? pet.breed : '$petName · ${pet.breed}',
              textAlign: TextAlign.start,
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
                      if (reservation.depositAmount > 0) ...[
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            text: formatPrice(reservation.depositAmount),
                            style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600, color: kAccountPriceColor),
                            children: [
                              TextSpan(
                                text: ' deposit',
                                style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
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
