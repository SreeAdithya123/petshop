/// Column lists for customer-facing queries (mirrors src/lib/columns.js).
///
/// `pets.cost_price` / `products.cost_price` are seller-only margins and
/// `shops.address` / `shops.phone` are contact details customers never see.
/// Row-level security can't hide individual columns, so every customer-facing
/// query must select an explicit list instead of `*` / `shops(*)`.
/// (Seller/admin screens scoped to their own data may still use `*`.)
const petPublicColumns =
    'id, shop_id, name, gender, species, breed, age_months, price, description, photo_urls, status, certification, listing_type, created_at';

const productPublicColumns =
    'id, shop_id, category, name, description, price, stock_quantity, photo_urls, status, requires_prescription, created_at';

const shopPublicColumns = 'id, name, description, banner_url, license_number, status, created_at';

const servicePublicColumns =
    'id, shop_id, category, name, description, price, duration_minutes, photo_urls, status, created_at';
