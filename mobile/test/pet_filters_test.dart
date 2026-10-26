import 'package:flutter_test/flutter_test.dart';
import 'package:pawsnearby/models/models.dart';
import 'package:pawsnearby/utils/pet_filters.dart';

Pet pet(
  String id, {
  String species = 'Dog',
  String breed = 'Labrador',
  String shopId = 'shop-a',
  int ageMonths = 6,
  num price = 20000,
  DateTime? createdAt,
}) {
  return Pet(
    id: id,
    shopId: shopId,
    species: species,
    breed: breed,
    ageMonths: ageMonths,
    price: price,
    photoUrls: const [],
    status: 'available',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  final pets = [
    pet('lab', breed: 'Labrador', price: 20000, ageMonths: 6, createdAt: DateTime(2026, 3, 1)),
    pet('pug', breed: 'Pug', price: 15000, ageMonths: 3, shopId: 'shop-b', createdAt: DateTime(2026, 2, 1)),
    pet('persian', species: 'Cat', breed: 'Persian', price: 28000, ageMonths: 4, createdAt: DateTime(2026, 4, 1)),
  ];

  List<String> ids(List<Pet> list) => list.map((p) => p.id).toList();

  group('applyPetFilters', () {
    test('no filters returns everything', () {
      expect(ids(applyPetFilters(pets, const PetFilterParams())), ['lab', 'pug', 'persian']);
    });

    test('filters by species, shop and breed', () {
      expect(ids(applyPetFilters(pets, const PetFilterParams(species: ['Cat']))), ['persian']);
      expect(ids(applyPetFilters(pets, const PetFilterParams(shops: ['shop-b']))), ['pug']);
      expect(ids(applyPetFilters(pets, const PetFilterParams(breeds: ['Pug', 'Persian']))), ['pug', 'persian']);
    });

    test('price bounds are inclusive', () {
      expect(ids(applyPetFilters(pets, const PetFilterParams(minPrice: 20000, maxPrice: 28000))), ['lab', 'persian']);
      expect(ids(applyPetFilters(pets, const PetFilterParams(maxPrice: 14999))), isEmpty);
    });

    test('filters combine with AND', () {
      expect(ids(applyPetFilters(pets, const PetFilterParams(species: ['Dog'], maxPrice: 16000))), ['pug']);
    });
  });

  group('sortPets', () {
    test('newest first by default', () {
      expect(ids(sortPets(pets, PetSort.newest)), ['persian', 'lab', 'pug']);
    });

    test('price ascending / descending', () {
      expect(ids(sortPets(pets, PetSort.priceAsc)), ['pug', 'lab', 'persian']);
      expect(ids(sortPets(pets, PetSort.priceDesc)), ['persian', 'lab', 'pug']);
    });

    test('youngest first', () {
      expect(ids(sortPets(pets, PetSort.ageAsc)), ['pug', 'persian', 'lab']);
    });

    test('does not mutate the input list', () {
      final copy = [...pets];
      sortPets(pets, PetSort.priceDesc);
      expect(ids(pets), ids(copy));
    });
  });

  group('query-parameter helpers', () {
    test('petSortFromParam', () {
      expect(petSortFromParam('price-asc'), PetSort.priceAsc);
      expect(petSortFromParam('price-desc'), PetSort.priceDesc);
      expect(petSortFromParam('age-asc'), PetSort.ageAsc);
      expect(petSortFromParam(null), PetSort.newest);
      expect(petSortFromParam('nonsense'), PetSort.newest);
    });

    test('parseListParam', () {
      expect(parseListParam('Dog,Cat'), ['Dog', 'Cat']);
      expect(parseListParam(' Dog , ,Cat '), ['Dog', 'Cat']);
      expect(parseListParam(''), isEmpty);
      expect(parseListParam(null), isEmpty);
    });

    test('parsePriceInput', () {
      expect(parsePriceInput('25,000'), 25000);
      expect(parsePriceInput(' 150 '), 150);
      expect(parsePriceInput(''), isNull);
      expect(parsePriceInput('abc'), isNull);
      expect(parsePriceInput('-5'), isNull);
      expect(parsePriceInput(null), isNull);
    });

    test('PetFilterParams flags', () {
      expect(const PetFilterParams().isEmpty, isTrue);
      expect(const PetFilterParams(species: ['Dog']).isEmpty, isFalse);
      expect(const PetFilterParams(minPrice: 10, maxPrice: 5).hasInvertedPriceRange, isTrue);
      expect(const PetFilterParams(minPrice: 5, maxPrice: 10).hasInvertedPriceRange, isFalse);
    });
  });
}
