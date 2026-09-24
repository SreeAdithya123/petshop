import { useEffect, useState } from "react";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { useMyShop } from "../../hooks/useMyShop";
import { supabase } from "../../lib/supabaseClient";
import { useAuthStore } from "../../store/authStore";

const statusOptions = ["open", "in_progress", "resolved", "closed"];

const statusStyles = {
  open: "bg-primary/10 text-primary",
  in_progress: "bg-primary/10 text-primary",
  resolved: "bg-trust/10 text-trust",
  closed: "bg-ink/5 text-ink-soft",
};

function StatusPill({ status }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ${
        statusStyles[status] || "bg-ink/5 text-ink-soft"
      }`}
    >
      {status.replace("_", " ")}
    </span>
  );
}

export function SellerSupport() {
  const { shop, loading: shopLoading } = useMyShop();
  const userId = useAuthStore((state) => state.session?.user?.id);

  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [selectedId, setSelectedId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);
  const [updatingStatus, setUpdatingStatus] = useState(false);

  async function loadTickets() {
    if (!shop) return;
    setLoading(true);
    const { data, error: queryError } = await supabase
      .from("support_tickets")
      .select("*, profiles(name,email)")
      .eq("shop_id", shop.id)
      .order("created_at", { ascending: false });

    if (queryError) setError(queryError.message);
    else {
      setError(null);
      setTickets(data || []);
    }
    setLoading(false);
  }

  useEffect(() => {
    if (shopLoading) return;
    if (!shop) {
      setLoading(false);
      return;
    }
    loadTickets();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [shop, shopLoading]);

  async function loadMessages(ticketId) {
    setMessagesLoading(true);
    const { data, error: queryError } = await supabase
      .from("support_messages")
      .select("*, profiles(name)")
      .eq("ticket_id", ticketId)
      .order("created_at", { ascending: true });

    if (!queryError) setMessages(data || []);
    setMessagesLoading(false);
  }

  function selectTicket(ticketId) {
    setSelectedId((current) => (current === ticketId ? null : ticketId));
    setReply("");
    if (ticketId !== selectedId) loadMessages(ticketId);
  }

  async function handleSendReply(event) {
    event.preventDefault();
    if (!reply.trim() || !selectedId) return;

    setSending(true);
    const { error: insertError } = await supabase
      .from("support_messages")
      .insert({ ticket_id: selectedId, sender_id: userId, message: reply.trim() });

    if (!insertError) {
      setReply("");
      await loadMessages(selectedId);
    }
    setSending(false);
  }

  async function handleStatusChange(ticketId, nextStatus) {
    setUpdatingStatus(true);
    const { error: updateError } = await supabase
      .from("support_tickets")
      .update({ status: nextStatus })
      .eq("id", ticketId);

    if (!updateError) {
      setTickets((current) =>
        current.map((ticket) => (ticket.id === ticketId ? { ...ticket, status: nextStatus } : ticket))
      );
    }
    setUpdatingStatus(false);
  }

  if (shopLoading || loading) {
    return (
      <Container className="py-12">
        <p className="text-[15px] text-ink-soft">Loading support tickets…</p>
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
        <p className="text-[15px] text-error">Couldn't load support tickets: {error}</p>
      </Container>
    );
  }

  if (tickets.length === 0) {
    return (
      <Container className="py-12">
        <EmptyState title="No support tickets yet" description="Customer questions about your shop will show up here." />
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-bold text-ink">Support tickets</h1>
      <p className="mt-2 text-[15px] text-ink-soft">Questions from customers about your shop.</p>

      <div className="mt-8 flex flex-col gap-4">
        {tickets.map((ticket) => {
          const isOpen = selectedId === ticket.id;
          return (
            <div key={ticket.id} className="rounded-xl border border-border bg-surface">
              <button
                type="button"
                onClick={() => selectTicket(ticket.id)}
                className="flex w-full flex-wrap items-center justify-between gap-3 p-6 text-left"
              >
                <div>
                  <p className="font-display text-lg font-semibold text-ink">{ticket.subject}</p>
                  <p className="mt-1 text-sm text-ink-soft">
                    {ticket.profiles?.name || "Customer"} &middot;{" "}
                    {new Date(ticket.created_at).toLocaleDateString()}
                  </p>
                </div>
                <StatusPill status={ticket.status} />
              </button>

              {isOpen && (
                <div className="border-t border-border p-6">
                  <div>
                    <label htmlFor={`status-${ticket.id}`} className="block text-sm text-ink">
                      Ticket status
                    </label>
                    <select
                      id={`status-${ticket.id}`}
                      value={ticket.status}
                      disabled={updatingStatus}
                      onChange={(event) => handleStatusChange(ticket.id, event.target.value)}
                      className="mt-1.5 w-full max-w-xs rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
                    >
                      {statusOptions.map((option) => (
                        <option key={option} value={option}>
                          {option.replace("_", " ")}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="mt-6 flex flex-col gap-4">
                    {messagesLoading && <p className="text-sm text-ink-soft">Loading messages…</p>}
                    {!messagesLoading && messages.length === 0 && (
                      <p className="text-sm text-ink-soft">No messages yet.</p>
                    )}
                    {!messagesLoading &&
                      messages.map((message) => (
                        <div key={message.id} className="rounded-lg bg-paper p-4">
                          <div className="flex items-baseline justify-between gap-3">
                            <p className="text-sm font-medium text-ink">{message.profiles?.name || "User"}</p>
                            <p className="text-xs text-ink-soft">
                              {new Date(message.created_at).toLocaleString()}
                            </p>
                          </div>
                          <p className="mt-1.5 text-[15px] text-ink">{message.message}</p>
                        </div>
                      ))}
                  </div>

                  <form onSubmit={handleSendReply} className="mt-6 flex flex-col gap-3">
                    <div>
                      <label htmlFor={`reply-${ticket.id}`} className="block text-sm text-ink">
                        Reply
                      </label>
                      <textarea
                        id={`reply-${ticket.id}`}
                        value={reply}
                        onChange={(event) => setReply(event.target.value)}
                        rows={3}
                        className="mt-1.5 w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
                      />
                    </div>
                    <Button type="submit" variant="accent" size="sm" disabled={sending || !reply.trim()} className="self-start">
                      {sending ? "Sending…" : "Send reply"}
                    </Button>
                  </form>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </Container>
  );
}
