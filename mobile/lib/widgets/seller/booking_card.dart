import 'package:flutter/material.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'seller_common.dart';

const _linkError = 'Video links must start with https://';

/// One customer booking of this shop's service, with Confirm / Mark
/// completed / Cancel and the video-link field. Mirrors
/// src/components/seller/BookingCard.jsx.
class BookingCard extends StatefulWidget {
  final ServiceBooking booking;
  final CustomerInfo? customer;
  final bool readOnly;

  /// Called after a successful change so the list can reload.
  final VoidCallback onChanged;

  const BookingCard({
    super.key,
    required this.booking,
    required this.customer,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  late final TextEditingController _link;
  bool _busy = false;
  String? _error;

  ServiceBooking get _booking => widget.booking;
  bool get _isVideo => _booking.deliveryMode == 'video';
  bool get _isOpen => _booking.status == 'pending' || _booking.status == 'confirmed';
  bool get _canAct => !widget.readOnly && _isOpen;

  @override
  void initState() {
    super.initState();
    _link = TextEditingController(text: _booking.videoRoomUrl ?? '');
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _apply(Map<String, dynamic> patch, {String? fromStatus}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await updateRow(
      'service_bookings',
      _booking.id,
      patch,
      match: fromStatus == null ? null : {'status': fromStatus},
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
    });
    if (failure == null) widget.onChanged();
  }

  void _confirmBooking() {
    final link = _link.text.trim();
    // A video link is optional here, but if one is typed it has to be usable.
    if (_isVideo && link.isNotEmpty && !isHttpsUrl(link)) {
      setState(() => _error = _linkError);
      return;
    }
    _apply({
      'status': 'confirmed',
      if (_isVideo && link.isNotEmpty) 'video_room_url': link,
    }, fromStatus: 'pending');
  }

  void _saveLink() {
    final link = _link.text.trim();
    if (!isHttpsUrl(link)) {
      setState(() => _error = _linkError);
      return;
    }
    _apply({'video_room_url': link});
  }

  Future<void> _cancelBooking() async {
    final slot = formatSlot(_booking.bookingDate, _booking.bookingTime);
    final confirmed = await confirmAction(
      context,
      title: 'Cancel this booking?',
      message: '${_booking.serviceName ?? 'This service'} on $slot will be marked as cancelled and the customer will see that.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep booking',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _apply({'status': 'cancelled'});
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    final savedLink = booking.videoRoomUrl ?? '';
    final draft = _link.text.trim();
    final subtitle = [
      if (booking.serviceCategory != null && booking.serviceCategory!.isNotEmpty)
        serviceCategoryLabel(booking.serviceCategory),
      'Booked ${formatOrderDate(booking.createdAt)}',
    ].join(' · ');
    final note = (booking.notes ?? '').trim();

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
                    Text(
                      booking.serviceName ?? 'Service',
                      style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 12),
          SellerMetaRow('Customer', child: SellerCustomerContact(customer: widget.customer)),
          SellerMetaRow('When', text: formatSlot(booking.bookingDate, booking.bookingTime)),
          SellerMetaRow('How', text: modeLabel(booking.deliveryMode)),
          SellerMetaRow('Price', text: formatPrice(booking.priceAtBooking)),
          if (savedLink.isNotEmpty && !(_canAct && _isVideo))
            SellerMetaRow('Video link', child: SellerLinkText(savedLink)),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            SellerNoteBox(label: 'Customer note', text: note),
          ],
          if (_canAct && _isVideo) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Video link', style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Paste a Google Meet/Zoom link; the customer sees it on their Services & Health pages.',
                    style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _link,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'https://meet.google.com/...'),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: (_busy || draft.isEmpty || draft == savedLink) ? null : _saveLink,
                      child: const Text('Save link'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            NoticeBox.error(message: _error!),
          ],
          if (_canAct) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (booking.status == 'pending')
                  ElevatedButton(onPressed: _busy ? null : _confirmBooking, child: const Text('Confirm')),
                if (booking.status == 'confirmed')
                  ElevatedButton(
                    onPressed: _busy ? null : () => _apply({'status': 'completed'}, fromStatus: 'confirmed'),
                    child: const Text('Mark completed'),
                  ),
                OutlinedButton(onPressed: _busy ? null : _cancelBooking, child: const Text('Cancel booking')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
