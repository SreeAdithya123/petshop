import 'package:flutter_test/flutter_test.dart';
import 'package:pawsnearby/data/columns.dart';
import 'package:pawsnearby/data/service_categories.dart';
import 'package:pawsnearby/models/models.dart';
import 'package:pawsnearby/models/service_models.dart';
import 'package:pawsnearby/utils/video_room.dart';

void main() {
  group('Shop.fromJson', () {
    test('tolerates the name-only embed used on customer queries', () {
      final shop = Shop.fromJson({'name': 'Pawsome Pets'});
      expect(shop.name, 'Pawsome Pets');
      expect(shop.address, '');
      expect(shop.phone, '');
      expect(shop.id, '');
    });

    test('parses a public-columns row', () {
      final shop = Shop.fromJson({
        'id': 's1',
        'name': 'Happy Kennel',
        'description': 'Friendly',
        'banner_url': null,
        'license_number': 'KA-1',
        'status': 'approved',
        'created_at': '2026-10-01T10:00:00Z',
      });
      expect(shop.id, 's1');
      expect(shop.licenseNumber, 'KA-1');
      expect(shop.status, 'approved');
      expect(shop.createdAt.year, 2026);
    });
  });

  group('Profile.fromJson', () {
    test('tolerates partial embeds such as profiles(name)', () {
      final profile = Profile.fromJson({'name': 'Asha'});
      expect(profile.name, 'Asha');
      expect(profile.id, '');
      expect(profile.role, '');
    });

    test('parses a full row', () {
      final profile = Profile.fromJson({
        'id': 'u1',
        'role': 'customer',
        'name': 'Sasi',
        'phone': '9999999999',
        'email': 'a@b.co',
        'created_at': '2026-09-01T00:00:00Z',
      });
      expect(profile.role, 'customer');
      expect(profile.phone, '9999999999');
    });
  });

  group('Pet.fromJson', () {
    final row = {
      'id': 'p1',
      'shop_id': 's1',
      'species': 'Dog',
      'breed': 'Golden Retriever',
      'age_months': 3,
      'price': 30000,
      'description': null,
      'photo_urls': ['https://example.com/a.jpg'],
      'status': 'available',
      'created_at': '2026-10-01T10:00:00Z',
      'name': 'Max',
      'gender': 'Male',
      'certification': null,
      'shops': {'name': 'Pawsome'},
    };

    test('parses the public columns and the shop-name embed', () {
      final pet = Pet.fromJson(row);
      expect(pet.displayName, 'Max');
      expect(pet.gender, 'Male');
      expect(pet.photoUrls, hasLength(1));
      expect(pet.shop?.name, 'Pawsome');
      expect(pet.price, 30000);
    });

    test('unnamed pets fall back to their breed; unknown gender stays null', () {
      final pet = Pet.fromJson({...row, 'name': null, 'gender': null, 'shops': null});
      expect(pet.displayName, 'Golden Retriever');
      expect(pet.gender, isNull);
      expect(pet.shop, isNull);
    });

    test('missing photo_urls and age do not crash', () {
      final pet = Pet.fromJson({...row, 'photo_urls': null, 'age_months': null});
      expect(pet.photoUrls, isEmpty);
      expect(pet.ageMonths, 0);
    });
  });

  group('Product.fromJson', () {
    test('requires_prescription defaults to false', () {
      final product = Product.fromJson({
        'id': 'x',
        'shop_id': 's',
        'category': 'medicine',
        'name': 'Shampoo',
        'price': 349,
        'stock_quantity': 40,
        'photo_urls': null,
        'status': 'available',
        'created_at': '2026-10-01T10:00:00Z',
      });
      expect(product.requiresPrescription, isFalse);
      expect(product.photoUrls, isEmpty);
    });
  });

  group('service models', () {
    test('ServiceItem with shop embed', () {
      final item = ServiceItem.fromJson({
        'id': 'sv1',
        'shop_id': 's1',
        'category': 'vet',
        'name': 'Vet Teleconsultation',
        'price': 499,
        'duration_minutes': 15,
        'status': 'approved',
        'created_at': '2026-10-01T10:00:00Z',
        'shops': {'name': 'Pawsome'},
      });
      expect(item.shopName, 'Pawsome');
      expect(item.durationMinutes, 15);
      expect(item.photoUrls, isEmpty);
    });

    test('ServiceBooking keeps the time string and date', () {
      final booking = ServiceBooking.fromJson({
        'id': 'b1',
        'service_id': 'sv1',
        'shop_id': 's1',
        'customer_id': 'u1',
        'booking_date': '2026-10-20',
        'booking_time': '14:30:00',
        'delivery_mode': 'video',
        'status': 'pending',
        'price_at_booking': 499,
        'created_at': '2026-10-01T10:00:00Z',
      });
      expect(booking.bookingDate.day, 20);
      expect(booking.bookingTime, '14:30:00');
      expect(booking.deliveryMode, 'video');
      expect(booking.videoRoomUrl, isNull);
    });

    test('DemoRequest and CustomServiceRequest', () {
      final demo = DemoRequest.fromJson({
        'id': 'd1',
        'customer_id': 'u1',
        'pet_id': 'p1',
        'shop_id': 's1',
        'preferred_date': '2026-10-20',
        'preferred_time': '11:00 AM',
        'mode': 'video',
        'status': 'approved',
        'meet_link': 'https://meet.jit.si/x',
        'created_at': '2026-10-01T10:00:00Z',
      });
      expect(demo.preferredTime, '11:00 AM');
      expect(demo.meetLink, 'https://meet.jit.si/x');

      final request = CustomServiceRequest.fromJson({
        'id': 'c1',
        'customer_id': 'u1',
        'title': 'Home grooming',
        'description': 'Please',
        'budget': 1500,
        'status': 'quoted',
        'quoted_price': 1200,
        'created_at': '2026-10-01T10:00:00Z',
      });
      expect(request.quotedPrice, 1200);
      expect(request.preferredDate, isNull);
    });

    test('SavedAddress.summary joins the non-empty parts', () {
      final address = SavedAddress.fromJson({
        'id': 'a1',
        'customer_id': 'u1',
        'label': 'Home',
        'line1': '12 MG Road',
        'line2': '',
        'city': 'Bengaluru',
        'state': 'KA',
        'zip': '560001',
        'is_default': true,
        'created_at': '2026-10-01T10:00:00Z',
      });
      expect(address.summary, '12 MG Road, Bengaluru, KA, 560001');
      expect(address.isDefault, isTrue);
    });

    test('OrderLine parses the order_items_detailed row', () {
      final line = OrderLine.fromJson({
        'order_item_id': 'oi1',
        'item_type': 'pet',
        'item_id': 'p1',
        'quantity': 1,
        'price_at_purchase': 30000,
        'label': 'Max (Golden Retriever)',
        'shop_id': 's1',
        'shop_name': 'Pawsome',
      });
      expect(line.label, 'Max (Golden Retriever)');
      expect(line.quantity, 1);
    });
  });

  group('privacy: public column lists', () {
    test('never request cost_price, address or phone', () {
      for (final columns in [petPublicColumns, productPublicColumns, shopPublicColumns, servicePublicColumns]) {
        expect(columns, isNot(contains('cost_price')));
        expect(columns, isNot(contains('address')));
        expect(columns, isNot(contains('phone')));
        expect(columns, isNot(contains('*')));
      }
    });
  });

  group('service categories', () {
    test('cover every enum value and fall back for unknown ones', () {
      expect(serviceCategories.map((c) => c.key), [
        'vet',
        'grooming',
        'trimming',
        'bathing',
        'training',
        'walking',
        'daycare',
        'boarding',
      ]);
      expect(serviceCategoryLabel('vet'), 'Vet');
      expect(serviceCategoryLabel('nope'), 'Other');
      expect(serviceCategoryLabel(null), 'Other');
    });
  });

  group('video links', () {
    test('jitsiRoomUrl is deterministic and has no dashes', () {
      final url = jitsiRoomUrl('1234-abcd-5678');
      expect(url, 'https://meet.jit.si/PETSTA-1234abcd5678');
      expect(jitsiRoomUrl('1234-abcd-5678'), url);
    });

    test('isSafeWebLink accepts only http(s) links with a host', () {
      expect(isSafeWebLink('https://meet.jit.si/room'), isTrue);
      expect(isSafeWebLink('http://example.com'), isTrue);
      expect(isSafeWebLink('javascript:alert(1)'), isFalse);
      expect(isSafeWebLink('ftp://example.com'), isFalse);
      expect(isSafeWebLink('https://'), isFalse);
      expect(isSafeWebLink(''), isFalse);
      expect(isSafeWebLink(null), isFalse);
    });
  });
}
