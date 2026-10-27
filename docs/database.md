# PETSTA database contract

Snapshot of the Supabase project `pytkeurgdbhekyppfblh` ("petshop") as the web and Flutter apps rely on it. It was read through the Supabase MCP connector on 2026-10-02 / 2026-10-05 and may be slightly stale — re-check against the live project before changing anything.

Both apps talk to the database **only** through PostgREST with the user's JWT, so row-level security (RLS) and the guard triggers below are the real security boundary. The apps' UI checks are convenience, not protection.

## Enums

| Enum | Values |
| --- | --- |
| `user_role` | customer, shop_owner, admin |
| `shop_status` | pending, approved, suspended |
| `pet_status` | available, reserved, sold |
| `product_category` | medicine, store |
| `product_status` | available, unavailable |
| `order_status` | pending, paid, fulfilled, cancelled |
| `order_type` | product_purchase, pet_reservation, gift, service_booking, event_ticket, insurance_purchase, wallet_topup |
| `payment_type` | full, deposit |
| `reservation_status` | pending, confirmed, expired, cancelled |
| `catalog_item_type` | pet, product, event_ticket, insurance_policy, service |
| `service_category` | vet, grooming, training, walking, daycare, boarding, trimming, bathing |
| `service_status` | pending, approved, suspended |
| `service_booking_status` | pending, confirmed, completed, cancelled |
| `service_delivery_mode` | in_person, video, phone |
| `custom_request_status` | open, quoted, accepted, declined, cancelled, closed |
| `demo_mode` | video, in_person |
| `demo_status` | pending, approved, rejected, completed, cancelled |
| `gift_delivery_status` | pending, sent, delivered |
| `support_ticket_status` | open, in_progress, resolved, closed |

## Tables used by the apps

- `profiles(id, role, name, phone, email, avatar_url, created_at)`
- `shops(id, name, license_number, owner_id, description, banner_url, status, contract_version, contract_accepted_at, hours jsonb, video_call_enabled, created_at)` and private `shop_private(shop_id, address, phone, lat, lng, updated_at)`
- `pets(id, shop_id, name, gender, species, breed, age_months, price, description, photo_urls[], status, certification, listing_type, cost_price, created_at)`
- `products(id, shop_id, category, name, description, price, stock_quantity, photo_urls[], status, requires_prescription, cost_price, created_at)`
- `services(id, shop_id, category, name, description, price, duration_minutes, photo_urls[], status, created_at)`
- `service_bookings(id, service_id, shop_id, customer_id, pet_id, provider_id, booking_date, booking_time, delivery_mode, video_room_url, status, price_at_booking, order_id, notes, created_at, service_name, service_category, shop_name)`
- `custom_service_requests(id, customer_id, title, description, category, pet_name, pet_species, preferred_date, budget, status, shop_id, shop_name, quoted_price, response_message, responded_at, created_at, updated_at)`
- `demo_requests(id, customer_id, pet_id, shop_id, pet_name, pet_breed, pet_species, shop_name, preferred_date, preferred_time text, mode, message, status, meet_link, seller_note, confirmed_date, confirmed_time, created_at, updated_at)`
- `refunds(id, order_id, customer_id, shop_id, reason, notes, amount, status text, resolved_by, resolved_at, created_at, item_label)`
- `orders(id, customer_id, order_type, status, payment_type, total_amount, created_at, address_id, delivery_agent_id, eta_date, tracking_number, coupon_id, discount_amount)`; `order_items(id, order_id, item_type, item_id, quantity, price_at_purchase, created_at)`
- `reservations(id, pet_id, customer_id, status, deposit_amount, deposit_payment_id, cancellation_reason, final_sale_amount, created_at, expires_at, order_id)`
- `gifts(id, order_id, sender_id, recipient_name, recipient_contact, message, delivery_status, created_at)`
- `addresses(id, customer_id, label, line1, line2, city, state, zip, lat, lng, is_default, created_at)`
- `wishlists(customer_id, item_type, item_id, created_at)`
- `shop_reviews(id, shop_id, customer_id, rating, review_text, created_at, hidden, moderated_by, moderated_at)`
- `support_tickets(id, customer_id, shop_id, subject, status, created_at)`, `support_messages`
- `prescriptions(id, customer_id, pet_id, product_id, file_url, status, reviewed_by, reviewed_at, created_at)`

## Privacy rules enforced today (UI + query shape only)

- Customer-facing queries select explicit column lists (`lib/data/columns.dart`, `src/lib/columns.js`) and embed `shops(name)` only. **They never request `shops.address`, `shops.phone`, `pets.cost_price` or `products.cost_price`.**
- **Shop contact details are now enforced in the database:** `shops.address/phone/lat/lng` were moved to `shop_private` (readable and writable only by the owning shop and admins) and dropped from `shops` on 2026-10-27. `pets.cost_price` / `products.cost_price` are still readable through the API by anyone who can read the pet/product (see pending work).

## RLS and trigger behaviour the apps depend on

Helper functions (SECURITY DEFINER): `is_admin()`, `owns_shop(shop_id)`, `owns_order(order_id)`, `shop_owns_item(item_type, item_id)`, `owns_any_approved_shop()`, `owns_customer_pet(pet_id)`, `customer_ordered_from_shop(shop_id)`.

- **Catalog reads:** anon/customers see `pets` with `status='available'` and `products` with `status='available'` of **approved** shops, approved `shops`, and `services` with `status='approved'`. Owners see their own rows in any status; admins see everything.
- **services:** owners INSERT/UPDATE/DELETE their shop's rows; a BEFORE INSERT trigger forces `status='pending'` and an UPDATE guard stops owners changing `status` (admin approves/suspends).
- **service_bookings:** customer INSERT with `customer_id = auth.uid()`; trigger fills `shop_id`, `price_at_booking`, `service_name`, `service_category`, `shop_name`, forces `status='pending'`, nulls `video_room_url`/`order_id`/`provider_id`, and rejects non-approved services. Customer UPDATE: only `status -> 'cancelled'` (from pending/confirmed). Shop owner UPDATE: `status`, `video_room_url`, `provider_id` only (date/time/mode/pet/notes are locked). A blocked update returns **zero rows**, not an error.
- **custom_service_requests:** customer INSERT (trigger forces `status='open'`, nulls the quote columns). Customer UPDATE: `cancelled` (from open/quoted) or `accepted`/`declined` (from quoted). Owners of any approved shop can read all `open` requests and quote one (`status='quoted'`, `shop_id` = their shop, `quoted_price`, `response_message`); they can revise while `quoted` and set `closed` when `accepted`.
- **demo_requests:** customer INSERT (trigger fills shop/pet snapshot columns, forces `pending`, rejects pets that are not `available`). Customer UPDATE: only `cancelled` (from pending/approved). Owner UPDATE: `status` (pending→approved/rejected, approved→completed/rejected), `meet_link`, `seller_note`, `confirmed_date`, `confirmed_time`; cannot set `cancelled` or change the customer's requested slot.
- **refunds:** customer INSERT (trigger requires the order to be theirs, the shop to have items on it, caps `amount` to that shop's total, forces `pending`). Owner UPDATE: only `pending → approved|rejected`.
- **profiles:** a user reads/updates their own row; shop owners can read the profiles of customers who ordered from, reserved from, or sent tickets/bookings/demo requests to their shop; a trigger blocks self role-escalation.
- **orders / order_items:** customers read their own; owners read orders that contain their items (via `shop_owns_item`). There is **no** client UPDATE path for order status today (see below).

## RPCs

| Function | Notes |
| --- | --- |
| `place_pet_order(p_pet_ids uuid[]) → uuid` | Atomic, server-priced; reserves each pet and creates a `pet_reservation` order. |
| `place_pet_gift(p_pet_id, p_recipient_name, p_recipient_contact, p_message) → uuid` | Creates a `gift` order + `gifts` row; the pet becomes reserved. |
| `order_items_detailed(p_order_id) → table(order_item_id, item_type, item_id, quantity, price_at_purchase, label, shop_id, shop_name)` | For an order the caller owns. |

## Database changes applied on 2026-10-26/27

Migrations (see `docs/sql/` for the statements): `shop_private_contact_table`, `drop_shop_contact_columns`, `order_lifecycle_and_account_deletion`, `order_hold_helper`, `release_order_pets_newer_orders_only`.

- **Shop contact privacy:** `shop_private` table with RLS (owner of the shop + admin only); public columns dropped.
- **`place_pet_order(uuid[])`:** now creates **one order per shop** (returns the first order's id; the others appear in My orders), caps a customer at 5 orders that currently hold a reserved pet, writes `order_status_history`.
- **`place_pet_gift(...)`:** same hold cap and history.
- **`seller_update_order_status(order, status)`:** shop owner of an order whose items are *all* theirs, or admin. `pending→paid|cancelled`, `paid→fulfilled|cancelled`. `fulfilled` marks reserved pets sold (and gifts delivered); `cancelled` returns pets to `available`; refuses to progress an order whose pet was already put back on sale.
- **`cancel_my_order(order)`:** the customer's own order while `pending`.
- **`expire_stale_pet_orders(interval)`** (internal, cron every 30 min as `expire-stale-pet-orders`): cancels `pending` reservation/gift orders older than 48 h that still genuinely hold a reserved pet and have sold nothing. It ignores old stale orders whose pet was re-reserved by someone else.
- **`delete_my_account()`:** customers only. No history → the auth user (and everything cascading from it) is deleted. With orders / bookings / refunds / reservations → the profile is anonymised, sign-in is disabled and the shops' records are kept.
- Internal helpers `release_order_pets`, `order_holds_reserved_pet` are not callable through the API.
- All of the above was tested as real users (customer, both shop owners, admin, anon) inside rolled-back transactions.

## Still to do (database)

1. **`cost_price` leak:** `pets.cost_price` and `products.cost_price` can be read through the API by anyone who can read the pet/product. Move them to owner-only tables (`pet_costs`, `product_costs`) the same way as `shop_private`, then update the seller screens (web + Flutter).
2. **Product stock:** product orders are inserted directly by the client and never change `stock_quantity`; decide whether stock should drop when an order is marked paid/fulfilled.
3. **Notifications:** the `notifications` table exists; writing a row on every order/booking/demo status change would give both apps an in-app feed and is the basis for push notifications.
4. **Auth settings (dashboard, not SQL):** enable leaked-password protection; add `io.supabase.petsta://reset-callback/` and `io.supabase.petsta://login-callback/` to the allowed redirect URLs and set the Site URL; configure custom SMTP (the built-in mailer is heavily rate-limited); enable backups (a paid plan).
5. **Indexes:** re-run the Supabase performance advisor and add covering indexes for any unindexed foreign keys.
