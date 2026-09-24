/**
 * Seeded shop directory. Placeholder license numbers and phone numbers
 * (555 exchange) — swap for real store records when the backend lands.
 *
 * Cedar & Sage is deliberately a brand-new shop with zero listings and zero
 * reviews, so both "New shop" (zero reviews) and "no pets listed right
 * now" (zero inventory) edge cases are demonstrated by real seed data
 * rather than only by code paths nobody exercises.
 */
export const shops = [
  {
    id: "thistledown",
    name: "Thistledown Pets & Aquatics",
    address: "214 Alder Street, Alder Creek, OR 97213",
    city: "Alder Creek, OR",
    phone: "(503) 555-0142",
    licenseNumber: "OR-PD-04821",
    rating: 4.8,
    reviewCount: 126,
  },
  {
    id: "whisker-wag",
    name: "Whisker & Wag Pet Co.",
    address: "88 Portside Avenue, Portside, OR 97035",
    city: "Portside, OR",
    phone: "(503) 555-0176",
    licenseNumber: "OR-PD-03390",
    rating: 4.6,
    reviewCount: 89,
  },
  {
    id: "hollow-creek",
    name: "Hollow Creek Exotics & Small Animals",
    address: "1470 Fernbridge Road, Fernbridge, OR 97140",
    city: "Fernbridge, OR",
    phone: "(503) 555-0119",
    licenseNumber: "OR-PD-05502",
    rating: 4.9,
    reviewCount: 41,
  },
  {
    id: "cedar-sage",
    name: "Cedar & Sage Pet Supply",
    address: "1002 Birchwood Lane, Alder Creek, OR 97213",
    city: "Alder Creek, OR",
    phone: "(503) 555-0188",
    licenseNumber: "OR-PD-06110",
    rating: 0,
    reviewCount: 0,
  },
];

export function getShopById(id) {
  return shops.find((shop) => shop.id === id);
}
