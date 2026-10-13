import 'package:flutter/material.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../shared_widgets.dart';
import '../ui_kit.dart';
import 'seller_common.dart';
import 'service_form_sheet.dart';

/// "My services" tab: the shop's catalogue with add / edit / delete. Mirrors
/// src/components/seller/ServicesTab.jsx.
class ServicesTab extends StatefulWidget {
  final String shopId;
  final bool readOnly;
  final SellerQuery<List<ServiceItem>> query;

  const ServicesTab({super.key, required this.shopId, required this.readOnly, required this.query});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  String? _deletingId;

  Future<void> _openForm(ServiceItem? service) {
    return showServiceFormSheet(
      context,
      shopId: widget.shopId,
      service: service,
      onSaved: _handleSaved,
    );
  }

  void _handleSaved(String message) {
    if (!mounted) return;
    showSnack(context, message);
    widget.query.reload();
  }

  Future<void> _delete(ServiceItem service) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this service?',
      message: '"${service.name}" will be removed from your shop. This can\'t be undone.',
      confirmLabel: 'Delete service',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingId = service.id);
    // A service with bookings can't be deleted; the database's message is shown as-is.
    final failure = await deleteRow('services', service.id);
    if (!mounted) return;
    setState(() => _deletingId = null);

    if (failure != null) {
      showSnack(context, failure, error: true);
      return;
    }
    showSnack(context, 'Service deleted.');
    widget.query.reload();
  }

  @override
  Widget build(BuildContext context) {
    return SellerQueryPanel<List<ServiceItem>>(
      query: widget.query,
      what: 'your services',
      builder: (context, services) {
        final addButton = ElevatedButton.icon(
          onPressed: () => _openForm(null),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add service'),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Services customers can book. New services go live after admin approval.',
              style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
            ),
            if (!widget.readOnly && services.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: addButton),
            ],
            const SizedBox(height: 16),
            if (services.isEmpty)
              CardBox(
                child: EmptyState(
                  title: 'No services yet',
                  description:
                      'Offer grooming, vet visits, training and more. Each new service is reviewed by an admin before customers can book it.',
                  action: widget.readOnly ? null : addButton,
                ),
              )
            else
              for (final service in services)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ServiceCard(
                    key: ValueKey(service.id),
                    service: service,
                    readOnly: widget.readOnly,
                    deleting: _deletingId == service.id,
                    onEdit: () => _openForm(service),
                    onDelete: () => _delete(service),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceItem service;
  final bool readOnly;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard({
    super.key,
    required this.service,
    required this.readOnly,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category = serviceCategoryFor(service.category);
    final details = [category.label, formatDuration(service.durationMinutes)].where((part) => part.isNotEmpty).join(' · ');
    final description = (service.description ?? '').trim();

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(details, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatPrice(service.price),
                style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                status: service.status,
                label: service.status == 'pending' ? 'Awaiting admin approval' : null,
              ),
              if (!readOnly) ...[
                OutlinedButton.icon(
                  onPressed: deleting ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                ),
                TextButton.icon(
                  onPressed: deleting ? null : onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(deleting ? 'Deleting…' : 'Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
