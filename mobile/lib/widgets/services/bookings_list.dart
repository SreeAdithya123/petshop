import 'package:flutter/material.dart';

import '../../core/async_utils.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../skeletons.dart';
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

  /// [silent] keeps the current rows on screen instead of flashing a skeleton.
  Future<void> load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent || bookings.isEmpty) loading = true;
    error = null;
    _notify();
    try {
      var query = SupabaseService.client.from('service_bookings').select(_bookingColumns).eq('customer_id', userId);
      final categoryFilter = category;
      if (categoryFilter != null) query = query.eq('service_category', categoryFilter);
      final rows = await withTimeout(query.order('created_at', ascending: false));
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
    // One change at a time: ignore a second tap while a request is in flight.
    if (busyId != null) return;
    busyId = id;
    actionError = null;
    _notify();
    try {
      // .select() so a row filtered out by RLS / the status guard is noticed.
      final rows = await withTimeout(
        SupabaseService.client
            .from('service_bookings')
            .update({'status': 'cancelled'})
            .eq('id', id)
            .inFilter('status', ['pending', 'confirmed'])
            .select('id'),
      );
      if (rows.isEmpty) actionError = kStatusChangedMessage;
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
          return const ListSkeleton(count: 2, itemHeight: 120);
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
              Semantics(
                liveRegion: true,
                child: Text(actionError, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
              ),
              const SizedBox(height: 12),
            ],
            for (final booking in bookings) ...[
              _BookingCard(
                booking: booking,
                busy: controller.busyId == booking.id,
                // Another cancel is in flight: keep every cancel button idle.
                locked: controller.busyId != null,
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
  final bool locked;
  final VoidCallback onCancel;

  const _BookingCard({required this.booking, required this.busy, required this.locked, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final mode = deliveryModeFor(booking.deliveryMode);
    final confirmed = booking.status == 'confirmed';
    final isVideo = booking.deliveryMode == 'video';
    final canCancel = booking.status == 'pending' || confirmed;
    // The join button needs both: the clinic has confirmed AND it saved a link
    // that is a plain http(s) URL (isSafeWebLink inside safeExternalUri).
    final videoUri = confirmed ? safeExternalUri(booking.videoRoomUrl) : null;
    final waitingForLink = confirmed && isVideo && videoUri == null;
    final awaitingConfirmation = booking.status == 'pending' && isVideo;
    final showExpectation = confirmed && (isVideo || videoUri != null);
    final shopName = booking.shopName?.trim() ?? '';
    final notes = booking.notes?.trim() ?? '';
    final time = formatClock(booking.bookingTime);
    final when = time.isEmpty ? formatDate(booking.bookingDate) : '${formatDate(booking.bookingDate)} at $time';
    final title = (booking.serviceName ?? '').isEmpty ? 'Service' : booking.serviceName!;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title, style: AppTheme.body(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Flexible(child: StatusBadge(status: booking.status)),
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaItem(icon: Icons.calendar_today_outlined, text: when),
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ],
          if (awaitingConfirmation) ...[
            const SizedBox(height: 10),
            Text(videoLinkAfterConfirmText, style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
          ],
          if (waitingForLink) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.hourglass_empty, size: 16, color: AppColors.inkSoft),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(videoLinkSoonText, style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
                ),
              ],
            ),
          ],
          if (showExpectation) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.info_outline, size: 16, color: AppColors.inkSoft),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(videoExpectationText, style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft)),
                ),
              ],
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
                  Semantics(
                    button: true,
                    label: 'Cancel booking for $title',
                    excludeSemantics: true,
                    onTap: busy || locked ? null : onCancel,
                    child: OutlinedButton(
                      onPressed: busy || locked ? null : onCancel,
                      child: busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Cancel'),
                    ),
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
