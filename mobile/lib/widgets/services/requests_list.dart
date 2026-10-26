import 'package:flutter/material.dart';

import '../../core/async_utils.dart';
import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../skeletons.dart';
import '../ui_kit.dart';
import 'service_support.dart';

// shop_name is the quoting shop's name; contact details are never part of the row.
const _requestColumns =
    'id, title, description, category, pet_name, pet_species, preferred_date, budget, status, '
    'shop_name, quoted_price, response_message, responded_at, created_at';

// Which current statuses a customer may move a request out of, per target status.
const _allowedFrom = <String, List<String>>{
  'cancelled': ['open', 'quoted'],
  'accepted': ['quoted'],
  'declined': ['quoted'],
};

/// The signed-in customer's own custom service requests, with accept /
/// decline / cancel. Mirrors useCustomRequests.js.
class CustomRequestsController extends ChangeNotifier {
  CustomRequestsController({required this.userId}) {
    load();
  }

  final String userId;

  List<CustomServiceRequest> requests = const [];
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
    if (!silent || requests.isEmpty) loading = true;
    error = null;
    _notify();
    try {
      final rows = await withTimeout(
        SupabaseService.client
            .from('custom_service_requests')
            .select(_requestColumns)
            .eq('customer_id', userId)
            .order('created_at', ascending: false),
      );
      if (_disposed || generation != _generation) return;
      requests = rows.map(CustomServiceRequest.fromJson).toList();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = errorText(e);
    }
    loading = false;
    _notify();
  }

  Future<void> changeStatus(String id, String nextStatus) async {
    final allowedFrom = _allowedFrom[nextStatus];
    // One change at a time: ignore a second tap while a request is in flight.
    if (allowedFrom == null || busyId != null) return;
    busyId = id;
    actionError = null;
    _notify();
    try {
      // .select() so a row filtered out by RLS / the status guard is noticed.
      final rows = await withTimeout(
        SupabaseService.client
            .from('custom_service_requests')
            .update({'status': nextStatus})
            .eq('id', id)
            .inFilter('status', allowedFrom)
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

/// Own custom service requests with quote handling (mirrors RequestList.jsx).
class RequestsList extends StatelessWidget {
  final CustomRequestsController controller;
  final String emptyMessage;

  const RequestsList({super.key, required this.controller, this.emptyMessage = 'No custom requests yet.'});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final requests = controller.requests;
        if (controller.loading && requests.isEmpty) {
          return const ListSkeleton(count: 2, itemHeight: 120);
        }
        final error = controller.error;
        final actionError = controller.actionError;
        if (requests.isEmpty) {
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
            for (final request in requests) ...[
              _RequestCard(
                request: request,
                busy: controller.busyId == request.id,
                // Another change is in flight: keep every action button idle.
                locked: controller.busyId != null,
                onChangeStatus: (status) => _changeStatus(context, request, status),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Future<void> _changeStatus(BuildContext context, CustomServiceRequest request, String status) async {
    if (status == 'accepted') {
      await controller.changeStatus(request.id, status);
      return;
    }
    final declining = status == 'declined';
    final confirmed = await confirmAction(
      context,
      title: declining ? 'Decline this quote?' : 'Cancel this request?',
      message: declining
          ? "The shop will be told you're not going ahead with this quote."
          : 'Shops will no longer be able to quote on it.',
      confirmLabel: declining ? 'Yes, decline' : 'Yes, cancel',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (confirmed) await controller.changeStatus(request.id, status);
  }
}

class _RequestCard extends StatelessWidget {
  final CustomServiceRequest request;
  final bool busy;
  final bool locked;
  final ValueChanged<String> onChangeStatus;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.locked,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final quoted = request.status == 'quoted';
    final canCancel = request.status == 'open' || quoted;
    final shopName = request.shopName?.trim() ?? '';
    final quotedPrice = request.quotedPrice;
    final hasQuote = request.status != 'open' && (quotedPrice != null || shopName.isNotEmpty);
    final responseMessage = request.responseMessage?.trim() ?? '';

    final petName = request.petName?.trim() ?? '';
    final petSpecies = request.petSpecies?.trim() ?? '';
    final pet = petName.isNotEmpty && petSpecies.isNotEmpty ? '$petName ($petSpecies)' : (petName.isNotEmpty ? petName : petSpecies);
    final category = request.category;
    final preferredDate = request.preferredDate;
    final budget = request.budget;
    final details = [
      if (category != null && category.isNotEmpty) serviceCategoryLabel(category),
      if (pet.isNotEmpty) 'Pet: $pet',
      if (preferredDate != null) 'Preferred ${formatDate(preferredDate)}',
      if (budget != null) 'Budget ${formatPrice(budget)}',
    ];

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(request.title, style: AppTheme.body(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: StatusBadge(status: request.status, label: request.status == 'open' ? 'Awaiting quotes' : null),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(details.join(' · '), style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
          ],
          const SizedBox(height: 8),
          Text(
            request.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
          ),
          if (hasQuote) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Quote from ',
                      style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                      children: [
                        TextSpan(
                          text: shopName.isEmpty ? 'a shop' : shopName,
                          style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (quotedPrice != null)
                    Text(
                      formatPrice(quotedPrice),
                      style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.accent),
                    ),
                  if (responseMessage.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(responseMessage, style: AppTheme.body(fontSize: 13.5)),
                  ],
                ],
              ),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (quoted) ...[
                  ElevatedButton(
                    onPressed: busy || locked ? null : () => onChangeStatus('accepted'),
                    child: const Text('Accept quote'),
                  ),
                  OutlinedButton(
                    onPressed: busy || locked ? null : () => onChangeStatus('declined'),
                    child: const Text('Decline'),
                  ),
                ],
                OutlinedButton(
                  onPressed: busy || locked ? null : () => onChangeStatus('cancelled'),
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Cancel request'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
