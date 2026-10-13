import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';

/// One bookable service (mirrors src/components/services/ServiceCard.jsx).
/// Shows the shop name only -- never an address or phone number.
class CatalogServiceCard extends StatelessWidget {
  final ServiceItem service;
  final VoidCallback onBook;

  const CatalogServiceCard({super.key, required this.service, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final category = serviceCategoryFor(service.category);
    final duration = formatDuration(service.durationMinutes);
    final description = service.description?.trim() ?? '';
    final shopName = service.shopName?.trim() ?? '';
    final photo = service.photoUrls.isNotEmpty ? service.photoUrls.first : null;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ServiceTile(photoUrl: photo, icon: category.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(category.icon, size: 14, color: AppColors.inkSoft),
                        const SizedBox(width: 4),
                        Text(category.label, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(service.name, style: AppTheme.body(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    if (shopName.isNotEmpty)
                      Text(
                        'by $shopName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatPrice(service.price),
                      style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.accent),
                    ),
                    if (duration.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: AppColors.inkSoft),
                          const SizedBox(width: 4),
                          Text(duration, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: onBook, child: const Text('Book now')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Square photo (or category-icon fallback) for a service.
class ServiceTile extends StatelessWidget {
  final String? photoUrl;
  final IconData icon;
  final double size;

  const ServiceTile({super.key, required this.photoUrl, required this.icon, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.12),
            AppColors.tertiary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Icon(icon, color: AppColors.primary, size: size * 0.44),
    );
    final url = photoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (context, imageUrl, error) => fallback,
                placeholder: (context, imageUrl) => fallback,
              ),
      ),
    );
  }
}
