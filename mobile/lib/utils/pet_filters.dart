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
