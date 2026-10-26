import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/account/account_widgets.dart';
import '../widgets/account_scaffold.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// Mirrors src/pages/Learn.jsx (now a section of "My account"): pet-care
/// reference videos, each opening its source link in the browser / video app.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account/learn',
      title: 'Learn',
      subtitle: 'Pet care videos picked by the PETSTA team. They open in your browser or video app.',
      builder: (context, profile) => const _LearnBody(),
    );
  }
}

class _LearnBody extends StatefulWidget {
  const _LearnBody();

  @override
  State<_LearnBody> createState() => _LearnBodyState();
}

class _LearnBodyState extends State<_LearnBody> with AccountRefreshMixin<_LearnBody> {
  List<ReferenceVideo>? _videos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> refreshAccountData() => _load();

  void _retry() {
    setState(() {
      _videos = null;
      _error = null;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final videos = await ReferenceVideosRepository().listAll();
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (_videos != null) {
        // A background refresh failed: keep the list on screen.
        showSnack(context, errorText(error), error: true);
        return;
      }
      setState(() => _error = errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return AccountErrorNote(message: _error!, onRetry: _retry);
    final videos = _videos;
    if (videos == null) return const AccountLoadingNote();

    if (videos.isEmpty) {
      return EmptyState(
        title: 'No videos yet',
        description: 'Check back soon for pet care tips.',
        action: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefreshHeading(title: 'Pet care videos', onRefresh: _load),
        const SizedBox(height: 8),
        for (final video in videos) ...[
          _VideoCard(key: ValueKey(video.id), video: video),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final ReferenceVideo video;
  const _VideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final thumbnail = video.thumbnailUrl;
    final category = video.category;
    // Only plain http(s) links can be opened; anything else shows as a static card.
    final uri = safeExternalUri(video.videoUrl);

    final placeholder = Container(color: AppColors.primary.withValues(alpha: 0.05));

    // The thumbnail is decorative: the title and category carry the meaning.
    final thumbnailView = ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnail != null && thumbnail.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbnail,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  placeholder: (context, url) => placeholder,
                  errorWidget: (context, url, error) => placeholder,
                )
              else
                placeholder,
              if (uri != null)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: uri != null,
      hint: uri == null ? null : 'Opens the video in your browser',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: uri == null ? null : () => openExternalUri(context, uri),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbnailView,
                const SizedBox(height: 10),
                Text(video.title, style: AppTheme.body(fontWeight: FontWeight.w600)),
                if (category != null && category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(titleCase(category), style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
