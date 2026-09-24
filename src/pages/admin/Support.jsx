import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";
import { useAuthStore } from "../../store/authStore";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";

const STATUS_OPTIONS = [
  { value: "all", label: "All" },
  { value: "open", label: "Open" },
  { value: "in_progress", label: "In progress" },
  { value: "resolved", label: "Resolved" },
  { value: "closed", label: "Closed" },
];

const STATUS_STYLES = {
  open: "bg-primary/10 text-primary",
  in_progress: "bg-primary/10 text-primary",
  resolved: "bg-trust/10 text-trust",
  closed: "bg-ink/5 text-ink-soft",
};

const STATUS_LABELS = {
  open: "Open",
  in_progress: "In progress",
  resolved: "Resolved",
  closed: "Closed",
};

function StatusPill({ status }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ${
        STATUS_STYLES[status] || "bg-ink/5 text-ink-soft"
      }`}
    >
      {STATUS_LABELS[status] || status}
    </span>
  );
}

function formatTimestamp(isoString) {
  return new Date(isoString).toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function AdminSupport() {
  const session = useAuthStore((state) => state.session);
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("all");
  const [selectedId, setSelectedId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);

  async function loadTickets() {
    setLoading(true);
    const { data } = await supabase
      .from("support_tickets")
      .select("*, profiles(name,email), shops(name)")
      .order("created_at", { ascending: false });
    setTickets(data ?? []);
    setLoading(false);
  }

  useEffect(() => {
    loadTickets();
  }, []);

  async function loadMessages(ticketId) {
    setMessagesLoading(true);
    const { data } = await supabase
      .from("support_messages")
      .select("*, profiles(name)")
      .eq("ticket_id", ticketId)
      .order("created_at", { ascending: true });
    setMessages(data ?? []);
    setMessagesLoading(false);
  }

  function toggleTicket(ticket) {
    if (selectedId === ticket.id) {
      setSelectedId(null);
      setMessages([]);
      setReply("");
      return;
    }
    setSelectedId(ticket.id);
    setReply("");
    loadMessages(ticket.id);
  }

  async function handleSendReply(ticketId) {
    if (!reply.trim()) return;
    setSending(true);
    await supabase.from("support_messages").insert({
      ticket_id: ticketId,
      sender_id: session.user.id,
      message: reply.trim(),
    });
    setReply("");
    await loadMessages(ticketId);
    setSending(false);
  }

  async function handleStatusChange(ticket, nextStatus) {
    await supabase.from("support_tickets").update({ status: nextStatus }).eq("id", ticket.id);
    setTickets((prev) => prev.map((item) => (item.id === ticket.id ? { ...item, status: nextStatus } : item)));
  }

  const filteredTickets =
    statusFilter === "all" ? tickets : tickets.filter((ticket) => ticket.status === statusFilter);

  return (
    <Container className="py-12">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-bold text-ink">Support tickets</h1>
          <p className="mt-1 text-[15px] text-ink-soft">All customer support tickets across the platform.</p>
        </div>
        <div>
          <label htmlFor="statusFilter" className="sr-only">
            Filter by status
          </label>
          <select
            id="statusFilter"
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value)}
            className="rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
          >
            {STATUS_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {loading && <p className="mt-8 text-[15px] text-ink-soft">Loading tickets…</p>}

      {!loading && tickets.length === 0 && (
        <div className="mt-8">
          <EmptyState title="No support tickets yet" description="Customer support tickets will show up here." />
        </div>
      )}

      {!loading && tickets.length > 0 && (
        <ul className="mt-8 divide-y divide-border rounded-xl border border-border bg-surface">
          {filteredTickets.map((ticket) => {
            const isSelected = selectedId === ticket.id;
            return (
              <li key={ticket.id} className="p-5">
                <button
                  type="button"
                  onClick={() => toggleTicket(ticket)}
                  className="flex w-full flex-col gap-2 text-left sm:flex-row sm:items-center sm:justify-between"
                >
                  <div>
                    <div className="font-display font-semibold text-ink">{ticket.subject}</div>
                    <div className="mt-1 text-sm text-ink-soft">
                      {ticket.profiles?.name || "Customer"} · {ticket.shops?.name || "General"} ·{" "}
                      {formatTimestamp(ticket.created_at)}
                    </div>
                  </div>
                  <StatusPill status={ticket.status} />
                </button>

                {isSelected && (
                  <div className="mt-5 border-t border-border pt-5">
                    <div className="flex flex-wrap items-center justify-between gap-4">
                      <label htmlFor={`status-${ticket.id}`} className="text-sm font-medium text-ink">
                        Status
                      </label>
                      <select
                        id={`status-${ticket.id}`}
                        value={ticket.status}
                        onChange={(event) => handleStatusChange(ticket, event.target.value)}
                        className="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-ink focus:border-primary focus:outline-none"
                      >
                        {STATUS_OPTIONS.filter((option) => option.value !== "all").map((option) => (
                          <option key={option.value} value={option.value}>
                            {option.label}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div className="mt-4 flex flex-col gap-3">
                      {messagesLoading && <p className="text-sm text-ink-soft">Loading messages…</p>}
                      {!messagesLoading && messages.length === 0 && (
                        <p className="text-sm text-ink-soft">No messages yet.</p>
                      )}
                      {!messagesLoading &&
                        messages.map((message) => (
                          <div key={message.id} className="rounded-lg bg-paper p-3">
                            <div className="flex items-center justify-between gap-3">
                              <span className="text-sm font-medium text-ink">
                                {message.profiles?.name || "Unknown"}
                              </span>
                              <span className="text-xs text-ink-soft">{formatTimestamp(message.created_at)}</span>
                            </div>
                            <p className="mt-1 text-[15px] text-ink">{message.message}</p>
                          </div>
                        ))}
                    </div>

                    <div className="mt-4 flex flex-col gap-3">
                      <label htmlFor={`reply-${ticket.id}`} className="text-sm font-medium text-ink">
                        Reply
                      </label>
                      <textarea
                        id={`reply-${ticket.id}`}
                        rows={3}
                        value={reply}
                        onChange={(event) => setReply(event.target.value)}
                        className="w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
                      />
                      <Button
                        variant="accent"
                        size="sm"
                        className="self-start"
                        disabled={sending || !reply.trim()}
                        onClick={() => handleSendReply(ticket.id)}
                      >
                        {sending ? "Sending…" : "Send reply"}
                      </Button>
                    </div>
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </Container>
  );
}
