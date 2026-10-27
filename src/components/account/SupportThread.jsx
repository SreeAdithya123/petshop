import { ArrowClockwise } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { formatOrderDate } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { Button } from "../ui/Button";

const MESSAGE_COLUMNS = "id, ticket_id, sender_id, message, created_at";

/**
 * One support conversation inside an expanded ticket: the messages (sent and
 * received) and a reply box. Customers talk to a shop through tickets because
 * shop contact details are private.
 */
export function SupportThread({ ticket, userId }) {
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);

  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState("");

  const closed = ticket.status === "closed";
  const otherParty = ticket.shops?.name || "PETSTA team";

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const { data, error } = await supabase
          .from("support_messages")
          .select(MESSAGE_COLUMNS)
          .eq("ticket_id", ticket.id)
          .order("created_at", { ascending: true });
        if (cancelled) return;
        if (error) {
          setLoadError(error.message);
        } else {
          setMessages(data ?? []);
          setLoadError("");
        }
      } catch (error) {
        if (!cancelled) setLoadError(error?.message || "Couldn't load the messages.");
      }
      if (!cancelled) setLoading(false);
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [ticket.id, reloadKey]);

  function refresh() {
    setLoading(true);
    setReloadKey((key) => key + 1);
  }

  async function handleSend(event) {
    event.preventDefault();
    const text = draft.trim();
    if (!text || sending) return;

    setSending(true);
    setSendError("");
    try {
      const { data, error } = await supabase
        .from("support_messages")
        .insert({ ticket_id: ticket.id, sender_id: userId, message: text })
        .select(MESSAGE_COLUMNS)
        .single();
      if (error) throw error;
      setDraft("");
      setMessages((current) => (current.some((message) => message.id === data.id) ? current : [...current, data]));
    } catch (error) {
      setSendError(error?.message || "Couldn't send your message. Please try again.");
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="border-t border-border px-4 py-4 sm:px-5">
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm text-ink-soft">Conversation with {otherParty}</p>
        <button
          type="button"
          onClick={refresh}
          disabled={loading}
          className="inline-flex items-center gap-1.5 text-sm text-primary hover:underline disabled:opacity-50"
        >
          <ArrowClockwise size={14} aria-hidden="true" />
          {loading ? "Refreshing…" : "Refresh"}
        </button>
      </div>

      {loadError && (
        <p role="alert" className="mt-3 text-sm text-error">
          {loadError}
        </p>
      )}

      {loading && messages.length === 0 && !loadError && (
        <p role="status" className="mt-3 text-sm text-ink-soft">
          Loading messages…
        </p>
      )}

      {!loading && !loadError && messages.length === 0 && (
        <p className="mt-3 text-sm text-ink-soft">
          {closed
            ? "No messages were sent on this ticket."
            : `No messages yet. Write the first one below and ${ticket.shops?.name ? "the shop" : "the PETSTA team"} will reply here.`}
        </p>
      )}

      {messages.length > 0 && (
        <ul className="mt-3 flex flex-col gap-3">
          {messages.map((message) => {
            const mine = message.sender_id === userId;
            return (
              <li key={message.id} className={`flex flex-col ${mine ? "items-end" : "items-start"}`}>
                <p
                  className={`max-w-[85%] whitespace-pre-wrap break-words rounded-2xl px-3.5 py-2.5 text-[15px] ${
                    mine ? "rounded-br-sm bg-primary text-white" : "rounded-bl-sm border border-border bg-paper text-ink"
                  }`}
                >
                  {message.message}
                </p>
                <p className="mt-1 text-xs text-ink-soft">
                  {mine ? "You" : otherParty} · {formatOrderDate(message.created_at)}
                </p>
              </li>
            );
          })}
        </ul>
      )}

      {closed ? (
        <p className="mt-4 text-sm text-ink-soft">This ticket is closed. Open a new ticket if you still need help.</p>
      ) : (
        <form onSubmit={handleSend} className="mt-4 flex flex-col gap-3">
          <div>
            <label htmlFor={`reply-${ticket.id}`} className="block text-sm text-ink">
              Reply
            </label>
            <textarea
              id={`reply-${ticket.id}`}
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              rows={3}
              maxLength={2000}
              disabled={sending}
              className="mt-1.5 w-full rounded-lg border border-border bg-surface px-4 py-2.5 text-[15px] text-ink focus:border-primary focus:outline-none"
            />
          </div>
          {sendError && (
            <p role="alert" className="text-sm text-error">
              {sendError}
            </p>
          )}
          <Button type="submit" variant="accent" size="sm" disabled={sending || !draft.trim()} className="self-start">
            {sending ? "Sending…" : "Send message"}
          </Button>
        </form>
      )}
    </div>
  );
}
