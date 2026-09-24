import { useEffect, useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { useMyShop } from "../../hooks/useMyShop";
import { supabase } from "../../lib/supabaseClient";

const orderTypeLabels = {
  product_purchase: "Product purchase",
  pet_reservation: "Pet reservation",
  gift: "Gift",
};

const statusStyles = {
  paid: "bg-trust/10 text-trust",
  fulfilled: "bg-trust/10 text-trust",
  pending: "bg-primary/10 text-primary",
  cancelled: "bg-error/10 text-error",
};

function StatusPill({ status }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ${
        statusStyles[status] || "bg-ink/5 text-ink-soft"
      }`}
    >
      {status}
    </span>
  );
}

function formatCurrency(amount) {
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(amount ?? 0);
}

export function SellerOrders() {
  const { shop, loading: shopLoading } = useMyShop();
  const [orders, setOrders] = useState([]);
  const [itemsByOrder, setItemsByOrder] = useState({});
  const [itemNames, setItemNames] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (shopLoading) return;
    if (!shop) {
      setLoading(false);
      return;
    }

    let cancelled = false;

    async function loadOrders() {
      setLoading(true);
      setError(null);

      const [{ data: pets, error: petsError }, { data: products, error: productsError }] = await Promise.all([
        supabase.from("pets").select("id, breed, species").eq("shop_id", shop.id),
        supabase.from("products").select("id, name").eq("shop_id", shop.id),
      ]);

      if (petsError || productsError) {
        if (!cancelled) {
          setError((petsError || productsError).message);
          setLoading(false);
        }
        return;
      }

      const petIds = (pets || []).map((pet) => pet.id);
      const productIds = (products || []).map((product) => product.id);
      const names = {};
      (pets || []).forEach((pet) => {
        names[pet.id] = pet.breed ? `${pet.breed} (${pet.species})` : pet.species;
      });
      (products || []).forEach((product) => {
        names[product.id] = product.name;
      });

      if (petIds.length === 0 && productIds.length === 0) {
        if (!cancelled) {
          setOrders([]);
          setItemsByOrder({});
          setItemNames(names);
          setLoading(false);
        }
        return;
      }

      const filters = [];
      if (petIds.length > 0) filters.push(`and(item_type.eq.pet,item_id.in.(${petIds.join(",")}))`);
      if (productIds.length > 0) filters.push(`and(item_type.eq.product,item_id.in.(${productIds.join(",")}))`);

      const { data: orderItems, error: orderItemsError } = await supabase
        .from("order_items")
        .select("*")
        .or(filters.join(","));

      if (orderItemsError) {
        if (!cancelled) {
          setError(orderItemsError.message);
          setLoading(false);
        }
        return;
      }

      const orderIds = [...new Set((orderItems || []).map((item) => item.order_id))];
      const grouped = {};
      (orderItems || []).forEach((item) => {
        if (!grouped[item.order_id]) grouped[item.order_id] = [];
        grouped[item.order_id].push(item);
      });

      if (orderIds.length === 0) {
        if (!cancelled) {
          setOrders([]);
          setItemsByOrder({});
          setItemNames(names);
          setLoading(false);
        }
        return;
      }

      const { data: fetchedOrders, error: ordersError } = await supabase
        .from("orders")
        .select("*, profiles(name,email)")
        .in("id", orderIds)
        .order("created_at", { ascending: false });

      if (!cancelled) {
        if (ordersError) setError(ordersError.message);
        else setOrders(fetchedOrders || []);
        setItemsByOrder(grouped);
        setItemNames(names);
        setLoading(false);
      }
    }

    loadOrders();
    return () => {
      cancelled = true;
    };
  }, [shop, shopLoading]);

  if (shopLoading || loading) {
    return (
      <Container className="py-12">
        <p className="text-[15px] text-ink-soft">Loading orders…</p>
      </Container>
    );
  }

  if (!shop) {
    return (
      <Container className="py-12">
        <EmptyState
          title="You haven't set up your shop yet"
          description="Create your shop profile first."
          action={
            <Button to="/seller/store" size="sm">
              Set up your shop
            </Button>
          }
        />
      </Container>
    );
  }

  if (error) {
    return (
      <Container className="py-12">
        <p className="text-[15px] text-error">Couldn't load orders: {error}</p>
      </Container>
    );
  }

  if (orders.length === 0) {
    return (
      <Container className="py-12">
        <EmptyState title="No orders yet" description="Orders for your pets and products will show up here." />
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-bold text-ink">Orders</h1>
      <p className="mt-2 text-[15px] text-ink-soft">Orders that include items from your shop.</p>

      <div className="mt-8 flex flex-col gap-4">
        {orders.map((order) => {
          const items = itemsByOrder[order.id] || [];
          return (
            <div key={order.id} className="rounded-xl border border-border bg-surface p-6">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="font-display text-lg font-semibold text-ink">
                    {orderTypeLabels[order.order_type] || order.order_type}
                  </p>
                  <p className="mt-1 text-sm text-ink-soft">
                    {order.profiles?.name || "Customer"} &middot;{" "}
                    {new Date(order.created_at).toLocaleDateString()}
                  </p>
                </div>
                <div className="flex flex-col items-end gap-2">
                  <StatusPill status={order.status} />
                  <p className="font-display text-lg font-semibold text-accent">
                    {formatCurrency(order.total_amount)}
                  </p>
                </div>
              </div>

              {items.length > 0 && (
                <ul className="mt-4 flex flex-col gap-1.5 border-t border-border pt-4">
                  {items.map((item) => (
                    <li key={item.id} className="flex justify-between text-sm text-ink">
                      <span>
                        {itemNames[item.item_id] || "Item"}{" "}
                        {item.quantity > 1 && <span className="text-ink-soft">&times; {item.quantity}</span>}
                      </span>
                      <span className="text-ink-soft">{formatCurrency(item.price_at_purchase)}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          );
        })}
      </div>
    </Container>
  );
}
