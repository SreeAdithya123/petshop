export function applyPetFilters(pets, { species = [], shops = [], breeds = [], minPrice, maxPrice }) {
  return pets.filter((pet) => {
    if (species.length && !species.includes(pet.species)) return false;
    if (shops.length && !shops.includes(pet.shopId)) return false;
    if (breeds.length && !breeds.includes(pet.breed)) return false;
    if (minPrice != null && !Number.isNaN(minPrice) && pet.price < minPrice) return false;
    if (maxPrice != null && !Number.isNaN(maxPrice) && pet.price > maxPrice) return false;
    return true;
  });
}

export function sortPets(pets, sort) {
  const sorted = [...pets];
  switch (sort) {
    case "price-asc":
      return sorted.sort((a, b) => a.price - b.price);
    case "price-desc":
      return sorted.sort((a, b) => b.price - a.price);
    case "newest":
    default:
      return sorted.sort((a, b) => new Date(b.listedDate) - new Date(a.listedDate));
  }
}
