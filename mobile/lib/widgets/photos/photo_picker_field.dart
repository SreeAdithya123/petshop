import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter, PlatformException;
import 'package:image_picker/image_picker.dart';

import '../../services/photo_upload.dart';
import '../../theme/app_theme.dart';
import '../../utils/listing_photos.dart';
import '../ui_kit.dart' show errorText;

/// Edits the photos of a listing (a pet, product or service) or the shop
/// banner: a horizontal strip of thumbnails with a "Add photo" tile.
///
/// A photo is added by taking one with the camera, choosing one from the
/// gallery (both are uploaded to the shop's folder in the public
/// `listing-photos` bucket) or pasting an https link. The strip does not own
/// the list: the parent passes the current [urls] and receives the new list
/// through [onChanged]. The first photo is the cover.
///
/// Photos uploaded during the edit are deleted from storage as soon as they are
/// removed again. Files that were already saved with the listing are not
/// touched here; the form deletes them after it has saved (see
/// [ListingPhotoTracker]).
class PhotoPickerField extends StatefulWidget {
  final String shopId;

  /// pets, products, services or shop.
  final String kind;
  final List<String> urls;
  final ValueChanged<List<String>> onChanged;
  final int max;

  /// One image only (the shop banner): a new photo replaces the current one.
  final bool single;
  final String label;

  /// False while the parent form is submitting.
  final bool enabled;

  /// Called with true while a photo is being picked or uploaded. The parent
  /// should not let the form be saved meanwhile, or the new photo is missed.
  final ValueChanged<bool>? onBusyChanged;

  const PhotoPickerField({
    super.key,
    required this.shopId,
    required this.kind,
    required this.urls,
    required this.onChanged,
    this.max = kMaxListingPhotos,
    this.single = false,
    this.label = 'Photos',
    this.enabled = true,
    this.onBusyChanged,
  });

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

const double _kTileSize = 96;
const double _kTileGap = 10;
const double _kPickMaxSide = 1600;
const int _kPickQuality = 85;

enum _AddAction { camera, gallery, link }

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  final ImagePicker _picker = ImagePicker();

  /// Photos uploaded by this field and not yet removed again.
  final Set<String> _uploadedHere = {};

  bool _busy = false;
  bool _uploading = false;
  String? _error;

  int get _limit => widget.single ? 1 : widget.max;
  bool get _canAdd => widget.single || widget.urls.length < _limit;
  bool get _hasReplaceableCover => widget.single && widget.urls.isNotEmpty;

  void _setBusy(bool busy, {bool uploading = false}) {
    if (!mounted) return;
    final changed = _busy != busy;
    setState(() {
      _busy = busy;
      _uploading = busy && uploading;
    });
    if (changed) widget.onBusyChanged?.call(busy);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _uploading = false;
      _error = message;
    });
    widget.onBusyChanged?.call(false);
  }

  Future<void> _add() async {
    if (_busy || !widget.enabled || !_canAdd) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _error = null);

    final action = await showModalBottomSheet<_AddAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _AddSheet(replacing: _hasReplaceableCover),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _AddAction.camera:
        await _pick(ImageSource.camera);
      case _AddAction.gallery:
        await _pick(ImageSource.gallery);
      case _AddAction.link:
        await _addByLink();
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    _setBusy(true);
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: _kPickMaxSide,
        maxHeight: _kPickMaxSide,
        imageQuality: _kPickQuality,
      );
    } on PlatformException catch (error) {
      _fail(_pickerMessage(error, source));
      return;
    } catch (error) {
      _fail(errorText(error));
      return;
    }
    if (!mounted) return;
    if (file == null) {
      // The seller closed the camera or gallery without choosing.
      _setBusy(false);
      return;
    }
    await _upload(file);
  }

  Future<void> _upload(XFile file) async {
    _setBusy(true, uploading: true);
    final String url;
    try {
      url = await uploadListingPhoto(shopId: widget.shopId, kind: widget.kind, file: file);
    } catch (error) {
      _fail(errorText(error));
      return;
    }
    if (!mounted) {
      // The form was closed mid-upload: nothing references the new file.
      unawaited(deleteListingPhotoByUrl(url));
      return;
    }
    if (!widget.single && widget.urls.length >= widget.max) {
      unawaited(deleteListingPhotoByUrl(url));
      _fail('You can add up to ${widget.max} photos.');
      return;
    }
    _uploadedHere.add(url);
    _setBusy(false);
    _replaceOrAppend(url);
  }

  Future<void> _addByLink() async {
    final link = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _LinkDialog(existing: widget.urls),
    );
    if (link == null || !mounted) return;
    _replaceOrAppend(link);
  }

  void _replaceOrAppend(String url) {
    final current = widget.urls;
    if (widget.single) {
      for (final old in current) {
        _discardIfUploadedHere(old);
      }
      widget.onChanged([url]);
      return;
    }
    if (current.length >= widget.max) return;
    widget.onChanged([...current, url]);
  }

  void _remove(int index) {
    if (_busy || !widget.enabled || index < 0 || index >= widget.urls.length) return;
    final next = [...widget.urls];
    final removed = next.removeAt(index);
    _discardIfUploadedHere(removed);
    setState(() => _error = null);
    widget.onChanged(next);
  }

  /// A photo uploaded during this edit and then dropped is referenced by
  /// nothing, so its file can go straight away.
  void _discardIfUploadedHere(String url) {
    if (_uploadedHere.remove(url)) unawaited(deleteListingPhotoByUrl(url));
  }

  String _pickerMessage(PlatformException error, ImageSource source) {
    switch (error.code) {
      case 'camera_access_denied':
        return 'Allow camera access in your phone settings to take a photo.';
      case 'photo_access_denied':
        return 'Allow photo access in your phone settings to choose a picture.';
      case 'no_available_camera':
        return 'No camera is available on this device.';
    }
    return source == ImageSource.camera
        ? "We couldn't open the camera. Please try again."
        : "We couldn't open your photos. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final interactive = widget.enabled && !_busy;
    final canAdd = _canAdd;
    final addLabel = _hasReplaceableCover ? 'Replace' : 'Add photo';
    final String hint;
    if (widget.single) {
      hint = 'One image. A wide photo works best.';
    } else if (urls.length >= widget.max) {
      hint = 'You have added the most you can (${widget.max}). Remove one to add another.';
    } else {
      hint = '${urls.length} of ${widget.max} photos. The first photo is the cover.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.label,
            style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < urls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: _kTileGap),
                    child: _PhotoThumb(
                      key: ValueKey(urls[i]),
                      url: urls[i],
                      position: i + 1,
                      isCover: !widget.single && i == 0,
                      single: widget.single,
                      onRemove: interactive ? () => _remove(i) : null,
                    ),
                  ),
                if (canAdd)
                  _AddTile(
                    label: addLabel,
                    uploading: _uploading,
                    semanticLabel: _uploading
                        ? 'Uploading photo'
                        : widget.single
                            ? '$addLabel, ${widget.label}'
                            : 'Add photo, ${urls.length} of ${widget.max} added',
                    onTap: interactive ? _add : null,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(hint, style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft)),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
          ),
        ],
      ],
    );
  }
}

/// One photo in the strip, with its remove button and, on the first photo of a
/// listing, a "Cover" badge.
class _PhotoThumb extends StatelessWidget {
  final String url;
  final int position;
  final bool isCover;
  final bool single;
  final VoidCallback? onRemove;

  const _PhotoThumb({
    super.key,
    required this.url,
    required this.position,
    required this.isCover,
    required this.single,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final description = single
        ? 'Current photo'
        : isCover
            ? 'Cover photo'
            : 'Photo $position';
    return SizedBox(
      width: _kTileSize,
      height: _kTileSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: description,
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (_kTileSize * pixelRatio).round(),
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: const Duration(milliseconds: 100),
                placeholder: (context, imageUrl) => Container(color: AppColors.primary.withValues(alpha: 0.05)),
                errorWidget: (context, imageUrl, error) => const _BrokenPhoto(),
              ),
            ),
          ),
          if (isCover)
            Positioned(
              left: 6,
              bottom: 6,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Cover',
                    style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: _RemoveButton(label: 'Remove ${description.toLowerCase()}', onPressed: onRemove),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of a photo that fails to load (a dead external link, say), so
/// the seller can still see it is there and remove it.
class _BrokenPhoto extends StatelessWidget {
  const _BrokenPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.paper,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: AppColors.inkSoft, size: 28),
    );
  }
}

/// A 48dp tap target with a small round "x" in the thumbnail's top-right corner.
class _RemoveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _RemoveButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.78),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Add photo" (or "Replace") tile; shows a spinner while an upload runs.
class _AddTile extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final bool uploading;
  final VoidCallback? onTap;

  const _AddTile({
    required this.label,
    required this.semanticLabel,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: AppColors.primary.withValues(alpha: 0.4));
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      liveRegion: uploading,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.05),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: border),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: _kTileSize,
            height: _kTileSize,
            child: Center(
              child: uploading
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                        SizedBox(height: 8),
                        Text('Uploading', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, size: 26, color: AppColors.primary),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that asks where the photo comes from.
class _AddSheet extends StatelessWidget {
  final bool replacing;
  const _AddSheet({required this.replacing});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Semantics(
              header: true,
              child: Text(replacing ? 'Replace photo' : 'Add a photo', style: AppTheme.display(fontSize: 18)),
            ),
          ),
          _SheetOption(
            icon: Icons.photo_camera_outlined,
            label: 'Take photo',
            onTap: () => Navigator.of(context).pop(_AddAction.camera),
          ),
          _SheetOption(
            icon: Icons.photo_library_outlined,
            label: 'Choose from gallery',
            onTap: () => Navigator.of(context).pop(_AddAction.gallery),
          ),
          _SheetOption(
            icon: Icons.link,
            label: 'Add by link',
            onTap: () => Navigator.of(context).pop(_AddAction.link),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: AppTheme.body(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

/// Asks for the https link of a photo that is already online. Pops with the
/// trimmed link once it is valid.
class _LinkDialog extends StatefulWidget {
  final List<String> existing;
  const _LinkDialog({required this.existing});

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final link = _controller.text.trim();
    final uri = Uri.tryParse(link);
    String? error;
    if (link.isEmpty) {
      error = 'Paste the link of a photo.';
    } else if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      error = 'The link must start with https://';
    } else if (widget.existing.contains(link)) {
      error = 'That photo is already added.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(link);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('Add photo by link', style: AppTheme.display(fontSize: 18)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: [LengthLimitingTextInputFormatter(2000)],
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Photo link',
          hintText: 'https://example.com/photo.jpg',
          errorText: _error,
          errorMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
