import { useEffect, useState } from "react";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

const statusLabels = {
  open: "Open",
  in_progress: "In progress",
  resolved: "Resolved",
  closed: "Closed",
};

export function Support() {
  const status = useAuthStore((state) => state.status);
  const session = useAuthStore((state) => state.session);

  const [shops, setShops] = useState([]);
  const [tickets, setTickets] = useState([]);
  const [ticketsLoading, setTicketsLoading] = useState(true);

  const [subject, setSubject] = useState("");
  const [shopId, setShopId] = useState("");
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!session) return;
    let cancelled = false;
    supabase
      .from("shops")
      .select("id,name")
      .eq("status", "approved")
      .then(({ data }) => {
        if (!cancelled) setShops(data ?? []);
      });
    return () => {
      cancelled = true;
    };
  }, [session]);

  async function loadTickets() {
    if (!session) return;
    setTicketsLoading(true);
    const { data } = await supabase
      .from("support_tickets")
      .select("*, shops(name)")
      .eq("customer_id", session.user.id)
      .order("created_at", { ascending: false });
    setTickets(data ?? []);
    setTicketsLoading(false);
  }

  useEffect(() => {
    loadTickets();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    const validationErrors = {};
    if (!subject.trim()) validationErrors.subject = "Enter a subject.";
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      const { error } = await supabase.from("support_tickets").insert({
        customer_id: session.user.id,
        shop_id: shopId || null,
        subject: subject.trim(),
      });
      if (error) throw error;
      setSubject("");
      setShopId("");
      await loadTickets();
    } catch (error) {
      setFormError(error.message || "Couldn't raise that ticket. Try again.");
    } finally {
      setSubmitting(false);
    }
  }

  if (status === "loading") {
    return (
      <Container className="py-16">
        <p className="text-ink-soft">Loading…</p>
      </Container>
    );
  }

  if (!session) {
    return (
      <Container className="py-16">
        <EmptyState
          title="Log in to get support"
          action={
            <Button to="/login" size="sm">
              Log in
            </Button>
          }
        />
      </Container>
    );
  }

  return (
    <Container className="py-10 lg:py-12">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Support</h1>
      <p className="mt-2 text-[15px] text-ink-soft">Raise a ticket and we'll get back to you.</p>

      <form onSubmit={handleSubmit} noValidate className="mt-8 flex max-w-lg flex-col gap-5">
        <div>
          <label htmlFor="subject" className="block text-sm text-ink">
            Subject
          </label>
          <input
            id="subject"
            type="text"
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            aria-invalid={Boolean(errors.subject)}
            className={fieldClassName(Boolean(errors.subject))}
          />
          {errors.subject && <p className="mt-1.5 text-sm text-error">{errors.subject}</p>}
        </div>

        <div>
          <label htmlFor="shop" className="block text-sm text-ink">
            Shop
          </label>
          <select
            id="shop"
            value={shopId}
            onChange={(event) => setShopId(event.target.value)}
            className="mt-1.5 w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
          >
            <option value="">General (not shop-specific)</option>
            {shops.map((shop) => (
              <option key={shop.id} value={shop.id}>
                {shop.name}
              </option>
            ))}
          </select>
        </div>

        {formError && <p className="text-sm text-error">{formError}</p>}

        <Button type="submit" variant="accent" size="md" disabled={submitting} className="w-fit">
          {submitting ? "Submitting…" : "Raise ticket"}
        </Button>
      </form>

      <h2 className="mt-12 font-display text-xl font-semibold text-ink">Your tickets</h2>

      {ticketsLoading ? (
        <p className="mt-4 text-ink-soft">Loading…</p>
      ) : tickets.length > 0 ? (
        <div className="mt-4 flex flex-col gap-3">
          {tickets.map((ticket) => (
            <div key={ticket.id} className="rounded-xl border border-border bg-surface p-4">
              <div className="flex items-center justify-between gap-3">
                <p className="text-[15px] font-medium text-ink">{ticket.subject}</p>
                <span className="rounded-full bg-primary/10 px-2.5 py-1 text-xs text-primary">
                  {statusLabels[ticket.status] ?? ticket.status}
                </span>
              </div>
              <p className="mt-1 text-sm text-ink-soft">{ticket.shops?.name ?? "General"}</p>
            </div>
          ))}
        </div>
      ) : (
        <div className="mt-4">
          <EmptyState title="No tickets yet" description="Raise a ticket above if you need help." />
        </div>
      )}
    </Container>
  );
}
