/**
 * Seeded pet listings.
 *
 * Photo sourcing (see /docs/decisions.md for the full breed→API mapping):
 *  - Dog and Cat entries carry `photos`: 3 URLs each, resolved from a real
 *    breed photo API (Dog CEO / TheCatAPI) and verified one by one
 *    (HTTP 200, image/*) before being hardcoded here. These are static CDN
 *    URLs, not live fetches, so the app has no runtime dependency on
 *    either API and a gallery works the same offline as online.
 *  - Bird, Rabbit, and Small Pet entries have `photos: null` — there's no
 *    reliable free breed-photo API for these, so PetPhoto renders the
 *    hand-illustrated SpeciesIcon instead of a mismatched stock photo.
 */
export const pets = [
  {
    id: "otis",
    name: "Otis",
    species: "Dog",
    breed: "Labrador Retriever",
    gender: "Male",
    ageLabel: "6 months",
    price: 875,
    shopId: "thistledown",
    status: "available",
    listedDate: "2026-09-15",
    photos: [
      "https://images.dog.ceo/breeds/labrador/labrador_zack_01.jpg",
      "https://images.dog.ceo/breeds/labrador/n02099712_6646.jpg",
      "https://images.dog.ceo/breeds/labrador/n02099712_2897.jpg",
    ],
    description:
      "Otis has the classic Lab motor: swims, fetches, chews anything left at ankle height. Been through his first round of obedience basics and knows sit and stay.",
  },
  {
    id: "biscuit",
    name: "Biscuit",
    species: "Dog",
    breed: "Beagle",
    gender: "Male",
    ageLabel: "5 months",
    price: 650,
    shopId: "whisker-wag",
    status: "available",
    listedDate: "2026-09-12",
    photos: [
      "https://images.dog.ceo/breeds/beagle/n02088364_12920.jpg",
      "https://images.dog.ceo/breeds/beagle/n02088364_1507.jpg",
      "https://images.dog.ceo/breeds/beagle/n02088364_129.jpg",
    ],
    description:
      "Loud nose, louder bark. Biscuit tracks a treat across a room by scent alone. Good with other dogs, still learning not to bay at the mail carrier.",
  },
  {
    id: "juniper",
    name: "Juniper",
    species: "Dog",
    breed: "Golden Retriever",
    gender: "Female",
    ageLabel: "4 months",
    price: 950,
    shopId: "hollow-creek",
    status: "available",
    listedDate: "2026-09-17",
    photos: [
      "https://images.dog.ceo/breeds/retriever-golden/pxl_20220624_150113115.mp_2.jpg",
      "https://images.dog.ceo/breeds/retriever-golden/20200731_180910_200731.jpg",
      "https://images.dog.ceo/breeds/retriever-golden/n02099601_9518.jpg",
    ],
    description:
      "Juniper is the calmer of her litter, happy to nap through a slow afternoon but perks right up for a tennis ball. Crate-trained overnight.",
  },
  {
    id: "theo",
    name: "Theo",
    species: "Dog",
    breed: "Standard Poodle",
    gender: "Male",
    ageLabel: "7 months",
    price: 825,
    shopId: "thistledown",
    status: "sold",
    listedDate: "2026-09-05",
    photos: [
      "https://images.dog.ceo/breeds/poodle-standard/n02113799_7726.jpg",
      "https://images.dog.ceo/breeds/poodle-standard/n02113799_2292.jpg",
      "https://images.dog.ceo/breeds/poodle-standard/n02113799_4642.jpg",
    ],
    description:
      "Sharp, low-shed coat and quick to pick up commands. Theo's already gone home with his new family — leaving him listed here for reference.",
  },
  {
    id: "mochi",
    name: "Mochi",
    species: "Cat",
    breed: "Siamese",
    gender: "Male",
    ageLabel: "3 months",
    price: 450,
    shopId: "whisker-wag",
    status: "available",
    listedDate: "2026-09-16",
    photos: [
      "https://cdn2.thecatapi.com/images/__tqyLW91.jpg",
      "https://cdn2.thecatapi.com/images/e0sS4bZcP.jpg",
      "https://cdn2.thecatapi.com/images/VsaXX13yt.jpg",
    ],
    description:
      "Talks constantly and follows staff between rooms. Litter-trained, good with the shop's resident cats, a little unsure around dogs so far.",
  },
  {
    id: "clementine",
    name: "Clementine",
    species: "Cat",
    breed: "Maine Coon",
    gender: "Female",
    ageLabel: "5 months",
    price: 525,
    shopId: "hollow-creek",
    status: "available",
    listedDate: "2026-09-08",
    photos: [
      "https://cdn2.thecatapi.com/images/6JCuKEGDQ.jpg",
      "https://cdn2.thecatapi.com/images/luT74s8zp.jpg",
      "https://cdn2.thecatapi.com/images/HD4lZB6BI.jpg",
    ],
    description:
      "Already showing the long Maine Coon frame and a thick coat that needs brushing twice a week. Prefers watching from a high shelf to being held.",
  },
  {
    id: "hazel",
    name: "Hazel",
    species: "Cat",
    breed: "British Shorthair",
    gender: "Female",
    ageLabel: "4 months",
    price: 475,
    shopId: "thistledown",
    status: "available",
    listedDate: "2026-09-03",
    photos: [
      "https://cdn2.thecatapi.com/images/GrPErz7EA.jpg",
      "https://cdn2.thecatapi.com/images/4QlywK9_Y.jpg",
      "https://cdn2.thecatapi.com/images/IouWtnMl2.jpg",
    ],
    description:
      "Dense blue-gray coat and the round British Shorthair face. Low-key even for a kitten, more interested in sitting near people than climbing on them.",
  },
  {
    id: "wren",
    name: "Wren",
    species: "Bird",
    breed: "Cockatiel",
    gender: "Male",
    ageLabel: "7 months",
    price: 140,
    shopId: "whisker-wag",
    status: "available",
    listedDate: "2026-09-01",
    photos: null,
    description:
      "Whistles the first four notes of a tune the last owner taught him and has started stringing them together unprompted. Hand-tame, steps up without coaxing.",
  },
  {
    id: "pepper",
    name: "Pepper",
    species: "Bird",
    breed: "Parakeet",
    gender: "Female",
    ageLabel: "5 months",
    price: 85,
    shopId: "hollow-creek",
    status: "available",
    listedDate: "2026-09-14",
    photos: null,
    description:
      "Bright green and yellow, still building confidence outside her cage. Chatters constantly once she settles into a new room.",
  },
  {
    id: "basil",
    name: "Basil",
    species: "Rabbit",
    breed: "Holland Lop",
    gender: "Male",
    ageLabel: "10 weeks",
    price: 85,
    shopId: "hollow-creek",
    status: "available",
    listedDate: "2026-09-13",
    photos: null,
    description:
      "Litter-box trained for a rabbit his age and tolerates gentle handling well. Lop ears, black otter coloring, from a small home-breeder litter of four.",
  },
  {
    id: "clove",
    name: "Clove",
    species: "Rabbit",
    breed: "Mini Rex",
    gender: "Female",
    ageLabel: "12 weeks",
    price: 70,
    shopId: "thistledown",
    status: "available",
    listedDate: "2026-09-06",
    photos: null,
    description:
      "Velveteen Mini Rex coat, chinchilla-gray. Skittish the first week in a new room, settles fast once she has a hide box.",
  },
  {
    id: "nutmeg",
    name: "Nutmeg",
    species: "Small Pet",
    breed: "Abyssinian Guinea Pig",
    gender: "Female",
    ageLabel: "8 weeks",
    price: 45,
    shopId: "whisker-wag",
    status: "available",
    listedDate: "2026-09-17",
    photos: null,
    description:
      "Rosetted coat that grows in swirls rather than flat, needs a bit more brushing than a smooth-coat guinea pig. Loud about vegetables, quiet otherwise.",
  },
];

export function getPetById(id) {
  return pets.find((pet) => pet.id === id);
}

export function getPetsByShop(shopId) {
  return pets.filter((pet) => pet.shopId === shopId);
}

export const speciesList = ["Dog", "Cat", "Bird", "Rabbit", "Small Pet"];
export const breedList = [...new Set(pets.map((pet) => pet.breed))].sort();
