import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_utils.dart';
import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/video_room.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';
import 'admin_common.dart';

/// Mirrors src/pages/admin/Videos.jsx: manage the reference videos shown to
/// shop owners and customers (add + delete, no edit).
class AdminVideosScreen extends ConsumerStatefulWidget {
  const AdminVideosScreen({super.key});

  @override
  ConsumerState<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

/// What the "Add a video" form hands back once it validates.
class _VideoValues {
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? category;

  const _VideoValues({required this.title, required this.videoUrl, this.thumbnailUrl, this.category});
}

Future<List<ReferenceVideo>> _fetchVideos() => ReferenceVideosRepository().listAll();

class _AdminVideosScreenState extends ConsumerState<AdminVideosScreen> {
  late final SellerQuery<List<ReferenceVideo>> _query;
  int _limit = kPageSize;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _query = SellerQuery<List<ReferenceVideo>>(_fetchVideos);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _openAddSheet() async {
    await showFormSheet<void>(
      context,
      title: 'Add a video',
      description: 'Shown to shop owners and customers as a reference.',
      builder: (sheetContext) => _VideoForm(onSubmit: _saveVideo),
    );
  }

  /// Inserts the video. Resolves to an error message, or null on success (the
  /// form closes itself). Lives here, not in the sheet, so the list refreshes
  /// even if the sheet was dismissed while saving.
  Future<String?> _saveVideo(_VideoValues values) async {
    final createdBy = ref.read(authControllerProvider).profile?.id;
    try {
      await withTimeout(
        SupabaseService.client.from('reference_videos').insert({
          'title': values.title,
          'video_url': values.videoUrl,
          'thumbnail_url': values.thumbnailUrl,
          'category': values.category,
          'created_by': createdBy,
        }),
      );
    } catch (e) {
      return describeError(e);
    }
    if (mounted) {
      showSnack(context, 'Added "${values.title}".');
      _query.reload();
    }
    return null;
  }

  Future<void> _delete(ReferenceVideo video) async {
    if (_deletingId != null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this video?',
      message: '"${video.title}" will be removed for everyone. This can\'t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingId = video.id);
    final failure = await deleteRow('reference_videos', video.id);
    if (!mounted) return;
    if (failure != null) {
      showSnack(context, failure, error: true);
      // Already gone (another admin)? Show what is really there.
      if (failure == kNothingChanged) await _query.reload();
    } else {
      showSnack(context, 'Deleted "${video.title}".');
      await _query.reload();
    }
    if (!mounted) return;
    setState(() => _deletingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Videos',
      heading: 'Reference videos',
      subtitle: 'Manage the reference videos shown to shop owners and customers.',
      onRefresh: _query.reload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add a video'),
            ),
          ),
          const SizedBox(height: 16),
          SellerQueryPanel<List<ReferenceVideo>>(
            query: _query,
            what: 'videos',
            builder: (context, videos) {
              if (videos.isEmpty) {
                return CardBox(
                  child: EmptyState(
                    title: 'No reference videos yet',
                    description: 'Videos you add will show up here.',
                    action: ElevatedButton(onPressed: _openAddSheet, child: const Text('Add a video')),
                  ),
                );
              }
              final shown = math.min(_limit, videos.length);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final video in videos.take(shown))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VideoCard(
                        key: ValueKey(video.id),
                        video: video,
                        deleting: _deletingId == video.id,
                        locked: _deletingId != null,
                        onDelete: () => _delete(video),
                      ),
                    ),
                  LoadMoreButton(
                    shown: shown,
                    total: videos.length,
                    onPressed: () => setState(() => _limit += kPageSize),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final ReferenceVideo video;
  final bool deleting;

  /// True while any video is being deleted; the buttons wait.
  final bool locked;
  final VoidCallback onDelete;

  const _VideoCard({
    super.key,
    required this.video,
    required this.deleting,
    required this.locked,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category = (video.category ?? '').trim();
    final uri = isSafeWebLink(video.videoUrl) ? Uri.tryParse(video.videoUrl.trim()) : null;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(url: video.thumbnailUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.isEmpty ? 'Uncategorized' : category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.videoUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(fontSize: 12.5, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tooltip(
                message: 'Open the video link',
                child: OutlinedButton.icon(
                  onPressed: uri == null ? null : () => openExternal(context, uri),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open'),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: locked ? AppColors.border : AppColors.error),
                ),
                onPressed: locked ? null : onDelete,
                icon: deleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                      )
                    : const Icon(Icons.delete_outline, size: 18),
                label: Text(deleting ? 'Deleting…' : 'Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small preview image; decorative (the title carries the meaning).
class _Thumbnail extends StatelessWidget {
  final String? url;
  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final link = (url ?? '').trim();
    final fallback = Container(
      color: AppColors.paper,
      alignment: Alignment.center,
      child: const Icon(Icons.play_circle_outline, color: AppColors.inkSoft),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 72,
          height: 48,
          child: isSafeWebLink(link)
              ? CachedNetworkImage(
                  imageUrl: link,
                  fit: BoxFit.cover,
                  memCacheWidth: 216,
                  placeholder: (context, imageUrl) => fallback,
                  errorWidget: (context, imageUrl, error) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

/// The "Add a video" form shown in a bottom sheet.
class _VideoForm extends StatefulWidget {
  /// Saves the video; resolves to an error message, or null on success.
  final Future<String?> Function(_VideoValues values) onSubmit;

  const _VideoForm({required this.onSubmit});

  @override
  State<_VideoForm> createState() => _VideoFormState();
}

class _VideoFormState extends State<_VideoForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _videoUrl = TextEditingController();
  final _thumbnailUrl = TextEditingController();
  final _category = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _videoUrl.dispose();
    _thumbnailUrl.dispose();
    _category.dispose();
    super.dispose();
  }

  String? _requiredLink(String? value, String empty) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return empty;
    return isHttpsUrl(text) ? null : 'Enter a link that starts with https://';
  }

  String? _optionalLink(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    return isHttpsUrl(text) ? null : 'Enter a link that starts with https://';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final thumbnail = _thumbnailUrl.text.trim();
    final category = _category.text.trim();
    final values = _VideoValues(
      title: _title.text.trim(),
      videoUrl: _videoUrl.text.trim(),
      thumbnailUrl: thumbnail.isEmpty ? null : thumbnail,
      category: category.isEmpty ? null : category,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });
    final failure = await widget.onSubmit(values);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _title,
            enabled: !_submitting,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a title.' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _videoUrl,
            enabled: !_submitting,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Video URL', hintText: 'https://'),
            validator: (value) => _requiredLink(value, 'Enter a video URL.'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _thumbnailUrl,
            enabled: !_submitting,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Thumbnail URL (optional)', hintText: 'https://'),
            validator: _optionalLink,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _category,
            enabled: !_submitting,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            decoration: const InputDecoration(labelText: 'Category (optional)'),
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            NoticeBox.error(message: _error!),
          ],
          const SizedBox(height: 18),
          LoadingButton(
            label: 'Save video',
            loading: _submitting,
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
