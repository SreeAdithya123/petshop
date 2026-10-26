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
- `shops(id, name, address, phone, license_number, owner_id, description, banner_url, status, contract_version, contract_accepted_at, lat, lng, hours jsonb, video_call_enabled, created_at)`
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
- **Gap:** RLS cannot hide columns, so anyone who calls the REST API directly can still read `shops.address/phone/lat/lng` of approved shops and `cost_price` of available pets/products. See "Pending database work".

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

## Pending database work (not applied — needs Supabase access)

The Flutter app already calls the functions below and degrades gracefully ("This action isn't available yet") until they exist. **Read `place_pet_order` and `place_pet_gift` first** (`select pg_get_functiondef('public.place_pet_order(uuid[])'::regprocedure);`) — the lifecycle functions must mirror what they write (orders, order_items, reservations, pets).

1. **Order lifecycle (biggest functional gap).**
   - `seller_update_order_status(p_order_id uuid, p_status text) → void` — SECURITY DEFINER; caller must own a shop with an item on the order (or be admin). Allowed: `pending→paid`, `paid→fulfilled`, `pending|paid→cancelled`. `fulfilled` marks the order's reserved pets `sold` (and confirms their reservation); `cancelled` returns reserved pets to `available` (and cancels the reservation, restoring product stock if stock was decremented). Decide how multi-shop orders behave (a cart can span shops): either split orders per shop in `place_pet_order`, or apply the status per shop's items and derive the order status.
   - `cancel_my_order(p_order_id uuid) → void` — the customer's own order while `pending`; same release behaviour.
   - **Reservation expiry:** a scheduled job (pg_cron) that cancels `pending` reservations/orders older than N hours so abandoned carts cannot lock pets forever, plus a cap on simultaneous pending orders per customer.
2. **Account deletion (App Store guideline 5.1.1(v) requires it):** `delete_my_account() → void`. Remove or anonymise personal data (wishlists, addresses, tickets, profile name/phone/email) and delete the auth user; orders must survive for the shop's records, so if foreign keys block deleting the auth user, anonymise the profile and ban the auth user instead. Shop owners should be told to contact support.
3. **Shop contact privacy (user-approved, not yet applied):** run `docs/sql/01_shop_private.sql` (additive), then switch `ShopContactRepository` (Flutter) and the web seller/admin shop screens to read/write `shop_private`, then run `docs/sql/02_drop_shop_contact_columns.sql`. Consider the same treatment for `cost_price` (a `pet_costs` / `product_costs` table readable only by the owning shop).
4. **Indexes:** re-run the Supabase performance advisor after the above and add covering indexes for any unindexed foreign keys.
5. **Auth settings (dashboard, not SQL):** enable leaked-password protection; add `io.supabase.petsta://reset-callback/` and `io.supabase.petsta://login-callback/` to the allowed redirect URLs and set the Site URL; configure custom SMTP (the built-in mailer is heavily rate-limited); enable backups (a paid plan).
