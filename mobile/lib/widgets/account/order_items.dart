import 'package:flutter/material.dart';

import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../ui_kit.dart';

/// Line items of a customer's own orders, resolved server-side by the
/// `order_items_detailed` RPC (labels + shop *names*, never contact details).
/// Mirrors fetchOrderItems / useOrderItems in src/components/account/accountHelpers.js.

// Items on a placed order never change, so one request per order is shared by
// every screen that needs them (orders, refunds). Failures are dropped so a
// retry refetches.
final Map<String, Future<List<OrderLine>>> _orderItemsRequests = {};

Future<List<OrderLine>> _requestOrderItems(String orderId) async {
  final data = await SupabaseService.client.rpc('order_items_detailed', params: {'p_order_id': orderId});
  final rows = data is List ? data : const [];
  return [
    for (final row in rows)
      if (row is Map) OrderLine.fromJson(Map<String, dynamic>.from(row)),
  ];
}

/// Forgets every cached request: after signing out (so the next account never
/// sees a previous one's items) and on pull-to-refresh.
void clearOrderItemsCache() => _orderItemsRequests.clear();

Future<List<OrderLine>> fetchOrderItems(String orderId) {
  final cached = _orderItemsRequests[orderId];
  if (cached != null) return cached;
  final request = _requestOrderItems(orderId);
  _orderItemsRequests[orderId] = request;
  request.then<void>((_) {}, onError: (Object _) {
    _orderItemsRequests.remove(orderId);
  });
  return request;
}

enum OrderItemsStatus { idle, loading, ready, error }

class OrderItemsState {
  final OrderItemsStatus status;
  final List<OrderLine> items;
  final String error;

  const OrderItemsState(this.status, {this.items = const [], this.error = ''});

  static const idle = OrderItemsState(OrderItemsStatus.idle);
  static const loading = OrderItemsState(OrderItemsStatus.loading);

  bool get isBusy => status == OrderItemsStatus.idle || status == OrderItemsStatus.loading;
}

/// One entry per shop on an order (refunds are requested per shop).
class ShopRefundGroup {
  final String shopId;
  final String shopName;
  final List<String> labels = [];
  num total = 0;

  ShopRefundGroup(this.shopId, this.shopName);
}

/// Groups [items] by shop; items with no shop are skipped.
List<ShopRefundGroup> groupItemsByShop(List<OrderLine> items) {
  final groups = <String, ShopRefundGroup>{};
  for (final item in items) {
    if (item.shopId.isEmpty) continue;
    final group = groups.putIfAbsent(item.shopId, () => ShopRefundGroup(item.shopId, item.shopName));
    group.labels.add(item.label.isEmpty ? 'Item' : item.label);
    group.total += item.priceAtPurchase * item.quantity;
  }
  return groups.values.toList();
}

/// Loads the items of [orderId] (when [enabled]) and hands the current
/// [OrderItemsState] to [builder]. `retry` refetches after an error.
class OrderItemsBuilder extends StatefulWidget {
  final String orderId;
  final bool enabled;
  final Widget Function(BuildContext context, OrderItemsState state, VoidCallback retry) builder;

  const OrderItemsBuilder({
    super.key,
    required this.orderId,
    this.enabled = true,
    required this.builder,
  });

  @override
  State<OrderItemsBuilder> createState() => _OrderItemsBuilderState();
}

class _OrderItemsBuilderState extends State<OrderItemsBuilder> {
  OrderItemsState _state = OrderItemsState.idle;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(OrderItemsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId || oldWidget.enabled != widget.enabled) {
      _sync();
    }
  }

  /// Called from initState/didUpdateWidget, where a rebuild follows anyway.
  void _sync() {
    final generation = ++_generation;
    if (widget.orderId.isEmpty || !widget.enabled) {
      _state = OrderItemsState.idle;
      return;
    }
    _state = OrderItemsState.loading;
    _fetch(generation);
  }

  Future<void> _fetch(int generation) async {
    OrderItemsState next;
    try {
      final items = await fetchOrderItems(widget.orderId);
      next = OrderItemsState(OrderItemsStatus.ready, items: items);
    } catch (error) {
      next = OrderItemsState(OrderItemsStatus.error, error: errorText(error));
    }
    if (!mounted || generation != _generation) return;
    setState(() => _state = next);
  }

  void _retry() {
    final generation = ++_generation;
    setState(() => _state = OrderItemsState.loading);
    _fetch(generation);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _state, _retry);
}
