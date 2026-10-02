import { MagnifyingGlass, PawPrint, Plus, Stethoscope } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { Container } from "../components/layout/Container";
import { BookingModal } from "../components/services/BookingModal";
import { CustomServiceModal } from "../components/services/CustomServiceModal";
import { MyServicesSection } from "../components/services/MyServicesSection";
import { ServiceCard } from "../components/services/ServiceCard";
import { SERVICE_CATEGORIES, categoryMeta } from "../components/services/serviceCategories";
import { useApprovedServices } from "../components/services/useApprovedServices";
import { useBookingAccess } from "../components/services/useBookingAccess";
import { useCustomRequests } from "../components/services/useCustomRequests";
import { useHashScroll } from "../components/services/useHashScroll";
import { useServiceBookings } from "../components/services/useServiceBookings";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { fieldClassName } from "../lib/styles";

const CATEGORY_CHIPS = [{ value: "all", label: "All", icon: PawPrint }, ...SERVICE_CATEGORIES];

const GRID_CLASS = "grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4";

function groupByCategory(services) {
  const byCategory = new Map();
  for (const service of services) {
    if (!byCategory.has(service.category)) byCategory.set(service.category, []);
    byCategory.get(service.category).push(service);
  }

  // Known categories in their display order, then anything unexpected.
  const knownValues = new Set(SERVICE_CATEGORIES.map((category) => category.value));
  const ordered = [
    ...SERVICE_CATEGORIES.map((category) => category.value),
    ...[...byCategory.keys()].filter((value) => !knownValues.has(value)),
  ];
  return ordered
    .filter((value) => byCategory.has(value))
    .map((value) => ({ category: categoryMeta(value), items: byCategory.get(value) }));
}

function CategoryHeading({ category, count }) {
  const Icon = category.icon;
  return (
    <h2 className="flex items-center gap-2 font-display text-xl font-semibold text-ink">
      <Icon size={22} className="text-primary" aria-hidden="true" />
      {category.label}
      <span className="text-sm font-normal text-ink-soft">({count})</span>
    </h2>
  );
}

export function Services() {
  const location = useLocation();
  const access = useBookingAccess();
  const { services, loading, error, reload } = useApprovedServices();
  const customerId = access.canBook ? access.userId : null;
  const bookings = useServiceBookings({ userId: customerId });
  const requests = useCustomRequests({ userId: customerId });

  const [category, setCategory] = useState("all");
  const [query, setQuery] = useState("");
  const [bookingService, setBookingService] = useState(null);
  // /services#custom (linked from the Health page) opens the request form straight away.
  const [customOpen, setCustomOpen] = useState(() => location.hash === "#custom");
  const [tab, setTab] = useState("bookings");

  useHashScroll(!loading && access.status !== "loading");

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return services.filter((service) => {
      if (category !== "all" && service.category !== category) return false;
      if (!needle) return true;
      return `${service.name} ${service.description ?? ""} ${service.shops?.name ?? ""}`
        .toLowerCase()
        .includes(needle);
    });
  }, [services, category, query]);

  const groups = useMemo(() => groupByCategory(filtered), [filtered]);

  function showMine(nextTab) {
    setBookingService(null);
    setCustomOpen(false);
    setTab(nextTab);
    // Wait a tick so the modal's scroll lock is released first.
    setTimeout(() => document.getElementById("my-bookings")?.scrollIntoView({ behavior: "smooth", block: "start" }), 0);
  }

  function clearFilters() {
    setCategory("all");
    setQuery("");
  }

  return (
    <Container className="py-10 lg:py-12">
      <div className="rounded-2xl bg-gradient-to-br from-primary/10 via-secondary/10 to-tertiary/10 p-6 md:p-8">
        <div className="flex flex-wrap items-end justify-between gap-5">
          <div>
            <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Pet services</h1>
            <p className="mt-2 max-w-xl text-[15px] text-ink-soft">
              Vets, grooming, training and more from approved local shops. Pick a slot and the shop confirms it.
            </p>
            <Link
              to="/health#vet"
              className="mt-3 inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:underline"
            >
              <Stethoscope size={16} aria-hidden="true" /> Need a vet? Book a video consult
            </Link>
          </div>
          <Button variant="accent" size="lg" onClick={() => setCustomOpen(true)}>
            <Plus size={18} weight="bold" aria-hidden="true" /> Custom service
          </Button>
        </div>
      </div>

      <div className="mt-6 flex flex-col gap-4">
        <div className="relative w-full sm:max-w-sm">
          <label htmlFor="service-search" className="sr-only">
            Search services
          </label>
          <MagnifyingGlass
            size={18}
            aria-hidden="true"
            className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-soft"
          />
          <input
            id="service-search"
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search services"
            className={`${fieldClassName(false)} !mt-0 !pl-10`}
          />
        </div>

        <div
          role="group"
          aria-label="Filter by category"
          className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 scrollbar-none sm:mx-0 sm:flex-wrap sm:overflow-visible sm:px-0"
        >
          {CATEGORY_CHIPS.map(({ value, label, icon: ChipIcon }) => {
            const active = category === value;
            return (
              <button
                key={value}
                type="button"
                aria-pressed={active}
                onClick={() => setCategory(value)}
                className={`inline-flex flex-none items-center gap-2 whitespace-nowrap rounded-full border px-4 py-2 text-sm font-medium transition-colors ${
                  active
                    ? "border-primary bg-primary text-white"
                    : "border-border bg-surface text-ink hover:bg-primary/5"
                }`}
              >
                <ChipIcon size={16} weight={active ? "fill" : "regular"} aria-hidden="true" />
                {label}
              </button>
            );
          })}
        </div>
      </div>

      {loading ? (
        <div role="status" aria-label="Loading services" className={`mt-8 ${GRID_CLASS}`}>
          {Array.from({ length: 6 }, (_, index) => (
            <div key={index} className="h-72 animate-pulse rounded-xl bg-ink/5" />
          ))}
        </div>
      ) : error ? (
        <div role="alert" className="mt-8 rounded-xl border border-error/30 bg-error/5 p-5 text-sm text-error">
          <p>Couldn't load services: {error}</p>
          <Button variant="outline" size="sm" className="mt-3" onClick={reload}>
            Try again
          </Button>
        </div>
      ) : services.length === 0 ? (
        <EmptyState
          title="No services listed yet"
          description="Shops are still getting set up. Need something specific? Send a custom request below and shops will quote."
        />
      ) : filtered.length === 0 ? (
        <EmptyState
          title="No services match"
          description="Try a different category or search term."
          action={
            <Button variant="outline" size="sm" onClick={clearFilters}>
              Clear filters
            </Button>
          }
        />
      ) : (
        <>
          <p className="mt-6 text-sm text-ink-soft" aria-live="polite">
            {filtered.length} {filtered.length === 1 ? "service" : "services"}
          </p>

          {category === "all" ? (
            <div className="mt-4 space-y-10">
              {groups.map(({ category: group, items }) => (
                <section key={group.value} aria-label={group.label}>
                  <CategoryHeading category={group} count={items.length} />
                  <div className={`mt-4 ${GRID_CLASS}`}>
                    {items.map((service) => (
                      <ServiceCard key={service.id} service={service} onBook={setBookingService} />
                    ))}
                  </div>
                </section>
              ))}
            </div>
          ) : (
            <div className={`mt-4 ${GRID_CLASS}`}>
              {filtered.map((service) => (
                <ServiceCard key={service.id} service={service} onBook={setBookingService} />
              ))}
            </div>
          )}
        </>
      )}

      <section
        id="custom"
        aria-labelledby="custom-heading"
        className="mt-14 scroll-mt-24 overflow-hidden rounded-2xl bg-gradient-to-br from-primary via-secondary to-tertiary p-8 text-white md:p-10"
      >
        <div className="flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
          <div className="max-w-2xl">
            <h2 id="custom-heading" className="font-display text-2xl font-bold">
              Can't find what you need?
            </h2>
            <p className="mt-2 text-[15px] opacity-90">
              Describe the service you're after — a special grooming style, a home visit, anything — and nearby
              approved shops will reply with a quote.
            </p>
          </div>
          <Button size="lg" onClick={() => setCustomOpen(true)} className="!bg-white !text-primary font-black shadow-lg">
            Request a custom service
          </Button>
        </div>
      </section>

      <MyServicesSection access={access} bookings={bookings} requests={requests} tab={tab} onTabChange={setTab} />

      {bookingService && (
        <BookingModal
          service={bookingService}
          onClose={() => setBookingService(null)}
          onBooked={bookings.reload}
          onViewMine={() => showMine("bookings")}
        />
      )}
      {customOpen && (
        <CustomServiceModal
          onClose={() => setCustomOpen(false)}
          onSent={requests.reload}
          onViewMine={() => showMine("requests")}
        />
      )}
    </Container>
  );
}
