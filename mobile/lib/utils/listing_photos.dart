import 'dart:math' as math;

/// Pure helpers for listing photos kept in the public `listing-photos` storage
/// bucket (pets, products, services and the shop banner). No Flutter or
/// network code lives here, so everything is unit-testable.
///
/// Object paths are `<shop_id>/<kind>/<random>.<ext>`; only the owning shop (or
/// an admin) may write inside its own `<shop_id>` folder, and anyone may view a
/// photo through its public URL. The public URL is what gets stored in
/// `photo_urls` / `banner_url`.

/// Most photos one listing can carry (the first is the cover).
const int kMaxListingPhotos = 6;

/// Largest photo the bucket accepts.
const int kMaxPhotoBytes = 5 * 1024 * 1024;

/// Name of the public storage bucket.
const String kListingPhotosBucket = 'listing-photos';

const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
const Set<String> _listingPhotoKinds = {'pets', 'products', 'services', 'shop'};
const String _publicUrlMarker = '/storage/v1/object/public/$kListingPhotosBucket/';
const String _hexDigits = '0123456789abcdef';

final math.Random _random = math.Random.secure();

/// "JPG", ".png" and "png" all become "png".
String _normalisedExtension(String ext) {
  var value = ext.trim().toLowerCase();
  if (value.startsWith('.')) value = value.substring(1);
  return value;
}

/// True for jpg, jpeg, png and webp, in any case, with or without a leading dot.
bool isAllowedPhotoExtension(String ext) => _allowedExtensions.contains(_normalisedExtension(ext));

/// The MIME type to upload [ext] with; 'application/octet-stream' when it isn't
/// an allowed photo type.
String mimeTypeForExtension(String ext) {
  switch (_normalisedExtension(ext)) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
  }
  return 'application/octet-stream';
}

/// The storage object path for a new photo: `<shopId>/<kind>/<id>.<ext>`.
///
/// [kind] must be pets, products, services or shop (anything else throws an
/// [ArgumentError]). [extension] is lowercased, loses a leading dot and "jpeg"
/// becomes "jpg". Without an [id], 16 random hex characters are used so two
/// uploads never collide.
String listingPhotoPath({
  required String shopId,
  required String kind,
  required String extension,
  String? id,
}) {
  if (!_listingPhotoKinds.contains(kind)) {
    throw ArgumentError.value(kind, 'kind', 'must be one of pets, products, services or shop');
  }
  var ext = _normalisedExtension(extension);
  if (ext == 'jpeg') ext = 'jpg';
  final name = (id == null || id.isEmpty) ? _randomHex(16) : id;
  return '$shopId/$kind/$name.$ext';
}

String _randomHex(int length) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_hexDigits[_random.nextInt(16)]);
  }
  return buffer.toString();
}

/// The object path inside the listing-photos bucket when [url] is a Supabase
/// public URL for that bucket, with any query string removed; null for every
/// other URL (external images, other buckets).
String? listingPhotoPathFromUrl(String url) {
  final text = url.trim();
  final start = text.indexOf(_publicUrlMarker);
  if (start < 0) return null;
  var path = text.substring(start + _publicUrlMarker.length);
  final cut = path.indexOf(RegExp(r'[?#]'));
  if (cut >= 0) path = path.substring(0, cut);
  if (path.isEmpty) return null;
  try {
    path = Uri.decodeComponent(path);
  } on FormatException {
    // Not percent-encoded text: use it as written.
  }
  return path.isEmpty ? null : path;
}

/// The lowercase extension of a file name or path, without the dot; empty when
/// there is none ("photo.JPG" -> "jpg", "photo" -> "", "dir.v2/photo" -> "").
String extensionOfFileName(String name) {
  final base = name.trim().split(RegExp(r'[\\/]')).last;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}
