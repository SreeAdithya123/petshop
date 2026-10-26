import 'package:flutter/material.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/video_room.dart';
import '../ui_kit.dart';
import 'seller_common.dart';
import 'video_link_field.dart';

/// One customer booking of this shop's service, with Confirm / Mark
/// completed / Cancel and the video-link field. Mirrors
/// src/components/seller/BookingCard.jsx. A video booking gets a free PETSTA
/// video room by default, so confirming never needs a pasted link.
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
  String? _busyAction;
  String? _error;
  String? _linkError;

  ServiceBooking get _booking => widget.booking;
  bool get _isVideo => _booking.deliveryMode == 'video';
  bool get _isOpen => _booking.status == 'pending' || _booking.status == 'confirmed';
  bool get _canAct => !widget.readOnly && _isOpen;
  String get _savedLink => (_booking.videoRoomUrl ?? '').trim();

  @override
  void initState() {
    super.initState();
    _link = TextEditingController(text: _savedLink.isNotEmpty ? _savedLink : jitsiRoomUrl(_booking.id));
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _apply(String action, Map<String, dynamic> patch, {String? fromStatus}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyAction = action;
      _error = null;
      _linkError = null;
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
      _busyAction = null;
      _error = failure;
    });
    // After a stale-status refusal the list reloads too, so the card shows the
    // booking's real state and the right buttons.
    if (failure == null || failure == kNothingChanged) widget.onChanged();
  }

  void _confirmBooking() {
    final patch = <String, dynamic>{'status': 'confirmed'};
    if (_isVideo) {
      // An empty field means the free PETSTA room; a typed link must be https.
      final resolved = resolveVideoLink(_link.text, _booking.id);
      if (resolved.error != null) {
        setState(() => _linkError = resolved.error);
        return;
      }
      patch['video_room_url'] = resolved.link;
    }
    _apply('confirm', patch, fromStatus: 'pending');
  }

  void _saveLink() {
    final resolved = resolveVideoLink(_link.text, _booking.id);
    if (resolved.error != null) {
      setState(() => _linkError = resolved.error);
      return;
    }
    _apply('link', {'video_room_url': resolved.link}, fromStatus: _booking.status);
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
    await _apply('cancel', {'status': 'cancelled'}, fromStatus: _booking.status);
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    final savedLink = _savedLink;
    final subtitle = [
      if (booking.serviceCategory != null && booking.serviceCategory!.isNotEmpty)
        serviceCategoryLabel(booking.serviceCategory),
      'Booked ${formatOrderDate(booking.createdAt)}',
    ].join(' · ');
    final note = (booking.notes ?? '').trim();
    final editingLink = _canAct && _isVideo;

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
          if (savedLink.isNotEmpty && !editingLink) SellerMetaRow('Video link', child: SellerVideoLink(savedLink)),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            SellerNoteBox(label: 'Customer note', text: note),
          ],
          if (editingLink) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VideoLinkField(
                    controller: _link,
                    roomId: booking.id,
                    enabled: !_busy,
                    errorText: _linkError,
                    onChanged: () => setState(() => _linkError = null),
                  ),
                  if (booking.status == 'confirmed') ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: LoadingButton(
                        label: 'Save link',
                        outlined: true,
                        loading: _busyAction == 'link',
                        onPressed: (_busy || _link.text.trim() == savedLink) ? null : _saveLink,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'The link is saved when you confirm the booking.',
                      style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                  ],
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
                  LoadingButton(
                    label: 'Confirm',
                    loading: _busyAction == 'confirm',
                    onPressed: _busy ? null : _confirmBooking,
                  ),
                if (booking.status == 'confirmed')
                  LoadingButton(
                    label: 'Mark completed',
                    loading: _busyAction == 'complete',
                    onPressed: _busy ? null : () => _apply('complete', {'status': 'completed'}, fromStatus: 'confirmed'),
                  ),
                LoadingButton(
                  label: 'Cancel booking',
                  outlined: true,
                  loading: _busyAction == 'cancel',
                  onPressed: _busy ? null : _cancelBooking,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
