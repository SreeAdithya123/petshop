import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';

bool _isPetOrder(String orderType) => orderType == 'pet_reservation' || orderType == 'gift';

/// Plain-words explanation of where an order stands. Nothing ships: the shop
/// arranges pickup and the customer pays in person.
String orderTimelineText(String status, String orderType) {
  switch (status) {
    case 'pending':
      return '${_isPetOrder(orderType) ? 'Reserved' : 'Placed'} — the shop will contact you to arrange pickup; pay in person.';
    case 'paid':
      return 'Paid — the shop has received your payment and will hand your order over at pickup.';
    case 'fulfilled':
      return "Handed over — pickup is complete. If something isn't right, you can request a refund.";
    case 'cancelled':
      return 'Cancelled — the items went back to the shop. If you had already paid in person, message the shop about getting your money back.';
    default:
      return titleCase(status);
  }
}

enum _DotState { done, next, todo, ended }

/// Reserved / Placed -> Paid -> Handed over, or a terminal "Cancelled".
class OrderTimeline extends StatelessWidget {
  final String status;
  final String orderType;
  const OrderTimeline({super.key, required this.status, required this.orderType});

  @override
  Widget build(BuildContext context) {
    final first = _isPetOrder(orderType) ? 'Reserved' : 'Placed';
    final cancelled = status == 'cancelled';
    final labels = cancelled ? [first, 'Cancelled'] : [first, 'Paid', 'Handed over'];
    final reached = cancelled ? 1 : (const {'pending': 0, 'paid': 1, 'fulfilled': 2}[status] ?? 0);

    _DotState stateAt(int index) {
      if (cancelled) return index == 0 ? _DotState.done : _DotState.ended;
      if (index <= reached) return _DotState.done;
      return index == reached + 1 ? _DotState.next : _DotState.todo;
    }

    Widget connector(bool visible, bool active) => Expanded(
          child: Container(
            height: 2,
            color: !visible ? Colors.transparent : (active ? AppColors.primary : AppColors.border),
          ),
        );

    // The sentence under the stepper carries the meaning for screen readers.
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      connector(index > 0, index <= reached),
                      _Dot(index: index, state: stateAt(index)),
                      connector(index < labels.length - 1, index < reached),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      fontSize: 11.5,
                      fontWeight: stateAt(index) == _DotState.done || stateAt(index) == _DotState.ended
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: stateAt(index) == _DotState.ended
                          ? AppColors.error
                          : (stateAt(index) == _DotState.done ? AppColors.ink : AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int index;
  final _DotState state;
  const _Dot({required this.index, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final BoxBorder? border;
    final Widget child;
    switch (state) {
      case _DotState.done:
        fill = AppColors.primary;
        border = null;
        child = const Icon(Icons.check, size: 14, color: Colors.white);
      case _DotState.ended:
        fill = AppColors.error;
        border = null;
        child = const Icon(Icons.close, size: 14, color: Colors.white);
      case _DotState.next:
        fill = AppColors.surface;
        border = Border.all(color: AppColors.primary, width: 2);
        child = Text('${index + 1}', style: AppTheme.body(fontSize: 11.5, color: AppColors.primary));
      case _DotState.todo:
        fill = AppColors.surface;
        border = Border.all(color: AppColors.border);
        child = Text('${index + 1}', style: AppTheme.body(fontSize: 11.5, color: AppColors.inkSoft));
    }
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: border),
      child: child,
    );
  }
}
