import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_error.dart';
import '../core/async_utils.dart';
import '../utils/listing_photos.dart';
import 'supabase_service.dart';

/// Uploading listing photos (pets, products, services, the shop banner) to the
/// public `listing-photos` storage bucket. See `utils/listing_photos.dart` for
/// the path rules.

/// A phone photo can be a few MB; allow far longer than a normal request.
const Duration _kUploadTimeout = Duration(seconds: 90);
const Duration _kDeleteTimeout = Duration(seconds: 15);

const String _tooLargeMessage = 'That photo is larger than ${kMaxPhotoBytes ~/ (1024 * 1024)} MB. Choose a smaller one.';
const String _unsupportedMessage = 'Use a JPG, PNG or WebP photo.';
const String _unreadableMessage = "We couldn't read that photo. Please choose it again.";

/// Uploads [file] for the shop [shopId] and returns its public URL.
///
/// [kind] is pets, products, services or shop. Throws a [UserFacingException]
/// (or a network / storage error that `friendlyError` understands) when the
/// photo is too big, is not a JPG / PNG / WebP image, cannot be read, or the
/// upload fails.
Future<String> uploadListingPhoto({
  required String shopId,
  required String kind,
  required XFile file,
}) async {
  final declared = extensionOfFileName(file.name);
  final bytes = await _readPhoto(file);

  // The picker can hand back a re-encoded file whose name no longer matches its
  // contents (a HEIC picture saved as JPEG), so trust the bytes first and the
  // file name second.
  final extension = _sniffExtension(bytes) ?? (isAllowedPhotoExtension(declared) ? declared : null);
  if (extension == null) throw const UserFacingException(_unsupportedMessage);

  final path = listingPhotoPath(shopId: shopId, kind: kind, extension: extension);
  final bucket = SupabaseService.client.storage.from(kListingPhotosBucket);
  try {
    await withTimeout(
      bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeTypeForExtension(extension), upsert: false),
      ),
      timeout: _kUploadTimeout,
    );
  } on StorageException catch (error) {
    final text = error.message.toLowerCase();
    if (error.statusCode == '413' || text.contains('maximum allowed size')) {
      throw UserFacingException(_tooLargeMessage, cause: error);
    }
    if (error.statusCode == '415' || text.contains('mime type')) {
      throw UserFacingException(_unsupportedMessage, cause: error);
    }
    rethrow;
  }
  return bucket.getPublicUrl(path);
}

/// The bytes of [file], after checking it is neither empty nor over the limit.
Future<Uint8List> _readPhoto(XFile file) async {
  try {
    // Ask for the size first so an oversized photo is never read into memory.
    if (await file.length() > kMaxPhotoBytes) throw const UserFacingException(_tooLargeMessage);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const UserFacingException(_unreadableMessage);
    if (bytes.length > kMaxPhotoBytes) throw const UserFacingException(_tooLargeMessage);
    return bytes;
  } on UserFacingException {
    rethrow;
  } catch (error) {
    throw UserFacingException(_unreadableMessage, cause: error);
  }
}

/// Deletes the stored file behind [url], if it is one of ours. Best effort: a
/// URL outside the bucket is ignored and every failure is swallowed (the worst
/// case is an orphaned file).
Future<void> deleteListingPhotoByUrl(String url) => _removePaths([listingPhotoPathFromUrl(url)]);

/// Deletes the stored files of every URL in [candidates] that is not also in
/// [keep] (best effort, see [deleteListingPhotoByUrl]). External image links
/// are never touched.
Future<void> deleteUnreferencedListingPhotos({
  required Iterable<String> candidates,
  required Iterable<String> keep,
}) {
  final kept = keep.map(listingPhotoPathFromUrl).whereType<String>().toSet();
  return _removePaths([
    for (final url in candidates)
      if (!kept.contains(listingPhotoPathFromUrl(url))) listingPhotoPathFromUrl(url),
  ]);
}

Future<void> _removePaths(List<String?> paths) async {
  final unique = paths.whereType<String>().toSet().toList();
  if (unique.isEmpty) return;
  try {
    await withTimeout(
      SupabaseService.client.storage.from(kListingPhotosBucket).remove(unique),
      timeout: _kDeleteTimeout,
    );
  } catch (_) {
    // Best effort: an undeleted file is only wasted space.
  }
}

/// Keeps listing-photo storage tidy for one form (a pet, product, service or
/// the shop profile).
///
/// Pass the photo URLs the record holds when the form opens. Then:
///  * call [saveStarted] right before the save request is sent;
///  * call [saveSucceeded] with the saved URLs once the save went through: the
///    files of photos the seller took off the listing are deleted;
///  * call [discard] from `dispose` with the form's current URLs: when the form
///    closes and no save was ever attempted, files uploaded during the edit are
///    deleted.
///
/// A save that failed leaves its outcome unknown (it may have reached the
/// server), so after one nothing is deleted on discard.
class ListingPhotoTracker {
  ListingPhotoTracker(Iterable<String> saved) : _saved = List<String>.of(saved);

  List<String> _saved;
  bool _saveIssued = false;

  void saveStarted() => _saveIssued = true;

  void saveSucceeded(Iterable<String> urls) {
    final previous = _saved;
    _saved = List<String>.of(urls);
    _saveIssued = false;
    unawaited(deleteUnreferencedListingPhotos(candidates: previous, keep: _saved));
  }

  void discard(Iterable<String> current) {
    if (_saveIssued) return;
    unawaited(deleteUnreferencedListingPhotos(candidates: current, keep: _saved));
  }
}

/// "jpg", "png" or "webp" when [bytes] start with that format's signature.
String? _sniffExtension(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'jpg';
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A) {
    return 'png';
  }
  // RIFF....WEBP
  if (b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return 'webp';
  }
  return null;
}
