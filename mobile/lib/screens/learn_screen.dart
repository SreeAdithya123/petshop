import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/Learn.jsx: a grid of reference videos, each opening its
/// source video externally (the web app opens them in a new tab).
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  List<ReferenceVideo> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await ReferenceVideosRepository().listAll();
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load videos. Try again.";
        _loading = false;
      });
    }
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = const LoadingView();
    } else if (_error != null) {
      content = ErrorView(message: _error!);
    } else {
      content = ListView(
        padding: kScreenPadding,
        children: [
          Text(
            'Learn',
            style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Videos on pet care, from our shops and our team.',
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          if (_videos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                title: 'No videos yet',
                description: 'Check back soon for pet care tips.',
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                return _VideoCard(
                  video: video,
                  onTap: () => _openVideo(video.videoUrl),
                );
              },
            ),
        ],
      );
    }

    return RoleShell(title: 'Learn', child: content);
  }
}

class _VideoCard extends StatelessWidget {
  final ReferenceVideo video;
  final VoidCallback onTap;
  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnail = video.thumbnailUrl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: (thumbnail != null && thumbnail.isNotEmpty)
                    ? Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.primary.withValues(alpha: 0.05),
                        ),
                      )
                    : Container(
                        color: AppColors.primary.withValues(alpha: 0.05),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              video.title,
              style: AppTheme.body(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (video.category != null && video.category!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _capitalize(video.category!),
                style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
