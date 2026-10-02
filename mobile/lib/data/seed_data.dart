/// Mirrors src/data/pets.js and src/data/shops.js in the web app 1:1 --
/// the same seeded, static catalog (not the Supabase `pets`/`shops` tables,
/// which have a different shape and are used elsewhere for Store/seller/
/// admin screens). Home, PetsList, PetDetail, Shops, ShopDetail, Cart,
/// Checkout and Reserve all browse this catalog exactly like the website
/// does, with no network calls.
library;

class SeedPet {
  final String id;
  final String name;
  final String species;
  final String breed;
  final String gender;
  final String ageLabel;
  final num price;
  final String shopId;
  final String status; // available | sold
  final DateTime listedDate;
  final List<String>? photos;
  final String description;

  const SeedPet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.gender,
    required this.ageLabel,
    required this.price,
    required this.shopId,
    required this.status,
    required this.listedDate,
    required this.photos,
    required this.description,
  });
}

class SeedShop {
  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String licenseNumber;
  final double rating;
  final int reviewCount;

  const SeedShop({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.licenseNumber,
    required this.rating,
    required this.reviewCount,
  });
}

// Not `const`: each entry's `listedDate: DateTime(...)` is not a compile-time
// constant (DateTime has no const constructor), so the list itself can only
// be a runtime-constructed (`final`) list even though its contents never change.
final List<SeedPet> seedPets = [
  SeedPet(
    id: 'otis',
    name: 'Otis',
    species: 'Dog',
    breed: 'Labrador Retriever',
    gender: 'Male',
    ageLabel: '6 months',
    price: 875,
    shopId: 'thistledown',
    status: 'available',
    listedDate: DateTime(2026, 9, 15),
    photos: [
      'https://images.dog.ceo/breeds/labrador/labrador_zack_01.jpg',
      'https://images.dog.ceo/breeds/labrador/n02099712_6646.jpg',
      'https://images.dog.ceo/breeds/labrador/n02099712_2897.jpg',
    ],
    description:
        "Otis has the classic Lab motor: swims, fetches, chews anything left at ankle height. Been through his first round of obedience basics and knows sit and stay.",
  ),
  SeedPet(
    id: 'biscuit',
    name: 'Biscuit',
    species: 'Dog',
    breed: 'Beagle',
    gender: 'Male',
    ageLabel: '5 months',
    price: 650,
    shopId: 'whisker-wag',
    status: 'available',
    listedDate: DateTime(2026, 9, 12),
    photos: [
      'https://images.dog.ceo/breeds/beagle/n02088364_12920.jpg',
      'https://images.dog.ceo/breeds/beagle/n02088364_1507.jpg',
      'https://images.dog.ceo/breeds/beagle/n02088364_129.jpg',
    ],
    description:
        "Loud nose, louder bark. Biscuit tracks a treat across a room by scent alone. Good with other dogs, still learning not to bay at the mail carrier.",
  ),
  SeedPet(
    id: 'juniper',
    name: 'Juniper',
    species: 'Dog',
    breed: 'Golden Retriever',
    gender: 'Female',
    ageLabel: '4 months',
    price: 950,
    shopId: 'hollow-creek',
    status: 'available',
    listedDate: DateTime(2026, 9, 17),
    photos: [
      'https://images.dog.ceo/breeds/retriever-golden/pxl_20220624_150113115.mp_2.jpg',
      'https://images.dog.ceo/breeds/retriever-golden/20200731_180910_200731.jpg',
      'https://images.dog.ceo/breeds/retriever-golden/n02099601_9518.jpg',
    ],
    description:
        "Juniper is the calmer of her litter, happy to nap through a slow afternoon but perks right up for a tennis ball. Crate-trained overnight.",
  ),
  SeedPet(
    id: 'theo',
    name: 'Theo',
    species: 'Dog',
    breed: 'Standard Poodle',
    gender: 'Male',
    ageLabel: '7 months',
    price: 825,
    shopId: 'thistledown',
    status: 'sold',
    listedDate: DateTime(2026, 9, 5),
    photos: [
      'https://images.dog.ceo/breeds/poodle-standard/n02113799_7726.jpg',
      'https://images.dog.ceo/breeds/poodle-standard/n02113799_2292.jpg',
      'https://images.dog.ceo/breeds/poodle-standard/n02113799_4642.jpg',
    ],
    description:
        "Sharp, low-shed coat and quick to pick up commands. Theo's already gone home with his new family — leaving him listed here for reference.",
  ),
  SeedPet(
    id: 'mochi',
    name: 'Mochi',
    species: 'Cat',
    breed: 'Siamese',
    gender: 'Male',
    ageLabel: '3 months',
    price: 450,
    shopId: 'whisker-wag',
    status: 'available',
    listedDate: DateTime(2026, 9, 16),
    photos: [
      'https://cdn2.thecatapi.com/images/__tqyLW91.jpg',
      'https://cdn2.thecatapi.com/images/e0sS4bZcP.jpg',
      'https://cdn2.thecatapi.com/images/VsaXX13yt.jpg',
    ],
    description:
        "Talks constantly and follows staff between rooms. Litter-trained, good with the shop's resident cats, a little unsure around dogs so far.",
  ),
  SeedPet(
    id: 'clementine',
    name: 'Clementine',
    species: 'Cat',
    breed: 'Maine Coon',
    gender: 'Female',
    ageLabel: '5 months',
    price: 525,
    shopId: 'hollow-creek',
    status: 'available',
    listedDate: DateTime(2026, 9, 8),
    photos: [
      'https://cdn2.thecatapi.com/images/6JCuKEGDQ.jpg',
      'https://cdn2.thecatapi.com/images/luT74s8zp.jpg',
      'https://cdn2.thecatapi.com/images/HD4lZB6BI.jpg',
    ],
    description:
        "Already showing the long Maine Coon frame and a thick coat that needs brushing twice a week. Prefers watching from a high shelf to being held.",
  ),
  SeedPet(
    id: 'hazel',
    name: 'Hazel',
    species: 'Cat',
    breed: 'British Shorthair',
    gender: 'Female',
    ageLabel: '4 months',
    price: 475,
    shopId: 'thistledown',
    status: 'available',
    listedDate: DateTime(2026, 9, 3),
    photos: [
      'https://cdn2.thecatapi.com/images/GrPErz7EA.jpg',
      'https://cdn2.thecatapi.com/images/4QlywK9_Y.jpg',
      'https://cdn2.thecatapi.com/images/IouWtnMl2.jpg',
    ],
    description:
        "Dense blue-gray coat and the round British Shorthair face. Low-key even for a kitten, more interested in sitting near people than climbing on them.",
  ),
  SeedPet(
    id: 'wren',
    name: 'Wren',
    species: 'Bird',
    breed: 'Cockatiel',
    gender: 'Male',
    ageLabel: '7 months',
    price: 140,
    shopId: 'whisker-wag',
    status: 'available',
    listedDate: DateTime(2026, 9, 1),
    photos: null,
    description:
        "Whistles the first four notes of a tune the last owner taught him and has started stringing them together unprompted. Hand-tame, steps up without coaxing.",
  ),
  SeedPet(
    id: 'pepper',
    name: 'Pepper',
    species: 'Bird',
    breed: 'Parakeet',
    gender: 'Female',
    ageLabel: '5 months',
    price: 85,
    shopId: 'hollow-creek',
    status: 'available',
    listedDate: DateTime(2026, 9, 14),
    photos: null,
    description:
        "Bright green and yellow, still building confidence outside her cage. Chatters constantly once she settles into a new room.",
  ),
  SeedPet(
    id: 'basil',
    name: 'Basil',
    species: 'Rabbit',
    breed: 'Holland Lop',
    gender: 'Male',
    ageLabel: '10 weeks',
    price: 85,
    shopId: 'hollow-creek',
    status: 'available',
    listedDate: DateTime(2026, 9, 13),
    photos: null,
    description:
        "Litter-box trained for a rabbit his age and tolerates gentle handling well. Lop ears, black otter coloring, from a small home-breeder litter of four.",
  ),
  SeedPet(
    id: 'clove',
    name: 'Clove',
    species: 'Rabbit',
    breed: 'Mini Rex',
    gender: 'Female',
    ageLabel: '12 weeks',
    price: 70,
    shopId: 'thistledown',
    status: 'available',
    listedDate: DateTime(2026, 9, 6),
    photos: null,
    description:
        "Velveteen Mini Rex coat, chinchilla-gray. Skittish the first week in a new room, settles fast once she has a hide box.",
  ),
  SeedPet(
    id: 'nutmeg',
    name: 'Nutmeg',
    species: 'Small Pet',
    breed: 'Abyssinian Guinea Pig',
    gender: 'Female',
    ageLabel: '8 weeks',
    price: 45,
    shopId: 'whisker-wag',
    status: 'available',
    listedDate: DateTime(2026, 9, 17),
    photos: null,
    description:
        "Rosetted coat that grows in swirls rather than flat, needs a bit more brushing than a smooth-coat guinea pig. Loud about vegetables, quiet otherwise.",
  ),
];

SeedPet? getSeedPetById(String id) {
  for (final pet in seedPets) {
    if (pet.id == id) return pet;
  }
  return null;
}

List<SeedPet> getSeedPetsByShop(String shopId) =>
    seedPets.where((p) => p.shopId == shopId).toList();

const List<SeedShop> seedShops = [
  SeedShop(
    id: 'thistledown',
    name: 'Thistledown Pets & Aquatics',
    address: '214 Alder Street, Alder Creek, OR 97213',
    city: 'Alder Creek, OR',
    phone: '(503) 555-0142',
    licenseNumber: 'OR-PD-04821',
    rating: 4.8,
    reviewCount: 126,
  ),
  SeedShop(
    id: 'whisker-wag',
    name: 'Whisker & Wag Pet Co.',
    address: '88 Portside Avenue, Portside, OR 97035',
    city: 'Portside, OR',
    phone: '(503) 555-0176',
    licenseNumber: 'OR-PD-03390',
    rating: 4.6,
    reviewCount: 89,
  ),
  SeedShop(
    id: 'hollow-creek',
    name: 'Hollow Creek Exotics & Small Animals',
    address: '1470 Fernbridge Road, Fernbridge, OR 97140',
    city: 'Fernbridge, OR',
    phone: '(503) 555-0119',
    licenseNumber: 'OR-PD-05502',
    rating: 4.9,
    reviewCount: 41,
  ),
  SeedShop(
    id: 'cedar-sage',
    name: 'Cedar & Sage Pet Supply',
    address: '1002 Birchwood Lane, Alder Creek, OR 97213',
    city: 'Alder Creek, OR',
    phone: '(503) 555-0188',
    licenseNumber: 'OR-PD-06110',
    rating: 0,
    reviewCount: 0,
  ),
];

SeedShop? getSeedShopById(String id) {
  for (final shop in seedShops) {
    if (shop.id == id) return shop;
  }
  return null;
}

const List<String> speciesList = ['Dog', 'Cat', 'Bird', 'Rabbit', 'Small Pet'];

List<String> get breedList =>
    ({for (final p in seedPets) p.breed}.toList()..sort());

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

List<SeedPet> applyPetFilters(List<SeedPet> pets, PetFilterParams params) {
  return pets.where((pet) {
    if (params.species.isNotEmpty && !params.species.contains(pet.species))
      return false;
    if (params.shops.isNotEmpty && !params.shops.contains(pet.shopId))
      return false;
    if (params.breeds.isNotEmpty && !params.breeds.contains(pet.breed))
      return false;
    if (params.minPrice != null && pet.price < params.minPrice!) return false;
    if (params.maxPrice != null && pet.price > params.maxPrice!) return false;
    return true;
  }).toList();
}

enum PetSort { newest, priceAsc, priceDesc }

List<SeedPet> sortPets(List<SeedPet> pets, PetSort sort) {
  final sorted = [...pets];
  switch (sort) {
    case PetSort.priceAsc:
      sorted.sort((a, b) => a.price.compareTo(b.price));
      break;
    case PetSort.priceDesc:
      sorted.sort((a, b) => b.price.compareTo(a.price));
      break;
    case PetSort.newest:
      sorted.sort((a, b) => b.listedDate.compareTo(a.listedDate));
      break;
  }
  return sorted;
}
