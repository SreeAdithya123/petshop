-- NOTE: three later migrations refined this file ('order_hold_helper', 'release_order_pets_newer_orders_only'):
-- place_pet_order, place_pet_gift, expire_stale_pet_orders and release_order_pets now use order_holds_reserved_pet()
-- and only treat NEWER live orders as holding a pet. The LIVE definitions are authoritative:
--   select pg_get_functiondef('public.place_pet_order(uuid[])'::regprocedure);

-- Order lifecycle, reservation expiry and account deletion.
-- Applied to project pytkeurgdbhekyppfblh as migration "order_lifecycle_and_account_deletion".
--
-- What this adds
--   * place_pet_order  : now creates ONE ORDER PER SHOP (a cart can span shops, but each
--                        shop must only ever manage its own pets) and caps a customer at 5
--                        orders that currently hold a reserved pet. Returns the first order id.
--   * place_pet_gift   : same hold cap; writes status history.
--   * seller_update_order_status(order, status) : shop owner (of an order that contains ONLY
--                        their items) or admin. pending->paid|cancelled, paid->fulfilled|cancelled.
--   * cancel_my_order(order) : the customer cancels their own PENDING order.
--   * expire_stale_pet_orders(hold) : cancels pending reservation/gift orders that have held a
--                        pet for longer than `hold` (default 48h); scheduled every 30 minutes.
--   * delete_my_account() : customers only. Hard-deletes accounts with no history; anonymises
--                        and disables sign-in for accounts with orders/bookings/refunds so the
--                        shops' records survive.
--   * release_order_pets(order) : internal helper (not callable through the API).

-- ---------------------------------------------------------------------------
-- Internal helper: hand an order's reserved pets back to the catalogue, unless
-- another live (pending/paid) order also holds that pet.
-- ---------------------------------------------------------------------------
create or replace function public.release_order_pets(p_order_id uuid)
returns void
language sql
security definer
set search_path to 'public'
as $function$
  update public.pets p
     set status = 'available'
   where p.status = 'reserved'
     and p.id in (select oi.item_id from public.order_items oi
                   where oi.order_id = p_order_id and oi.item_type = 'pet')
     and not exists (
       select 1
         from public.order_items oi2
         join public.orders o2 on o2.id = oi2.order_id
        where oi2.item_type = 'pet'
          and oi2.item_id = p.id
          and oi2.order_id <> p_order_id
          and o2.status in ('pending', 'paid'));

  update public.reservations
     set status = 'cancelled',
         cancellation_reason = coalesce(cancellation_reason, 'Order cancelled')
   where order_id = p_order_id
     and status in ('pending', 'confirmed');
$function$;

revoke all on function public.release_order_pets(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- place_pet_order: one order per shop + hold cap.
-- ---------------------------------------------------------------------------
create or replace function public.place_pet_order(p_pet_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_ids uuid[];
  v_first uuid;
  v_order uuid;
  v_shop record;
  v_count integer;
  v_held integer;
begin
  if v_uid is null then
    raise exception 'Please log in to place an order';
  end if;

  select coalesce(array_agg(distinct x), '{}') into v_ids from unnest(p_pet_ids) as x;
  if cardinality(v_ids) = 0 then
    raise exception 'Your cart is empty';
  end if;
  if cardinality(v_ids) > 10 then
    raise exception 'You can reserve at most 10 pets at a time';
  end if;

  -- Abuse guard: a customer can only hold a few pets at once.
  select count(*) into v_held
    from public.orders o
   where o.customer_id = v_uid
     and o.status = 'pending'
     and o.order_type in ('pet_reservation', 'gift')
     and exists (select 1
                   from public.order_items oi
                   join public.pets p on p.id = oi.item_id
                  where oi.order_id = o.id and oi.item_type = 'pet' and p.status = 'reserved');
  if v_held >= 5 then
    raise exception 'You already have 5 reservations waiting for the shop. Please wait for the shop to complete one, or cancel one first.';
  end if;

  perform 1 from public.pets where id = any(v_ids) for update;

  select count(*) into v_count
    from public.pets p
    join public.shops s on s.id = p.shop_id
   where p.id = any(v_ids) and p.status = 'available' and s.status = 'approved';

  if v_count <> cardinality(v_ids) then
    raise exception 'One or more pets in your cart are no longer available';
  end if;

  -- One order per shop, so each shop only ever manages its own pets.
  for v_shop in
    select p.shop_id, sum(p.price) as total
      from public.pets p
     where p.id = any(v_ids)
     group by p.shop_id
     order by p.shop_id
  loop
    insert into public.orders (customer_id, order_type, status, payment_type, total_amount)
    values (v_uid, 'pet_reservation', 'pending', 'full', v_shop.total)
    returning id into v_order;

    insert into public.order_items (order_id, item_type, item_id, quantity, price_at_purchase)
    select v_order, 'pet', p.id, 1, p.price
      from public.pets p
     where p.id = any(v_ids) and p.shop_id = v_shop.shop_id;

    insert into public.order_status_history (order_id, status, note, changed_by)
    values (v_order, 'pending', 'Reserved by customer', v_uid);

    if v_first is null then
      v_first := v_order;
    end if;
  end loop;

  update public.pets set status = 'reserved' where id = any(v_ids);

  return v_first;
end;
$function$;

-- ---------------------------------------------------------------------------
-- place_pet_gift: same hold cap, status history.
-- ---------------------------------------------------------------------------
create or replace function public.place_pet_gift(
  p_pet_id uuid,
  p_recipient_name text,
  p_recipient_contact text,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_price numeric;
  v_order uuid;
  v_held integer;
begin
  if v_uid is null then
    raise exception 'Please log in to send a gift';
  end if;
  if coalesce(btrim(p_recipient_name), '') = '' or coalesce(btrim(p_recipient_contact), '') = '' then
    raise exception 'Recipient name and contact are required';
  end if;

  select count(*) into v_held
    from public.orders o
   where o.customer_id = v_uid
     and o.status = 'pending'
     and o.order_type in ('pet_reservation', 'gift')
     and exists (select 1
                   from public.order_items oi
                   join public.pets p on p.id = oi.item_id
                  where oi.order_id = o.id and oi.item_type = 'pet' and p.status = 'reserved');
  if v_held >= 5 then
    raise exception 'You already have 5 reservations waiting for the shop. Please wait for the shop to complete one, or cancel one first.';
  end if;

  select p.price into v_price
    from public.pets p
    join public.shops s on s.id = p.shop_id
   where p.id = p_pet_id and p.status = 'available' and s.status = 'approved'
     for update of p;

  if v_price is null then
    raise exception 'This pet is no longer available';
  end if;

  insert into public.orders (customer_id, order_type, status, payment_type, total_amount)
  values (v_uid, 'gift', 'pending', 'full', v_price)
  returning id into v_order;

  insert into public.order_items (order_id, item_type, item_id, quantity, price_at_purchase)
  values (v_order, 'pet', p_pet_id, 1, v_price);

  insert into public.gifts (order_id, sender_id, recipient_name, recipient_contact, message, delivery_status)
  values (v_order, v_uid, btrim(p_recipient_name), btrim(p_recipient_contact),
          nullif(btrim(coalesce(p_message, '')), ''), 'pending');

  insert into public.order_status_history (order_id, status, note, changed_by)
  values (v_order, 'pending', 'Gift reserved by customer', v_uid);

  update public.pets set status = 'reserved' where id = p_pet_id;

  return v_order;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Shop owner / admin: move an order through its lifecycle.
-- ---------------------------------------------------------------------------
create or replace function public.seller_update_order_status(p_order_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_admin boolean := coalesce((select public.is_admin()), false);
  v_target public.order_status;
  v_current public.order_status;
begin
  if v_uid is null then
    raise exception 'Please log in';
  end if;

  begin
    v_target := p_status::public.order_status;
  exception when invalid_text_representation then
    raise exception 'Unknown order status: %', p_status;
  end;

  select status into v_current from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;

  if not v_admin then
    if not exists (select 1 from public.order_items oi where oi.order_id = p_order_id) then
      raise exception 'Order not found';
    end if;
    if exists (select 1
                 from public.order_items oi
                where oi.order_id = p_order_id
                  and not coalesce(public.shop_owns_item(oi.item_type, oi.item_id), false)) then
      raise exception 'You can only manage orders that contain only your shop''s items';
    end if;
  end if;

  if not ((v_current = 'pending' and v_target in ('paid', 'cancelled'))
       or (v_current = 'paid' and v_target in ('fulfilled', 'cancelled'))) then
    raise exception 'An order that is % cannot be changed to %', v_current, v_target;
  end if;

  -- Don't progress a sale whose pet was already put back on sale.
  if v_target in ('paid', 'fulfilled') and exists (
       select 1
         from public.order_items oi
         join public.pets p on p.id = oi.item_id
        where oi.order_id = p_order_id and oi.item_type = 'pet' and p.status = 'available') then
    raise exception 'This pet was put back on sale. Cancel this order instead.';
  end if;

  update public.orders set status = v_target where id = p_order_id;

  if v_target = 'paid' then
    update public.gifts set delivery_status = 'sent' where order_id = p_order_id;
  elsif v_target = 'fulfilled' then
    update public.pets set status = 'sold'
     where status = 'reserved'
       and id in (select item_id from public.order_items where order_id = p_order_id and item_type = 'pet');
    update public.gifts set delivery_status = 'delivered' where order_id = p_order_id;
  elsif v_target = 'cancelled' then
    perform public.release_order_pets(p_order_id);
  end if;

  insert into public.order_status_history (order_id, status, changed_by)
  values (p_order_id, v_target::text, v_uid);
end;
$function$;

revoke all on function public.seller_update_order_status(uuid, text) from public, anon;
grant execute on function public.seller_update_order_status(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Customer: cancel my own pending order.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_my_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_status public.order_status;
  v_customer uuid;
begin
  if v_uid is null then
    raise exception 'Please log in';
  end if;

  select status, customer_id into v_status, v_customer
    from public.orders where id = p_order_id for update;
  if not found or v_customer <> v_uid then
    raise exception 'Order not found';
  end if;
  if v_status <> 'pending' then
    raise exception 'Only orders that are still waiting for the shop can be cancelled';
  end if;

  update public.orders set status = 'cancelled' where id = p_order_id;
  perform public.release_order_pets(p_order_id);

  insert into public.order_status_history (order_id, status, note, changed_by)
  values (p_order_id, 'cancelled', 'Cancelled by customer', v_uid);
end;
$function$;

revoke all on function public.cancel_my_order(uuid) from public, anon;
grant execute on function public.cancel_my_order(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Reservation expiry: pending reservation/gift orders that still hold a reserved
-- pet (and have sold nothing) are cancelled after `p_hold`.
-- ---------------------------------------------------------------------------
create or replace function public.expire_stale_pet_orders(p_hold interval default interval '48 hours')
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_order record;
  v_count integer := 0;
begin
  for v_order in
    select o.id
      from public.orders o
     where o.status = 'pending'
       and o.order_type in ('pet_reservation', 'gift')
       and o.created_at < now() - p_hold
       and exists (select 1
                     from public.order_items oi
                     join public.pets p on p.id = oi.item_id
                    where oi.order_id = o.id and oi.item_type = 'pet' and p.status = 'reserved')
       and not exists (select 1
                         from public.order_items oi
                         join public.pets p on p.id = oi.item_id
                        where oi.order_id = o.id and oi.item_type = 'pet' and p.status = 'sold')
     for update of o skip locked
  loop
    update public.orders set status = 'cancelled' where id = v_order.id;
    perform public.release_order_pets(v_order.id);
    insert into public.order_status_history (order_id, status, note)
    values (v_order.id, 'cancelled', 'Reservation expired');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$function$;

revoke all on function public.expire_stale_pet_orders(interval) from public, anon, authenticated;

do $do$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'expire-stale-pet-orders';
  perform cron.schedule('expire-stale-pet-orders', '*/30 * * * *', 'select public.expire_stale_pet_orders()');
end
$do$;

-- ---------------------------------------------------------------------------
-- Account deletion (App Store guideline 5.1.1(v)). Customers only.
-- ---------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_role text;
  v_has_history boolean;
begin
  if v_uid is null then
    raise exception 'Please log in';
  end if;

  select role::text into v_role from public.profiles where id = v_uid;
  if v_role is null then
    raise exception 'Account not found';
  end if;
  if v_role <> 'customer' then
    raise exception 'Shop owner and admin accounts are closed by PETSTA support. Please contact support.';
  end if;

  -- Cancel open orders and give their pets back.
  perform public.release_order_pets(o.id) from public.orders o
   where o.customer_id = v_uid and o.status = 'pending';
  update public.orders set status = 'cancelled' where customer_id = v_uid and status = 'pending';

  delete from public.wishlists where customer_id = v_uid;
  delete from public.addresses where customer_id = v_uid;

  v_has_history :=
       exists (select 1 from public.orders where customer_id = v_uid)
    or exists (select 1 from public.service_bookings where customer_id = v_uid)
    or exists (select 1 from public.refunds where customer_id = v_uid)
    or exists (select 1 from public.reservations where customer_id = v_uid);

  if not v_has_history then
    delete from auth.users where id = v_uid;
  else
    -- Keep the shops' sales records, remove everything personal, block sign-in.
    update public.profiles
       set name = 'Deleted user', phone = null, email = null, avatar_url = null
     where id = v_uid;
    delete from auth.identities where user_id = v_uid;
    delete from auth.sessions where user_id = v_uid;
    update auth.users
       set email = 'deleted-' || v_uid::text || '@deleted.invalid',
           phone = null,
           raw_user_meta_data = '{}'::jsonb,
           banned_until = 'infinity'
     where id = v_uid;
  end if;
end;
$function$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
