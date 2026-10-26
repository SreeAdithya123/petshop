import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// Lays tiles out two per row at equal height.
class AdminTileGrid extends StatelessWidget {
  final List<Widget> tiles;
  const AdminTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < tiles.length ? 12 : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles[i]),
                  const SizedBox(width: 12),
                  Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A dashboard counter. With a [route] the whole tile is a button that opens
/// that screen; without one it is a plain read-out. [attention] tiles
/// highlight while the count is above zero. A null [value] (that count failed
/// to load) shows a dash and is announced as unavailable.
class AdminStatTile extends StatelessWidget {
  final String label;
  final int? value;
  final String? hint;
  final IconData icon;
  final String? route;
  final bool attention;

  const AdminStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.route,
    this.hint,
    this.attention = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = value;
    final target = route;
    final highlighted = attention && (count ?? 0) > 0;
    final accent = highlighted ? AppColors.adminAccent : AppColors.inkSoft;
    final spoken = '$label: ${count ?? 'unavailable'}${hint == null ? '' : '. $hint'}';
    void open() {
      if (target != null) context.push(target);
    }

    return Semantics(
      container: true,
      button: target != null,
      label: spoken,
      hint: target == null ? null : 'Opens the list',
      onTap: target == null ? null : open,
      excludeSemantics: true,
      child: Material(
        color: highlighted ? AppColors.adminAccent.withValues(alpha: 0.06) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: highlighted ? AppColors.adminAccent.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: InkWell(
          onTap: target == null ? null : open,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(icon, size: 18, color: accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(count == null ? '–' : '$count', style: AppTheme.display(fontSize: 24)),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(hint!, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
