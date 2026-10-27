import { supabase } from "../../lib/supabaseClient";

// Data layer for the seller Orders and Dashboard pages. An order belongs to a
// shop through its lines: only order_items whose item_id is one of this shop's
// pets, products or services are read, so an order only ever shows (and totals)
// THIS shop's lines.

const ID_CHUNK_SIZE = 100;
const ROW_PAGE_SIZE = 1000;
const MAX_ROW_PAGES = 100;

/** Rows revealed per "Load more" click. */
export const ORDERS_PAGE_SIZE = 20;

const ORDER_TYPE_LABELS = {
  product_purchase: "Product purchase",
  pet_reservation: "Pet reservation",
  gift: "Gift",
};

export function orderTypeLabel(type) {
  if (ORDER_TYPE_LABELS[type]) return ORDER_TYPE_LABELS[type];
  const text = String(type ?? "").replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

export const PET_STATUS_LABELS = {
  available: "Pet available",
  reserved: "Pet reserved",
  sold: "Pet sold",
};

function chunk(list, size) {
  const chunks = [];
  for (let start = 0; start < list.length; start += size) chunks.push(list.slice(start, start + size));
  return chunks;
}

/**
 * Pages through a query past PostgREST's row cap (1000) so lists and totals
 * are never silently truncated. Ordered by id so pages never overlap. Throws
 * the Supabase error.
 */
async function fetchAllRows(buildQuery) {
  const rows = [];
  for (let page = 0; page < MAX_ROW_PAGES; page += 1) {
    const from = page * ROW_PAGE_SIZE;
    const { data, error } = await buildQuery()
      .order("id", { ascending: true })
      .range(from, from + ROW_PAGE_SIZE - 1);
    if (error) throw error;
    const batch = data ?? [];
    rows.push(...batch);
    if (batch.length < ROW_PAGE_SIZE) break;
  }
  return rows;
}

async function fetchAllInChunks(ids, buildQuery) {
  const batches = await Promise.all(chunk(ids, ID_CHUNK_SIZE).map((part) => fetchAllRows(() => buildQuery(part))));
  return batches.flat();
}

function petLabel(pet) {
  const breed = (pet.breed ?? "").trim();
  const species = (pet.species ?? "").trim();
  const name = (pet.name ?? "").trim();
  const detail = breed ? (species ? `${breed} (${species})` : breed) : species;
  if (!name) return detail || "Pet";
  return detail ? `${name} · ${detail}` : name;
}

async function readShopOrders(shopId) {
  const [pets, products, services] = await Promise.all([
    fetchAllRows(() => supabase.from("pets").select("id, name, breed, species, status").eq("shop_id", shopId)),
    fetchAllRows(() => supabase.from("products").select("id, name").eq("shop_id", shopId)),
    fetchAllRows(() => supabase.from("services").select("id, name").eq("shop_id", shopId)),
  ]);

  // item id -> label / type / pet status; ids are uuids so they never collide.
  const labels = {};
  const types = {};
  const petStatuses = {};
  let soldCount = 0;
  pets.forEach((pet) => {
    labels[pet.id] = petLabel(pet);
    types[pet.id] = "pet";
    petStatuses[pet.id] = pet.status ?? "";
    if (pet.status === "sold") soldCount += 1;
  });
  products.forEach((product) => {
    labels[product.id] = product.name || "Product";
    types[product.id] = "product";
  });
  services.forEach((service) => {
    labels[service.id] = service.name || "Service";
    types[service.id] = "service";
  });

  const counts = { petCount: pets.length, productCount: products.length, soldCount };
  const empty = { ...counts, orders: [], customersError: null };

  const itemIds = Object.keys(labels);
  if (itemIds.length === 0) return empty;

  const itemRows = await fetchAllInChunks(itemIds, (ids) =>
    supabase
      .from("order_items")
      .select("id, order_id, item_id, item_type, quantity, price_at_purchase")
      .in("item_id", ids),
  );

  const linesByOrder = {};
  itemRows.forEach((row) => {
    if (!row.order_id || !row.item_id) return;
    const quantity = Math.max(1, Number(row.quantity) || 1);
    const price = Number(row.price_at_purchase) || 0;
    if (!linesByOrder[row.order_id]) linesByOrder[row.order_id] = [];
    linesByOrder[row.order_id].push({
      key: row.id ?? `${row.order_id}:${row.item_id}`,
      itemId: row.item_id,
      itemType: types[row.item_id] ?? row.item_type ?? "",
      name: labels[row.item_id] ?? "Item",
      quantity,
      price,
      total: price * quantity,
      petStatus: petStatuses[row.item_id] || null,
    });
  });

  const orderIds = Object.keys(linesByOrder);
  if (orderIds.length === 0) return empty;

  const orderRows = await fetchAllInChunks(orderIds, (ids) =>
    supabase
      .from("orders")
      .select("id, customer_id, order_type, status, payment_type, total_amount, created_at")
      .in("id", ids),
  );

  // Names are a nicety: if the lookup fails the orders are still listed.
  const names = {};
  let customersError = null;
  const customerIds = [...new Set(orderRows.map((row) => row.customer_id).filter(Boolean))];
  try {
    for (const ids of chunk(customerIds, ID_CHUNK_SIZE)) {
      const { data, error } = await supabase.from("profiles").select("id, name").in("id", ids);
      if (error) throw error;
      (data ?? []).forEach((profile) => {
        const name = (profile.name ?? "").trim();
        if (name) names[profile.id] = name;
      });
    }
  } catch (thrown) {
    customersError = thrown?.message || "Something went wrong.";
  }

  const orders = orderRows
    .map((row) => {
      const lines = linesByOrder[row.id] ?? [];
      return {
        ...row,
        total_amount: Number(row.total_amount) || 0,
        customerName: names[row.customer_id] ?? "Customer",
        lines,
        // What THIS shop earns from the order: the sum of its own lines.
        shopSubtotal: lines.reduce((sum, line) => sum + line.total, 0),
      };
    })
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

  return { ...counts, orders, customersError };
}

/**
 * Loads the shop's listing counts, the orders that include its items (newest
 * first, each with only this shop's lines and subtotal) and, best effort, the
 * customers' names. Resolves to { data, error } for useLoader and never throws;
 * data is { orders, petCount, productCount, soldCount, customersError }.
 */
export async function loadShopOrders(shopId) {
  try {
    return { data: await readShopOrders(shopId), error: null };
  } catch (thrown) {
    return { data: null, error: { message: thrown?.message || "Something went wrong." } };
  }
}
