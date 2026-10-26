-- UNAPPLIED / UNTESTED -- review, then run in the Supabase SQL editor (or apply as a migration).
--
-- Step 1 of 2: move shop contact details into a private table that only the
-- owning shop and admins can read. This step is ADDITIVE and safe to run while
-- the current apps are live: it copies the data and loosens two NOT NULLs, but
-- keeps the old columns, so nothing that reads shops.address/phone breaks.
--
-- Step 2 (docs/sql/02_drop_shop_contact_columns.sql) removes the old columns
-- and must only run after the apps read/write shop_private instead.

begin;

create table if not exists public.shop_private (
  shop_id    uuid primary key references public.shops (id) on delete cascade,
  address    text,
  phone      text,
  lat        double precision,
  lng        double precision,
  updated_at timestamptz not null default now()
);

alter table public.shop_private enable row level security;

-- Owners manage their own shop's contact details; admins can see/edit all.
drop policy if exists shop_private_select on public.shop_private;
create policy shop_private_select on public.shop_private
  for select using (public.owns_shop(shop_id) or (select public.is_admin()));

drop policy if exists shop_private_insert on public.shop_private;
create policy shop_private_insert on public.shop_private
  for insert with check (public.owns_shop(shop_id) or (select public.is_admin()));

drop policy if exists shop_private_update on public.shop_private;
create policy shop_private_update on public.shop_private
  for update using (public.owns_shop(shop_id) or (select public.is_admin()))
  with check (public.owns_shop(shop_id) or (select public.is_admin()));

drop policy if exists shop_private_delete on public.shop_private;
create policy shop_private_delete on public.shop_private
  for delete using ((select public.is_admin()));

-- Keep updated_at honest.
create or replace function public.shop_private_touch()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Trigger-only function: nobody should be able to call it over the REST API.
revoke all on function public.shop_private_touch() from public, anon, authenticated;

drop trigger if exists shop_private_touch on public.shop_private;
create trigger shop_private_touch before update on public.shop_private
  for each row execute function public.shop_private_touch();

-- Copy what exists today.
insert into public.shop_private (shop_id, address, phone, lat, lng)
select id, address, phone, lat, lng
from public.shops
on conflict (shop_id) do nothing;

-- New shops will be created without contact details on the public row.
alter table public.shops alter column address drop not null;
alter table public.shops alter column phone drop not null;

commit;

-- Verify (expect one row per shop, and 0 for the anon role):
--   select count(*) from public.shop_private;
--   select count(*) from public.shops;
--   set local role anon; select count(*) from public.shop_private;  -- should be 0
