import { Receipt } from "@phosphor-icons/react";
import { useCallback, useEffect, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { shortOrderId } from "../components/account/accountHelpers";
import { SupportThread } from "../components/account/SupportThread";
import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { StatusBadge } from "../components/ui/StatusBadge";
import { formatOrderDate } from "../lib/format";
import { fieldClassName } from "../lib/styles";
import { supabase } from "../lib/supabaseClient";
import { useAuthStore } from "../store/authStore";

const TICKET_COLUMNS = "id, shop_id, subject, status, created_at, shops(name)";

// Deep links from My orders: /support?shop=<shopId>&order=<orderId>. Anything
// that doesn't look like an id is ignored.
const SHOP_PARAM = /^[0-9a-fA-F-]{32,36}$/;
const ORDER_PARAM = /^[0-9a-fA-F-]{8,36}$/;

export function Support() {
  const status = useAuthStore((state) => state.status);
  const session = useAuthStore((state) => state.session);
  const userId = session?.user?.id;

  const [searchParams] = useSearchParams();
  const shopParam = SHOP_PARAM.test(searchParams.get("shop") ?? "") ? searchParams.get("shop") : "";
  const orderParam = ORDER_PARAM.test(searchParams.get("order") ?? "") ? searchParams.get("order") : "";
  // The subject a ticket about an order starts with, e.g. "Order #1A2B3C4D".
  const orderSubject = orderParam ? `Order #${shortOrderId(orderParam)}` : "";

  const [shops, setShops] = useState([]);
  const [shopsState, setShopsState] = useState("loading"); // loading | ready | error
  const [tickets, setTickets] = useState([]);
  const [ticketsLoading, setTicketsLoading] = useState(true);
  const [ticketsError, setTicketsError] = useState("");
  const [openTicketId, setOpenTicketId] = useState(null);

  const [subject, setSubject] = useState(orderSubject);
  const [shopId, setShopId] = useState(shopParam);
  const [message, setMessage] = useState("");
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [notice, setNotice] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // A different deep link replaces whatever was pre-filled.
  useEffect(() => {
    setSubject(orderSubject);
    setShopId(shopParam);
  }, [orderSubject, shopParam]);

  useEffect(() => {
    if (!userId) return undefined;
    let cancelled = false;
    supabase
      .from("shops")
      .select("id, name")
      .eq("status", "approved")
      .order("name", { ascending: true })
      .then(({ data, error }) => {
        if (cancelled) return;
        setShops(error ? [] : (data ?? []));
        setShopsState(error ? "error" : "ready");
      });
    return () => {
      cancelled = true;
    };
  }, [userId]);

  const loadTickets = useCallback(async () => {
    if (!userId) return;
    const { data, error } = await supabase
      .from("support_tickets")
      .select(TICKET_COLUMNS)
      .eq("customer_id", userId)
      .order("created_at", { ascending: false });
    if (error) {
      setTicketsError(error.message);
    } else {
      setTickets(data ?? []);
      setTicketsError("");
    }
    setTicketsLoading(false);
  }, [userId]);

  useEffect(() => {
    loadTickets();
  }, [loadTickets]);

  // The pre-selected shop only counts when it is one of the approved shops.
  const selectedShopId = shops.some((shop) => shop.id === shopId) ? shopId : "";

  // An open ticket about this very order: continue it instead of starting another.
  const existingTicket = orderSubject
    ? tickets.find(
        (ticket) =>
          ticket.subject === orderSubject && (ticket.shop_id ?? "") === shopParam && ticket.status !== "closed",
      )
    : undefined;

  const autoOpened = useRef(false);
  useEffect(() => {
    if (autoOpened.current || ticketsLoading || !existingTicket) return;
    autoOpened.current = true;
    setOpenTicketId(existingTicket.id);
  }, [ticketsLoading, existingTicket]);

  async function handleSubmit(event) {
    event.preventDefault();
    if (submitting) return;
    setFormError("");
    setNotice("");

    const validationErrors = {};
    if (!subject.trim()) validationErrors.subject = "Enter a subject.";
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    let ticketId;
    try {
      const { data, error } = await supabase
        .from("support_tickets")
        .insert({
          customer_id: userId,
          shop_id: selectedShopId || null,
          subject: subject.trim(),
        })
        .select("id")
        .single();
      if (error) throw error;
      ticketId = data.id;
    } catch (error) {
      setFormError(error?.message || "Couldn't raise that ticket. Try again.");
      setSubmitting(false);
      return;
    }

    // The ticket exists; if the first message fails the thread lets the customer send it again.
    let messageFailed = false;
    const text = message.trim();
    if (text) {
      try {
        const { error } = await supabase
          .from("support_messages")
          .insert({ ticket_id: ticketId, sender_id: userId, message: text });
        if (error) messageFailed = true;
      } catch {
        messageFailed = true;
      }
    }

    setSubject("");
    setShopId("");
    setMessage("");
    setNotice(
      messageFailed
        ? "Your ticket was created, but your message didn't send. Open the ticket below to try again."
        : "Ticket raised. Replies will show up in your tickets below.",
    );
    await loadTickets();
    setOpenTicketId(ticketId);
    setSubmitting(false);
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
          description="Message a shop about an order, or ask the PETSTA team for help."
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
      <p className="mt-2 text-[15px] text-ink-soft">
        Message a shop about an order, or ask the PETSTA team for help.
      </p>

      {orderSubject && (
        <p className="mt-6 flex max-w-lg items-start gap-2 rounded-lg border border-primary/20 bg-primary/5 px-4 py-3 text-sm text-ink-soft">
          <Receipt size={18} className="mt-0.5 flex-none text-primary" aria-hidden="true" />
          <span>
            This ticket is about <span className="font-medium text-ink">{orderSubject}</span>. Shops arrange pickup
            through tickets, because their contact details stay private.
          </span>
        </p>
      )}

      {existingTicket && (
        <p
          role="status"
          className="mt-4 max-w-lg rounded-lg border border-trust/30 bg-trust/5 px-4 py-3 text-sm text-ink"
        >
          You already have an open ticket about this order. Continue the conversation in your tickets below, or raise a
          new one here.
        </p>
      )}

      <form onSubmit={handleSubmit} noValidate className="mt-8 flex max-w-lg flex-col gap-5">
        <div>
          <label htmlFor="subject" className="block text-sm text-ink">
            Subject
          </label>
          <input
            id="subject"
            type="text"
            maxLength={120}
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            disabled={submitting}
            aria-invalid={Boolean(errors.subject)}
            className={fieldClassName(Boolean(errors.subject))}
          />
          {errors.subject && <p className="mt-1.5 text-sm text-error">{errors.subject}</p>}
        </div>

        <div>
          <label htmlFor="shop" className="block text-sm text-ink">
            Who is it for?
          </label>
          <select
            id="shop"
            value={selectedShopId}
            onChange={(event) => setShopId(event.target.value)}
            disabled={submitting || shopsState === "loading"}
            className="mt-1.5 w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
          >
            <option value="">General (the PETSTA team)</option>
            {shops.map((shop) => (
              <option key={shop.id} value={shop.id}>
                {shop.name}
              </option>
            ))}
          </select>
          {shopsState === "error" && (
            <p className="mt-1.5 text-xs text-ink-soft">
              Couldn't load the list of shops, so this ticket will go to the PETSTA team.
            </p>
          )}
        </div>

        <div>
          <label htmlFor="message" className="block text-sm text-ink">
            Message<span className="text-ink-soft"> (optional)</span>
          </label>
          <textarea
            id="message"
            rows={4}
            maxLength={1000}
            value={message}
            onChange={(event) => setMessage(event.target.value)}
            disabled={submitting}
            className={fieldClassName(false)}
          />
          <p className="mt-1.5 text-xs text-ink-soft">What do you need help with?</p>
        </div>

        {formError && (
          <p role="alert" className="text-sm text-error">
            {formError}
          </p>
        )}
        {notice && (
          <p role="status" className="text-sm text-trust">
            {notice}
          </p>
        )}

        <Button
          type="submit"
          variant="accent"
          size="md"
          disabled={submitting || shopsState === "loading"}
          className="w-fit"
        >
          {submitting ? "Submitting…" : "Raise ticket"}
        </Button>
      </form>

      <h2 className="mt-12 font-display text-xl font-semibold text-ink">Your tickets</h2>

      {ticketsLoading ? (
        <p role="status" className="mt-4 text-ink-soft">
          Loading…
        </p>
      ) : ticketsError ? (
        <div
          role="alert"
          className="mt-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-error/30 bg-error/5 px-4 py-3"
        >
          <p className="text-sm text-error">{ticketsError}</p>
          <Button variant="outline" size="sm" onClick={loadTickets}>
            Try again
          </Button>
        </div>
      ) : tickets.length > 0 ? (
        <div className="mt-4 flex flex-col gap-3">
          {tickets.map((ticket) => {
            const isOpen = openTicketId === ticket.id;
            return (
              <div key={ticket.id} className="rounded-xl border border-border bg-surface">
                <button
                  type="button"
                  onClick={() => setOpenTicketId(isOpen ? null : ticket.id)}
                  aria-expanded={isOpen}
                  className="flex w-full items-center justify-between gap-3 p-4 text-left"
                >
                  <span className="min-w-0">
                    <span className="block break-words text-[15px] font-medium text-ink">{ticket.subject}</span>
                    <span className="mt-1 block text-sm text-ink-soft">
                      {ticket.shops?.name ?? "General"} · {formatOrderDate(ticket.created_at)}
                    </span>
                  </span>
                  <StatusBadge status={ticket.status} className="flex-none" />
                </button>
                {isOpen && <SupportThread ticket={ticket} userId={userId} />}
              </div>
            );
          })}
        </div>
      ) : (
        <div className="mt-4">
          <EmptyState title="No tickets yet" description="Raise a ticket above if you need help." />
        </div>
      )}
    </Container>
  );
}
