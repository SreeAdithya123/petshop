import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Mirrors src/pages/admin/Videos.jsx: manage the reference videos shown to
/// shop owners and customers (add + delete, no edit).
class AdminVideosScreen extends ConsumerStatefulWidget {
  const AdminVideosScreen({super.key});

  @override
  ConsumerState<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

class _AdminVideosScreenState extends ConsumerState<AdminVideosScreen> {
  final _repo = ReferenceVideosRepository();

  bool _loading = true;
  List<ReferenceVideo> _videos = [];
  bool _showForm = false;

  final _titleController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  final _categoryController = TextEditingController();

  final Map<String, String> _errors = {};
  bool _submitting = false;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoUrlController.dispose();
    _thumbnailUrlController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() => _loading = true);
    try {
      final videos = await _repo.listAll();
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleForm() {
    setState(() => _showForm = !_showForm);
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_titleController.text.trim().isEmpty) errors['title'] = 'Enter a title.';
    if (_videoUrlController.text.trim().isEmpty) errors['video_url'] = 'Enter a video URL.';
    return errors;
  }

  Future<void> _handleSubmit() async {
    final validationErrors = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(validationErrors);
    });
    if (validationErrors.isNotEmpty) return;

    final profile = ref.read(authControllerProvider).profile;
    setState(() => _submitting = true);
    try {
      await _repo.insert({
        'title': _titleController.text.trim(),
        'video_url': _videoUrlController.text.trim(),
        'thumbnail_url': _thumbnailUrlController.text.trim().isEmpty ? null : _thumbnailUrlController.text.trim(),
        'category': _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        'created_by': profile?.id,
      });
      if (!mounted) return;
      _titleController.clear();
      _videoUrlController.clear();
      _thumbnailUrlController.clear();
      _categoryController.clear();
      setState(() {
        _errors.clear();
        _showForm = false;
      });
      await _loadVideos();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleDelete(ReferenceVideo video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('Delete "${video.title}"? This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingId = video.id);
    try {
      await _repo.delete(video.id);
      await _loadVideos();
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Videos',
      child: _loading
          ? const LoadingView(label: 'Loading videos…')
          : ListView(
              padding: kScreenPadding,
              children: [
                ScreenHeader(
                  title: 'Reference videos',
                  subtitle: 'Manage the reference videos shown to shop owners and customers.',
                  trailing: ElevatedButton(
                    onPressed: _toggleForm,
                    child: Text(_showForm ? 'Cancel' : 'Add a video'),
                  ),
                ),
                if (_showForm) ...[
                  const SizedBox(height: 24),
                  _buildForm(),
                ],
                const SizedBox(height: 24),
                if (_videos.isEmpty && !_showForm)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(
                      title: 'No reference videos yet',
                      description: 'Videos you add will show up here.',
                    ),
                  )
                else if (_videos.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _videos.length; i++) ...[
                          if (i > 0) const Divider(height: 1, color: AppColors.border),
                          _VideoRow(
                            video: _videos[i],
                            deleting: _deletingId == _videos[i].id,
                            onDelete: () => _handleDelete(_videos[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(label: 'Title', controller: _titleController, error: _errors['title']),
          const SizedBox(height: 18),
          _Field(
            label: 'Video URL',
            controller: _videoUrlController,
            error: _errors['video_url'],
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 18),
          _Field(
            label: 'Thumbnail URL (optional)',
            controller: _thumbnailUrlController,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 18),
          _Field(label: 'Category (optional)', controller: _categoryController),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleSubmit,
              child: Text(_submitting ? 'Saving…' : 'Save video'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final ReferenceVideo video;
  final bool deleting;
  final VoidCallback onDelete;

  const _VideoRow({required this.video, required this.deleting, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                video.thumbnailUrl!,
                width: 80,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 48,
                  color: AppColors.paper,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  video.category?.isNotEmpty == true ? video.category! : 'Uncategorized',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: deleting ? null : onDelete,
            child: Text(deleting ? 'Deleting…' : 'Delete'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? error;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.error,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTheme.body(),
          decoration: InputDecoration(
            errorText: error,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
