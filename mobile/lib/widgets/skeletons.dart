import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pulsing grey placeholder block used while data loads (no extra package).
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFF1F5F9), t),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A card-shaped skeleton row (title + two lines), repeated [count] times.
class ListSkeleton extends StatelessWidget {
  final int count;
  final double itemHeight;
  const ListSkeleton({super.key, this.count = 4, this.itemHeight = 92});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: itemHeight,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 16),
                    SizedBox(height: 10),
                    SkeletonBox(height: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 120, height: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two-column grid of image + text skeleton cards (pets / products / shops).
class GridSkeleton extends StatelessWidget {
  final int count;
  final double childAspectRatio;
  const GridSkeleton({super.key, this.count = 6, this.childAspectRatio = 0.72});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemBuilder: (context, _) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SkeletonBox(height: double.infinity, radius: 0)),
              Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 90, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 60, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
