import '../models/models.dart';

/// Mirrors src/lib/petFilters.js, on the database [Pet] model.
class PetFilterParams {
  final List<String> species;
  final List<String> shops;
  final List<String> breeds;
  final double? minPrice;
  final double? maxPrice;

  const PetFilterParams({
    this.species = const [],
    this.shops = const [],
    this.breeds = const [],
    this.minPrice,
    this.maxPrice,
  });

  /// True when no filter is set.
  bool get isEmpty =>
      species.isEmpty && shops.isEmpty && breeds.isEmpty && minPrice == null && maxPrice == null;

  /// True when both bounds are set and the minimum is above the maximum, which
  /// can never match anything.
  bool get hasInvertedPriceRange => minPrice != null && maxPrice != null && minPrice! > maxPrice!;
}

List<Pet> applyPetFilters(List<Pet> pets, PetFilterParams params) {
  return pets.where((pet) {
    if (params.species.isNotEmpty && !params.species.contains(pet.species)) return false;
    if (params.shops.isNotEmpty && !params.shops.contains(pet.shopId)) return false;
    if (params.breeds.isNotEmpty && !params.breeds.contains(pet.breed)) return false;
    if (params.minPrice != null && pet.price < params.minPrice!) return false;
    if (params.maxPrice != null && pet.price > params.maxPrice!) return false;
    return true;
  }).toList();
}

enum PetSort { newest, priceAsc, priceDesc, ageAsc }

List<Pet> sortPets(List<Pet> pets, PetSort sort) {
  final sorted = [...pets];
  switch (sort) {
    case PetSort.priceAsc:
      sorted.sort((a, b) => a.price.compareTo(b.price));
    case PetSort.priceDesc:
      sorted.sort((a, b) => b.price.compareTo(a.price));
    case PetSort.ageAsc:
      sorted.sort((a, b) => a.ageMonths.compareTo(b.ageMonths));
    case PetSort.newest:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return sorted;
}

/// Reads the `sort` query parameter used by the web app's /pets URLs
/// ("price-asc", "price-desc", "age-asc"); anything else means newest first.
PetSort petSortFromParam(String? raw) {
  switch (raw) {
    case 'price-asc':
      return PetSort.priceAsc;
    case 'price-desc':
      return PetSort.priceDesc;
    case 'age-asc':
      return PetSort.ageAsc;
    default:
      return PetSort.newest;
  }
}

/// Splits a comma-separated query parameter ("Dog,Cat") into its non-empty
/// parts; null or empty input gives an empty list.
List<String> parseListParam(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  return raw.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
}

/// Parses a whole-rupee price typed into a filter field. Blank, non-numeric
/// and negative input gives null (no bound).
double? parsePriceInput(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value < 0) return null;
  return value;
}
