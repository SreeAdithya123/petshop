-- UNAPPLIED / UNTESTED -- DESTRUCTIVE. Do NOT run until:
--   1. docs/sql/01_shop_private.sql has been applied and verified,
--   2. every client (web, Android, iOS) reads and writes shop contact details
--      through public.shop_private (Flutter: lib/repositories/shop_contact_repository.dart,
--      web: src/pages/seller/StoreProfile.jsx, src/pages/admin/*),
--   3. you have a backup / have confirmed shop_private holds every shop's data:
--        select s.id from public.shops s
--        left join public.shop_private p on p.shop_id = s.id
--        where p.shop_id is null or p.address is null;     -- expect 0 rows
--
-- Removing the columns makes it impossible for any API caller to read a shop's
-- address or phone from the public table.

begin;

alter table public.shops drop column if exists address;
alter table public.shops drop column if exists phone;
alter table public.shops drop column if exists lat;
alter table public.shops drop column if exists lng;

commit;
