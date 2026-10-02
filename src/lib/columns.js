/**
 * Column lists for customer-facing queries.
 *
 * `pets.cost_price` and `products.cost_price` are seller-only margins, and
 * `shops.address` / `shops.phone` are shop contact details that customers
 * never see. Row-level security can't hide individual columns, so every
 * customer-facing page must select an explicit list instead of "*".
 * (Seller / admin pages scoped to their own data may still use "*".)
 */
export const PET_PUBLIC_COLUMNS =
  "id, shop_id, name, gender, species, breed, age_months, price, description, photo_urls, status, certification, listing_type, created_at";

export const PRODUCT_PUBLIC_COLUMNS =
  "id, shop_id, category, name, description, price, stock_quantity, photo_urls, status, requires_prescription, created_at";

export const SHOP_PUBLIC_COLUMNS = "id, name, description, banner_url, license_number, status, created_at";
