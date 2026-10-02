import { useCallback, useState } from "react";
import { BookingsTab } from "../../components/seller/BookingsTab";
import { RequestsTab } from "../../components/seller/RequestsTab";
import { SellerPage } from "../../components/seller/SellerPage";
import { ServicesTab } from "../../components/seller/ServicesTab";
import { TabPanel, Tabs } from "../../components/seller/Tabs";
import { useLoader } from "../../components/seller/useLoader";
import { attachCustomers } from "../../components/seller/profiles";
import { useMyShop } from "../../hooks/useMyShop";
import { supabase } from "../../lib/supabaseClient";

// Custom requests are read without customer_id: shop owners never see who asked.
const REQUEST_COLUMNS =
  "id, title, description, category, pet_name, pet_species, preferred_date, budget, status, shop_id, quoted_price, response_message, responded_at, created_at";

function ServicesWorkspace({ shop }) {
  const readOnly = shop.status !== "approved";
  const [tab, setTab] = useState("services");

  const loadServices = useCallback(
    () => supabase.from("services").select("*").eq("shop_id", shop.id).order("created_at", { ascending: false }),
    [shop.id],
  );
  const loadBookings = useCallback(
    async () =>
      attachCustomers(
        await supabase
          .from("service_bookings")
          .select("*")
          .eq("shop_id", shop.id)
          .order("created_at", { ascending: false }),
      ),
    [shop.id],
  );
  // Every open request is visible to approved shop owners; the rest are the ones this shop quoted.
  const loadRequests = useCallback(
    () =>
      supabase
        .from("custom_service_requests")
        .select(REQUEST_COLUMNS)
        .or(`status.eq.open,shop_id.eq.${shop.id}`)
        .order("created_at", { ascending: false }),
    [shop.id],
  );

  const services = useLoader(loadServices);
  const bookings = useLoader(loadBookings);
  const requests = useLoader(loadRequests);

  const pendingBookings = bookings.data ? bookings.data.rows.filter((row) => row.status === "pending").length : null;
  const openRequests = requests.data ? requests.data.filter((row) => row.status === "open").length : null;

  const tabs = [
    {
      value: "services",
      label: "My services",
      count: services.data ? services.data.length : null,
      countLabel: "services",
    },
    { value: "bookings", label: "Bookings", count: pendingBookings, countLabel: "pending", attention: true },
    { value: "requests", label: "Custom requests", count: openRequests, countLabel: "open", attention: true },
  ];

  return (
    <>
      <Tabs tabs={tabs} value={tab} onChange={setTab} label="Services sections" idPrefix="services" />
      <TabPanel value={tab} idPrefix="services">
        {tab === "services" && <ServicesTab shopId={shop.id} readOnly={readOnly} query={services} />}
        {tab === "bookings" && <BookingsTab readOnly={readOnly} query={bookings} />}
        {tab === "requests" && <RequestsTab shopId={shop.id} readOnly={readOnly} query={requests} />}
      </TabPanel>
    </>
  );
}

export function SellerServices() {
  const { shop, loading, error } = useMyShop();

  return (
    <SellerPage
      title="Services"
      description="Manage the services your shop offers, the bookings customers make and their custom requests."
      unlocks="add services and answer bookings and custom requests"
      shop={shop}
      loading={loading}
      error={error}
    >
      <ServicesWorkspace shop={shop} />
    </SellerPage>
  );
}
