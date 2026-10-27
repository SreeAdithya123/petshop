import 'package:flutter_test/flutter_test.dart';
import 'package:pawsnearby/utils/listing_photos.dart';

void main() {
  const shop = '11111111-0000-0000-0000-000000000001';
  const publicBase = 'https://pytkeurgdbhekyppfblh.supabase.co/storage/v1/object/public/listing-photos';

  group('limits', () {
    test('match the storage bucket rules', () {
      expect(kMaxListingPhotos, 6);
      expect(kMaxPhotoBytes, 5 * 1024 * 1024);
      expect(kListingPhotosBucket, 'listing-photos');
    });
  });

  group('extensions and MIME types', () {
    test('only jpg, jpeg, png and webp are allowed, in any case and with or without a dot', () {
      for (final ok in ['jpg', 'JPG', '.jpeg', 'png', '.PNG', 'webp', ' webp ']) {
        expect(isAllowedPhotoExtension(ok), isTrue, reason: ok);
      }
      for (final bad in ['gif', 'heic', 'svg', 'pdf', '', '.']) {
        expect(isAllowedPhotoExtension(bad), isFalse, reason: bad);
      }
    });

    test('mimeTypeForExtension', () {
      expect(mimeTypeForExtension('jpg'), 'image/jpeg');
      expect(mimeTypeForExtension('.JPEG'), 'image/jpeg');
      expect(mimeTypeForExtension('png'), 'image/png');
      expect(mimeTypeForExtension('WEBP'), 'image/webp');
      expect(mimeTypeForExtension('gif'), 'application/octet-stream');
    });

    test('extensionOfFileName', () {
      expect(extensionOfFileName('photo.JPG'), 'jpg');
      expect(extensionOfFileName('a/b\\c/pic.PNG'), 'png');
      expect(extensionOfFileName('photo'), '');
      expect(extensionOfFileName('photo.'), '');
      expect(extensionOfFileName('dir.v2/photo'), '');
      expect(extensionOfFileName('archive.tar.webp'), 'webp');
    });
  });

  group('listingPhotoPath', () {
    test('builds <shop>/<kind>/<id>.<ext> and normalises the extension', () {
      expect(listingPhotoPath(shopId: shop, kind: 'pets', extension: '.JPEG', id: 'abc'), '$shop/pets/abc.jpg');
      expect(listingPhotoPath(shopId: shop, kind: 'shop', extension: 'png', id: 'banner'), '$shop/shop/banner.png');
    });

    test('random ids are 16 hex characters and do not collide', () {
      final a = listingPhotoPath(shopId: shop, kind: 'products', extension: 'webp');
      final b = listingPhotoPath(shopId: shop, kind: 'products', extension: 'webp');
      final pattern = RegExp('^$shop/products/[0-9a-f]{16}\\.webp\$');
      expect(pattern.hasMatch(a), isTrue, reason: a);
      expect(a, isNot(b));
    });

    test('rejects unknown kinds', () {
      expect(() => listingPhotoPath(shopId: shop, kind: 'avatars', extension: 'jpg'), throwsArgumentError);
      expect(() => listingPhotoPath(shopId: shop, kind: '', extension: 'jpg'), throwsArgumentError);
    });

    test('the generated path always starts with the shop id (what the storage rule checks)', () {
      for (final kind in ['pets', 'products', 'services', 'shop']) {
        expect(listingPhotoPath(shopId: shop, kind: kind, extension: 'jpg').split('/').first, shop);
      }
    });
  });

  group('listingPhotoPathFromUrl', () {
    test('extracts the object path from our public URLs', () {
      expect(listingPhotoPathFromUrl('$publicBase/$shop/pets/abc.jpg'), '$shop/pets/abc.jpg');
    });

    test('strips query strings and fragments', () {
      expect(listingPhotoPathFromUrl('$publicBase/$shop/pets/abc.jpg?width=400'), '$shop/pets/abc.jpg');
      expect(listingPhotoPathFromUrl('$publicBase/$shop/pets/abc.jpg#top'), '$shop/pets/abc.jpg');
    });

    test('decodes percent-encoding', () {
      expect(listingPhotoPathFromUrl('$publicBase/$shop/pets/my%20dog.jpg'), '$shop/pets/my dog.jpg');
    });

    test('returns null for external images and other buckets, so they are never deleted', () {
      expect(listingPhotoPathFromUrl('https://images.dog.ceo/breeds/labrador/n02099712_2897.jpg'), isNull);
      expect(listingPhotoPathFromUrl('https://x.supabase.co/storage/v1/object/public/other-bucket/a.jpg'), isNull);
      expect(listingPhotoPathFromUrl(''), isNull);
      expect(listingPhotoPathFromUrl('$publicBase/'), isNull);
    });
  });
}
