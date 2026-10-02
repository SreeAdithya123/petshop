import { useEffect, useMemo, useState } from "react";
import { supabase } from "../../lib/supabaseClient";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { formatDate, formatPrice } from "../../lib/format";

const RECENT_DAYS = 30;

const TABS = [
  { value: "pending", label: "Pending" },
  { value: "approved", label: "Approved" },
  { value: "suspended", label: "Suspended" },
  { value: "all", label: "All" },
];

const EMPTY_MESSAGES = {
  pending: "No services are waiting for approval.",
  approved: "No services are approved yet.",
  suspended: "No services are suspended.",
  all: "No services yet.",
};

function titleCase(value) {
  const text = String(value ?? "").replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

export function AdminServices() {
  const [services, setServices] = useState([]);
  const [activity, setActivity] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [tab, setTab] = useState("pending");
  const [busyId, setBusyId] = useState(null);
  const [actionError, setActionError] = useState("");

  useEffect(() => {
    let cancelled = false;
    const since = new Date(Date.now() - RECENT_DAYS * 24 * 60 * 60 * 1000).toISOString();

    async function load() {
      const [servicesResult, requestsResult, bookingsResult] = await Promise.all([
        supabase
          .from("services")
          .select("id, shop_id, category, name, description, price, duration_minutes, status, created_at, shops(name)")
          .order("created_at", { ascending: false }),
        supabase.from("custom_service_requests").select("id", { count: "exact", head: true }).gte("created_at", since),
        supabase.from("service_bookings").select("id", { count: "exact", head: true }).gte("created_at", since),
      ]);
      if (cancelled) return;

      if (servicesResult.error) {
        setError(servicesResult.error.message);
      } else {
        setError(null);
        setServices(servicesResult.data ?? []);
      }
      setActivity({
        requests: requestsResult.count ?? 0,
        bookings: bookingsResult.count ?? 0,
        error: (requestsResult.error || bookingsResult.error)?.message ?? null,
      });
      setLoading(false);
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [reloadKey]);

  const counts = useMemo(() => {
    const result = { pending: 0, approved: 0, suspended: 0, all: services.length };
    for (const service of services) {
      if (service.status in result) result[service.status] += 1;
    }
    return result;
  }, [services]);

  const visibleServices = useMemo(
    () => (tab === "all" ? services : services.filter((service) => service.status === tab)),
    [services, tab],
  );

  function retry() {
    setLoading(true);
    setError(null);
    setReloadKey((key) => key + 1);
  }

  async function updateStatus(service, nextStatus, { confirmMessage } = {}) {
    if (confirmMessage && !window.confirm(confirmMessage)) return;
    setActionError("");
    setBusyId(service.id);
    const { data, error: updateError } = await supabase
      .from("services")
      .update({ status: nextStatus })
      .eq("id", service.id)
      .select("id");
    setBusyId(null);

    if (updateError) {
      setActionError(updateError.message);
    } else if (!data || data.length === 0) {
      // RLS filters rows silently, so "no error" alone doesn't prove the update landed.
      setActionError(`Couldn't update "${service.name}". It may have been removed or you may lack permission.`);
    } else {
      setServices((prev) => prev.map((row) => (row.id === service.id ? { ...row, status: nextStatus } : row)));
    }
  }

  function renderActions(service) {
    const disabled = busyId === service.id;
    const shopName = service.shops?.name ?? "this shop";

    if (service.status === "approved") {
      return (
        <Button
          variant="outline"
          size="sm"
          disabled={disabled}
          onClick={() =>
            updateStatus(service, "suspended", {
              confirmMessage: `Suspend "${service.name}" from ${shopName}? It will no longer be visible to customers.`,
            })
          }
        >
          Suspend
        </Button>
      );
    }

    return (
      <div className="flex gap-2">
        <Button variant="primary" size="sm" disabled={disabled} onClick={() => updateStatus(service, "approved")}>
          Approve
        </Button>
        {service.status === "pending" && (
          <Button
            variant="outline"
            size="sm"
            disabled={disabled}
            onClick={() =>
              updateStatus(service, "suspended", {
                confirmMessage: `Suspend "${service.name}" from ${shopName}? It will not be approved.`,
              })
            }
          >
            Suspend
          </Button>
        )}
      </div>
    );
  }

  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-bold text-ink">Manage services</h1>
      <p className="mt-1 text-[15px] text-ink-soft">
        Review new services before customers can see or book them.
      </p>

      {loading ? (
        <p className="mt-8 text-[15px] text-ink-soft">Loading services…</p>
      ) : error ? (
        <div className="mt-8 flex flex-col items-start gap-3">
          <p className="text-[15px] text-error">Couldn't load services: {error}</p>
          <Button type="button" variant="outline" size="sm" onClick={retry}>
            Try again
          </Button>
        </div>
      ) : (
        <>
          <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
            <SummaryTile label="Awaiting approval" value={counts.pending} />
            <SummaryTile
              label={`Custom requests, last ${RECENT_DAYS} days`}
              value={activity?.error ? "—" : activity?.requests}
            />
            <SummaryTile
              label={`Service bookings, last ${RECENT_DAYS} days`}
              value={activity?.error ? "—" : activity?.bookings}
            />
          </div>
          {activity?.error && (
            <p className="mt-3 text-sm text-error">Couldn't load recent activity: {activity.error}</p>
          )}

          <div
            role="group"
            aria-label="Filter services by status"
            className="mt-8 flex w-fit max-w-full gap-1 overflow-x-auto rounded-lg border border-border p-1"
          >
            {TABS.map((option) => (
              <button
                key={option.value}
                type="button"
                aria-pressed={tab === option.value}
                onClick={() => setTab(option.value)}
                className={`whitespace-nowrap rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                  tab === option.value ? "bg-primary text-white" : "text-ink-soft hover:text-ink"
                }`}
              >
                {option.label} ({counts[option.value]})
              </button>
            ))}
          </div>

          {actionError && (
            <p role="alert" className="mt-4 text-sm text-error">
              {actionError}
            </p>
          )}

          {services.length === 0 ? (
            <div className="mt-6">
              <EmptyState title="No services yet" description="Services will appear here once sellers create them." />
            </div>
          ) : visibleServices.length === 0 ? (
            <p className="mt-6 text-[15px] text-ink-soft">{EMPTY_MESSAGES[tab]}</p>
          ) : (
            <ul className="mt-6 divide-y divide-border rounded-xl border border-border bg-surface">
              {visibleServices.map((service) => (
                <li key={service.id} className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                      <span className="font-display font-semibold text-ink">{service.name}</span>
                      <StatusBadge status={service.status} />
                    </div>
                    <div className="mt-1 text-sm text-ink-soft">
                      {service.shops?.name ?? "Unknown shop"} &middot; {titleCase(service.category)}
                    </div>
                    <div className="mt-1 text-sm text-ink-soft">
                      <span className="font-medium text-accent">{formatPrice(service.price)}</span>
                      {service.duration_minutes ? ` · ${service.duration_minutes} min` : ""}
                      {service.created_at ? ` · Added ${formatDate(service.created_at)}` : ""}
                    </div>
                    {service.description && (
                      <p className="mt-2 line-clamp-2 max-w-prose text-sm text-ink-soft">{service.description}</p>
                    )}
                  </div>
                  <div className="flex-none">{renderActions(service)}</div>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </Container>
  );
}

function SummaryTile({ label, value }) {
  return (
    <div className="rounded-xl border border-border bg-surface p-5">
      <div className="font-display text-3xl font-bold text-ink">{value}</div>
      <div className="mt-1 text-sm text-ink-soft">{label}</div>
    </div>
  );
}
