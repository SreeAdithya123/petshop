import 'package:flutter/material.dart';

import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../shared_widgets.dart';
import '../ui_kit.dart';
import 'service_support.dart';

const _bookingColumns =
    'id, service_id, shop_id, customer_id, pet_id, booking_date, booking_time, delivery_mode, video_room_url, '
    'status, price_at_booking, notes, created_at, service_name, service_category, shop_name';

/// The signed-in customer's own service bookings, newest first, plus the one
/// action a customer may take on them (cancel). Mirrors useServiceBookings.js.
/// [category] narrows the list (e.g. 'vet' for consultations).
class ServiceBookingsController extends ChangeNotifier {
  ServiceBookingsController({required this.userId, this.category}) {
    load();
  }

  final String userId;
  final String? category;

  List<ServiceBooking> bookings = const [];
  bool loading = true;
  String? error;
  String? busyId;
  String? actionError;

  bool _disposed = false;
  int _generation = 0;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// [silent] keeps the current rows on screen instead of flashing a spinner.
  Future<void> load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent || bookings.isEmpty) loading = true;
    error = null;
    _notify();
    try {
      var query = SupabaseService.client.from('service_bookings').select(_bookingColumns).eq('customer_id', userId);
      final categoryFilter = category;
      if (categoryFilter != null) query = query.eq('service_category', categoryFilter);
      final rows = await query.order('created_at', ascending: false);
      if (_disposed || generation != _generation) return;
      bookings = rows.map(ServiceBooking.fromJson).toList();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = errorText(e);
    }
    loading = false;
    _notify();
  }

  Future<void> cancel(String id) async {
    busyId = id;
    actionError = null;
    _notify();
    try {
      // .select() so a row filtered out by RLS / the status guard is noticed.
      final rows = await SupabaseService.client
          .from('service_bookings')
          .update({'status': 'cancelled'})
          .eq('id', id)
          .inFilter('status', ['pending', 'confirmed'])
          .select('id');
      if (rows.isEmpty) actionError = "That didn't go through — its status may have changed.";
    } catch (e) {
      actionError = errorText(e);
    }
    busyId = null;
    if (_disposed) return;
    await load(silent: true);
  }
}

/// Own service bookings with status, join link and cancel (mirrors BookingList.jsx).
class BookingsList extends StatelessWidget {
  final ServiceBookingsController controller;
  final String emptyMessage;

  const BookingsList({super.key, required this.controller, this.emptyMessage = 'No bookings yet.'});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final bookings = controller.bookings;
        if (controller.loading && bookings.isEmpty) {
          return const LoadingView();
        }
        final error = controller.error;
        final actionError = controller.actionError;
        if (bookings.isEmpty) {
          if (error != null) {
            return InlineErrorNotice(message: error, onRetry: () => controller.load());
          }
          return SectionEmptyBox(emptyMessage);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null) ...[
              InlineErrorNotice(message: error, onRetry: () => controller.load()),
              const SizedBox(height: 12),
            ],
            if (actionError != null) ...[
              Text(actionError, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
              const SizedBox(height: 12),
            ],
            for (final booking in bookings) ...[
              _BookingCard(
                booking: booking,
                busy: controller.busyId == booking.id,
                onCancel: () => _confirmCancel(context, booking),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmCancel(BuildContext context, ServiceBooking booking) async {
    final confirmed = await confirmAction(
      context,
      title: 'Cancel this booking?',
      message: 'This frees up the slot. You can book again any time.',
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (confirmed) await controller.cancel(booking.id);
  }
}

class _BookingCard extends StatelessWidget {
  final ServiceBooking booking;
  final bool busy;
  final VoidCallback onCancel;

  const _BookingCard({required this.booking, required this.busy, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final mode = deliveryModeFor(booking.deliveryMode);
    final canCancel = booking.status == 'pending' || booking.status == 'confirmed';
    final videoUri = booking.status == 'confirmed' ? safeExternalUri(booking.videoRoomUrl) : null;
    final shopName = booking.shopName?.trim() ?? '';
    final notes = booking.notes?.trim() ?? '';
    final waitingForLink = booking.status == 'confirmed' && booking.deliveryMode == 'video' && videoUri == null;
    final time = formatClock(booking.bookingTime);

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (booking.serviceName ?? '').isEmpty ? 'Service' : booking.serviceName!,
                  style: AppTheme.body(fontSize: 15.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: booking.status),
            ],
          ),
          if (shopName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('by $shopName', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _MetaItem(
                icon: Icons.calendar_today_outlined,
                text: time.isEmpty ? formatDate(booking.bookingDate) : '${formatDate(booking.bookingDate)} at $time',
              ),
              _MetaItem(icon: mode.icon, text: mode.label),
              if (booking.priceAtBooking > 0)
                Text(
                  formatPrice(booking.priceAtBooking),
                  style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ],
          if (waitingForLink) ...[
            const SizedBox(height: 10),
            Text(
              "The clinic hasn't added a video link yet — check back soon.",
              style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ],
          if (videoUri != null || canCancel) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (videoUri != null)
                  ElevatedButton.icon(
                    onPressed: () => openVideoLink(context, videoUri),
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: const Text('Join video consult'),
                  ),
                if (canCancel)
                  OutlinedButton(
                    onPressed: busy ? null : onCancel,
                    child: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.inkSoft),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft))),
      ],
    );
  }
}
