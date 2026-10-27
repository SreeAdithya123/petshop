-- APPLIED on 2026-10-27 as migration "listing_photos_storage_and_drop_cost_price". Source of truth.
--
-- Public bucket for pet / product / service / shop photos. Anyone can VIEW a photo by its URL;
-- only the owning shop (or an admin) can upload, replace or delete files in its own folder.
-- Files live at  <shop_id>/<kind>/<random>.<ext>  with kind in pets | products | services | shop.
-- (Direct SQL deletes on storage.objects are blocked by Supabase; remove files through the Storage API.)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-photos', 'listing-photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.can_manage_listing_photo(p_name text)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'storage'
as $function$
  select case
    when (storage.foldername(p_name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then (public.owns_shop(((storage.foldername(p_name))[1])::uuid)
            or coalesce((select public.is_admin()), false))
    else false
  end;
$function$;

revoke all on function public.can_manage_listing_photo(text) from public, anon;
grant execute on function public.can_manage_listing_photo(text) to authenticated;

create policy "listing photos: owners read" on storage.objects
  for select to authenticated
  using (bucket_id = 'listing-photos' and public.can_manage_listing_photo(name));

create policy "listing photos: owners upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'listing-photos' and public.can_manage_listing_photo(name));

create policy "listing photos: owners replace" on storage.objects
  for update to authenticated
  using (bucket_id = 'listing-photos' and public.can_manage_listing_photo(name))
  with check (bucket_id = 'listing-photos' and public.can_manage_listing_photo(name));

create policy "listing photos: owners delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'listing-photos' and public.can_manage_listing_photo(name));

-- cost_price was never read or written by either app and held no data; removed so the sellers'
-- margins can never be exposed through the public API.
alter table public.pets drop column if exists cost_price;
alter table public.products drop column if exists cost_price;
