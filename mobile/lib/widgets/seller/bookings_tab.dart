import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/service_models.dart';
import '../shared_widgets.dart';
import '../ui_kit.dart';
import 'booking_card.dart';
import 'seller_common.dart';

const _bookingFilters = <StatusFilter>[
  StatusFilter('pending', 'Pending'),
  StatusFilter('confirmed', 'Confirmed'),
  StatusFilter('completed', 'Completed'),
  StatusFilter('cancelled', 'Cancelled'),
  StatusFilter('all', 'All'),
];

String _statusOf(ServiceBooking booking) => booking.status;

/// "Bookings" tab: customer bookings of this shop's services, newest first.
/// Mirrors src/components/seller/BookingsTab.jsx.
class BookingsTab extends StatefulWidget {
  final bool readOnly;
  final SellerQuery<WithCustomers<ServiceBooking>> query;

  const BookingsTab({super.key, required this.readOnly, required this.query});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  String? _filter;
  int _limit = kPageSize;

  @override
  Widget build(BuildContext context) {
    return SellerQueryPanel<WithCustomers<ServiceBooking>>(
      query: widget.query,
      what: 'bookings',
      builder: (context, data) {
        final rows = data.rows;
        // Open on "Pending" when there is something to act on, otherwise show everything.
        final pendingCount = rows.where((row) => row.status == 'pending').length;
        final active = _filter ?? (pendingCount > 0 ? 'pending' : 'all');
        final visible = applyStatusFilter(_bookingFilters, active, rows, _statusOf);
        final shown = math.min(_limit, visible.length);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilterChipBar<String>(
              options: filterOptions(_bookingFilters, rows, _statusOf),
              selected: active,
              onSelected: (value) => setState(() {
                _filter = value;
                _limit = kPageSize;
              }),
            ),
            const SizedBox(height: 16),
            if (data.customersError != null) ...[
              NoticeBox.error(message: "Couldn't load customer names: ${data.customersError}"),
              const SizedBox(height: 12),
            ],
            if (visible.isEmpty)
              CardBox(
                child: EmptyState(
                  title: rows.isEmpty ? 'No bookings yet' : 'Nothing here',
                  description: rows.isEmpty
                      ? 'When customers book one of your approved services, it shows up here.'
                      : 'No bookings match this filter.',
                ),
              )
            else ...[
              for (final booking in visible.take(shown))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookingCard(
                    key: ValueKey(booking.id),
                    booking: booking,
                    customer: data.customers[booking.customerId],
                    readOnly: widget.readOnly,
                    onChanged: widget.query.reload,
                  ),
                ),
              LoadMoreButton(
                shown: shown,
                total: visible.length,
                onPressed: () => setState(() => _limit += kPageSize),
              ),
            ],
          ],
        );
      },
    );
  }
}
