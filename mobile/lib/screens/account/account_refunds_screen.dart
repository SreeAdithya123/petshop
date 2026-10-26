import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/account/account_widgets.dart';
import '../../widgets/account/order_items.dart';
import '../../widgets/account_scaffold.dart';
import '../../widgets/ui_kit.dart';

const _reasons = ['Pet unwell', 'Not as described', 'Wrong item', 'Changed my mind', 'Other'];

class _RefundOrder {
  final String id;
  final String orderType;
  final num totalAmount;
  final DateTime createdAt;

  const _RefundOrder({
    required this.id,
    required this.orderType,
    required this.totalAmount,
    required this.createdAt,
  });

  factory _RefundOrder.fromJson(Map<String, dynamic> json) => _RefundOrder(
        id: json['id'] as String,
        orderType: json['order_type'] as String? ?? '',
        totalAmount: asNum(json['total_amount']),
        createdAt: asDate(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  String get title => '${orderTypeLabel(orderType)} · ${formatPrice(totalAmount)}';
  String get subtitle => '${formatDate(createdAt.toLocal())} · ${orderRef(id)}';
}

/// Mirrors src/pages/account/AccountRefunds.jsx: request a refund on one of
/// your orders (per shop) and follow the status of earlier requests.
class AccountRefundsScreen extends StatelessWidget {
  /// Order to preselect (the `?order=<id>` query parameter).
  final String? orderId;

  const AccountRefundsScreen({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account/refunds',
      title: 'Refunds',
      subtitle: 'Ask a shop for a refund on something you bought. Each shop reviews its own requests.',
      builder: (context, profile) => _RefundsBody(
        key: ValueKey(profile.id),
        userId: profile.id,
        initialOrderId: orderId,
      ),
    );
  }
}

class _RefundsBody extends StatefulWidget {
  final String userId;
  final String? initialOrderId;

  const _RefundsBody({super.key, required this.userId, required this.initialOrderId});

  @override
  State<_RefundsBody> createState() => _RefundsBodyState();
}

class _RefundsBodyState extends State<_RefundsBody> with AccountRefreshMixin<_RefundsBody> {
  bool _loading = true;
  bool _hasLoaded = false;
  String? _loadError;
  List<_RefundOrder> _orders = const [];
  List<RefundRequest> _refunds = const [];

  late String _selectedOrderId = widget.initialOrderId ?? '';
  String _selectedShopId = '';
  String _reason = '';
  final _notesController = TextEditingController();
  Map<String, String> _errors = {};
  String _formError = '';
  bool _submitting = false;
  String _success = '';

  OrderItemsState _items = OrderItemsState.idle;
  int _itemsGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_RefundsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialOrderId ?? '';
    if (oldWidget.initialOrderId != widget.initialOrderId && next.isNotEmpty) {
      _selectedOrderId = next;
      _selectedShopId = '';
      if (!_loading && _orderId.isNotEmpty) _startItems(_orderId);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // The preselected / chosen order, ignoring stale or unknown ids.
  String get _orderId => _orders.any((order) => order.id == _selectedOrderId) ? _selectedOrderId : '';

  List<ShopRefundGroup> get _groups => groupItemsByShop(_items.items);

  /// This order's earlier refund requests, keyed by shop.
  Map<String, RefundRequest> get _refundsForOrder {
    final orderId = _orderId;
    final result = <String, RefundRequest>{};
    if (orderId.isEmpty) return result;
    for (final refund in _refunds) {
      if (refund.orderId == orderId) result[refund.shopId] = refund;
    }
    return result;
  }

  List<ShopRefundGroup> get _openGroups {
    final requested = _refundsForOrder;
    return _groups.where((group) => !requested.containsKey(group.shopId)).toList();
  }

  String get _shopId {
    final open = _openGroups;
    if (open.any((group) => group.shopId == _selectedShopId)) return _selectedShopId;
    return open.length == 1 ? open.first.shopId : '';
  }

  @override
  Future<void> refreshAccountData() => _load();

  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _load();
  }

  Future<void> _load() async {
    final client = SupabaseService.client;
    try {
      final results = await Future.wait([
        client
            .from('orders')
            .select('id, order_type, status, total_amount, created_at')
            .eq('customer_id', widget.userId)
            .neq('status', 'cancelled')
            .order('created_at', ascending: false),
        client
            .from('refunds')
            .select('id, order_id, customer_id, shop_id, reason, notes, amount, status, item_label, created_at, resolved_at')
            .eq('customer_id', widget.userId)
            .order('created_at', ascending: false),
      ]);
      final orders = [
        for (final row in (results[0] as List).cast<Map<String, dynamic>>()) _RefundOrder.fromJson(row),
      ];
      final refunds = [
        for (final row in (results[1] as List).cast<Map<String, dynamic>>()) RefundRequest.fromJson(row),
      ];
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _refunds = refunds;
        _hasLoaded = true;
        _loading = false;
        _loadError = null;
        // Load the items of a preselected order once its id is known to be valid.
        final preselected = _orderId;
        if (preselected.isNotEmpty && _items.status == OrderItemsStatus.idle) _startItems(preselected);
      });
    } catch (error) {
      if (!mounted) return;
      if (_hasLoaded) {
        // A background refresh failed: keep what is on screen.
        showSnack(context, errorText(error), error: true);
        return;
      }
      setState(() {
        _loading = false;
        _loadError = errorText(error);
      });
    }
  }

  /// Starts loading [orderId]'s items. Callers run this inside setState (or
  /// where a rebuild follows anyway); the result arrives asynchronously.
  void _startItems(String orderId) {
    final generation = ++_itemsGeneration;
    _items = OrderItemsState.loading;
    _fetchItems(orderId, generation);
  }

  Future<void> _fetchItems(String orderId, int generation) async {
    OrderItemsState next;
    try {
      final items = await fetchOrderItems(orderId);
      next = OrderItemsState(OrderItemsStatus.ready, items: items);
    } catch (error) {
      next = OrderItemsState(OrderItemsStatus.error, error: errorText(error));
    }
    if (!mounted || generation != _itemsGeneration) return;
    setState(() => _items = next);
  }

  void _handleOrderChange(String? value) {
    final id = value ?? '';
    setState(() {
      _selectedOrderId = id;
      _selectedShopId = '';
      _errors = {..._errors}
        ..remove('order')
        ..remove('shop');
      _success = '';
      _formError = '';
      if (id.isEmpty) {
        _itemsGeneration++;
        _items = OrderItemsState.idle;
      } else {
        _startItems(id);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final orderId = _orderId;
    final shopId = _shopId;
    final notes = _notesController.text.trim();

    final errors = <String, String>{};
    if (orderId.isEmpty) {
      errors['order'] = 'Choose the order this refund is for.';
    } else if (shopId.isEmpty) {
      errors['shop'] = 'Choose what the refund is for.';
    } else if (_refundsForOrder.containsKey(shopId)) {
      errors['shop'] = "You've already requested a refund from this shop for this order.";
    }
    if (_reason.isEmpty) errors['reason'] = "Tell us why you're asking for a refund.";
    if (_reason == 'Other' && notes.isEmpty) errors['notes'] = 'Add a few words so the shop knows what happened.';
    setState(() {
      _formError = '';
      _success = '';
      _errors = errors;
    });
    if (errors.isNotEmpty) return;

    final group = _groups.firstWhere((candidate) => candidate.shopId == shopId);
    setState(() {
      _submitting = true;
      _selectedShopId = shopId;
    });
    try {
      // The server fills in the amount (that shop's total on the order) and
      // the pending status.
      await SupabaseService.client.from('refunds').insert({
        'order_id': orderId,
        'customer_id': widget.userId,
        'shop_id': shopId,
        'reason': _reason,
        'item_label': group.labels.join(', '),
        if (notes.isNotEmpty) 'notes': notes,
      });
    } catch (error) {
      if (!mounted) return;
      final duplicate = error is PostgrestException && error.code == '23505';
      setState(() {
        _submitting = false;
        _formError = duplicate
            ? "You've already requested a refund from this shop for this order."
            : errorText(error);
      });
      if (duplicate) await _load();
      return;
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _success = 'Refund request sent. The shop will review it, and you can follow its status below.';
      _selectedShopId = '';
      _reason = '';
      _errors = {};
      _notesController.clear();
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AccountLoadingNote();
    if (_loadError != null) return AccountErrorNote(message: _loadError!, onRetry: _retryLoad);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Request a refund'),
        const SizedBox(height: 12),
        if (_orders.isEmpty)
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You don't have any orders to request a refund for yet.",
                  style: AppTheme.body(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/account/orders'),
                  child: const Text('View your orders'),
                ),
              ],
            ),
          )
        else
          _buildForm(),
        const SizedBox(height: 32),
        RefreshHeading(title: 'Your refund requests', onRefresh: _load),
        const SizedBox(height: 12),
        if (_refunds.isEmpty)
          Text("You haven't requested any refunds yet.", style: AppTheme.body(color: AppColors.inkSoft))
        else
          for (final refund in _refunds) ...[
            _RefundCard(key: ValueKey(refund.id), refund: refund),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildForm() {
    final orderId = _orderId;
    final unknownPreselect = _selectedOrderId.isNotEmpty && orderId.isEmpty;
    final groups = _groups;
    final refundsForOrder = _refundsForOrder;
    final openGroups = _openGroups;
    final shopId = _shopId;
    // Nothing left to refund on this order (or none of its items belongs to a shop).
    final blocked = orderId.isNotEmpty && _items.status == OrderItemsStatus.ready && openGroups.isEmpty;

    return CardBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unknownPreselect) ...[
            const NoticeBox.warning(
              message: "We couldn't find that order among the ones you can ask a refund for. Pick one below.",
            ),
            const SizedBox(height: 16),
          ],
          const FormLabel('Order'),
          DropdownField<String>(
            value: orderId.isEmpty ? null : orderId,
            hint: 'Choose an order…',
            errorText: _errors['order'],
            itemHeight: 64,
            onChanged: _submitting ? null : _handleOrderChange,
            items: [
              for (final order in _orders)
                DropdownMenuItem<String>(
                  value: order.id,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.title,
                        style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        order.subtitle,
                        style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (orderId.isNotEmpty) ...[
            const SizedBox(height: 18),
            const FormLabel('What is the refund for?'),
            if (_items.isBusy)
              Text('Loading items…', style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft))
            else if (_items.status == OrderItemsStatus.error)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(_items.error, style: AppTheme.body(fontSize: 13.5, color: AppColors.error)),
                  TextButton(
                    onPressed: () => setState(() => _startItems(orderId)),
                    child: const Text('Try again'),
                  ),
                ],
              )
            else if (groups.isEmpty)
              Text(
                'None of the items on this order can be refunded through a shop.',
                style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
              )
            else ...[
              Text(
                'Refunds are handled by each shop separately. If your order has items from more than one shop, '
                'send one request per shop.',
                style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 10),
              for (final group in groups) ...[
                _ShopOption(
                  group: group,
                  existing: refundsForOrder[group.shopId],
                  selected: shopId == group.shopId,
                  onTap: () => setState(() {
                    _selectedShopId = group.shopId;
                    _errors = {..._errors}..remove('shop');
                  }),
                ),
                const SizedBox(height: 8),
              ],
              if (openGroups.isEmpty)
                Text(
                  "You've already requested a refund from every shop on this order.",
                  style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                ),
              if (_errors['shop'] != null)
                Text(_errors['shop']!, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
            ],
          ],
          const SizedBox(height: 18),
          const FormLabel('Reason'),
          DropdownField<String>(
            value: _reason.isEmpty ? null : _reason,
            hint: 'Choose a reason…',
            errorText: _errors['reason'],
            onChanged: _submitting
                ? null
                : (value) => setState(() {
                      _reason = value ?? '';
                      _errors = {..._errors}
                        ..remove('reason')
                        ..remove('notes');
                    }),
            items: [
              for (final reason in _reasons) DropdownMenuItem<String>(value: reason, child: Text(reason)),
            ],
          ),
          const SizedBox(height: 18),
          FormLabel('Notes', optional: _reason != 'Other'),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              helperText: 'Anything the shop should know.',
              errorText: _errors['notes'],
            ),
            onChanged: (_) {
              if (_errors.containsKey('notes')) setState(() => _errors = {..._errors}..remove('notes'));
            },
          ),
          if (_formError.isNotEmpty) ...[
            const SizedBox(height: 14),
            NoticeBox.error(message: _formError),
          ],
          if (_success.isNotEmpty) ...[
            const SizedBox(height: 14),
            NoticeBox(message: _success, color: AppColors.trust, icon: Icons.check_circle_outline),
          ],
          const SizedBox(height: 18),
          LoadingButton(
            label: 'Send refund request',
            loading: _submitting,
            onPressed: blocked ? null : _submit,
            expand: true,
          ),
        ],
      ),
    );
  }
}

/// Selectable "radio" card for one shop's part of an order.
class _ShopOption extends StatelessWidget {
  final ShopRefundGroup group;
  final RefundRequest? existing;
  final bool selected;
  final VoidCallback onTap;

  const _ShopOption({
    required this.group,
    required this.existing,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final existing = this.existing;
    final locked = existing != null;
    final borderColor = selected && !locked ? AppColors.primary : AppColors.border;

    return Material(
      color: locked
          ? AppColors.paper
          : (selected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked ? null : onTap,
        child: Opacity(
          opacity: locked ? 0.75 : 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected && !locked ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected && !locked ? AppColors.primary : AppColors.inkSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.shopName.isEmpty ? 'Shop' : group.shopName,
                        style: AppTheme.body(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.labels.join(', '),
                        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                      ),
                      if (existing != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              'Refund already requested',
                              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                            ),
                            StatusBadge(status: existing.status),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(formatPrice(group.total), style: AppTheme.body(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RefundCard extends StatelessWidget {
  final RefundRequest refund;
  const _RefundCard({super.key, required this.refund});

  @override
  Widget build(BuildContext context) {
    final label = refund.itemLabel ?? '';
    final notes = refund.notes ?? '';

    return CardBox(
      child: OrderItemsBuilder(
        orderId: refund.orderId,
        builder: (context, items, retry) {
          String shopName = '';
          for (final item in items.items) {
            if (item.shopId == refund.shopId) {
              shopName = item.shopName;
              break;
            }
          }

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
                        Text(
                          label.isEmpty ? 'Refund request' : label,
                          style: AppTheme.body(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        if (shopName.isNotEmpty)
                          Text(shopName, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                        TextButton(
                          onPressed: () => context.go('/account/orders'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 40),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text(
                            'Order ${orderRef(refund.orderId)}',
                            style: AppTheme.body(fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: refund.status),
                      if (refund.amount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          formatPrice(refund.amount),
                          style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600, color: kAccountPriceColor),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Reason: ${refund.reason}', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
              if (notes.isNotEmpty)
                Text('“$notes”', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
              Text(
                'Requested ${formatOrderDate(refund.createdAt)}',
                style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              ),
              if (refund.resolvedAt != null)
                Text(
                  'Resolved ${formatOrderDate(refund.resolvedAt!)}',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
            ],
          );
        },
      ),
    );
  }
}
