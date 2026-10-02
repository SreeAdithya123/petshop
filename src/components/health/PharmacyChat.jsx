import { PaperPlaneTilt, Pill, Robot, Siren, Stethoscope, Warning } from "@phosphor-icons/react";
import { useCallback, useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { formatPrice } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { Button } from "../ui/Button";
import {
  DISCLAIMER,
  INTRO_MESSAGE,
  QUICK_REPLIES,
  TOPICS,
  buildProductFilter,
  getReply,
} from "./pharmacyIntents";

// Customer-facing: no cost_price, and the shop embed is name-only.
const PRODUCT_COLUMNS =
  "id, shop_id, name, description, price, stock_quantity, photo_urls, requires_prescription, category, shops(name)";
const MAX_MESSAGE_LENGTH = 300;

const INITIAL_MESSAGES = [{ id: 1, role: "bot", reply: { kind: "greeting", message: INTRO_MESSAGE } }];

function VetLink({ children }) {
  return (
    <a
      href="#vet"
      className="mt-3 inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:underline"
    >
      <Stethoscope size={16} aria-hidden="true" /> {children}
    </a>
  );
}

function ProductThumb({ src }) {
  const [failed, setFailed] = useState(false);

  if (!src || failed) {
    return (
      <span className="flex h-10 w-10 flex-none items-center justify-center rounded-lg bg-primary/10 text-primary">
        <Pill size={20} aria-hidden="true" />
      </span>
    );
  }
  return (
    <img
      src={src}
      alt=""
      loading="lazy"
      onError={() => setFailed(true)}
      className="h-10 w-10 flex-none rounded-lg object-cover"
    />
  );
}

/** Looks up catalogue products matching the reply's keywords and lists up to four. */
function ProductSuggestions({ keywords, category, onSettled }) {
  const [state, setState] = useState({ status: "loading", items: [], error: "" });

  useEffect(() => {
    let cancelled = false;
    async function load() {
      let query = supabase
        .from("products")
        .select(PRODUCT_COLUMNS)
        .eq("status", "available")
        .or(buildProductFilter(keywords));
      if (category) query = query.eq("category", category);
      const { data, error } = await query.limit(4);
      if (cancelled) return;
      if (error) setState({ status: "error", items: [], error: error.message });
      else setState({ status: "done", items: data ?? [], error: "" });
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [keywords, category]);

  // The list grows once results arrive; let the chat keep the newest reply in view.
  useEffect(() => {
    if (state.status !== "loading") onSettled?.();
  }, [state.status, onSettled]);

  if (state.status === "loading") {
    return <p className="mt-3 text-ink-soft">Looking for related products…</p>;
  }
  if (state.status === "error") {
    return (
      <p role="alert" className="mt-3 text-error">
        Couldn't search the store: {state.error}
      </p>
    );
  }
  if (state.items.length === 0) {
    return (
      <p className="mt-3 text-ink-soft">
        Nothing in the store matches right now. A vet can recommend the right option for your pet.
      </p>
    );
  }

  return (
    <div className="mt-3">
      <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">In the store</p>
      <ul className="mt-2 space-y-2">
        {state.items.map((product) => (
          <li key={product.id}>
            <Link
              to={`/store/${product.id}`}
              className="flex items-center gap-3 rounded-lg border border-border bg-paper p-2.5 transition-colors hover:bg-primary/5"
            >
              <ProductThumb src={product.photo_urls?.[0]} />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-ink">{product.name}</p>
                {product.shops?.name && <p className="truncate text-xs text-ink-soft">{product.shops.name}</p>}
                {product.requires_prescription && (
                  <span className="mt-1 inline-flex rounded-full bg-warning/15 px-2 py-0.5 text-[11px] font-medium text-amber-700">
                    Prescription needed
                  </span>
                )}
              </div>
              <p className="flex-none text-sm font-semibold text-accent">{formatPrice(product.price)}</p>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}

function BotReply({ reply, onSend, onSettled }) {
  if (reply.kind === "emergency") {
    return (
      <>
        <div className="rounded-lg border border-error/40 bg-error/5 p-3">
          <p className="flex items-center gap-1.5 font-semibold text-error">
            <Siren size={18} weight="fill" aria-hidden="true" /> Urgent
          </p>
          <p className="mt-1 font-medium text-ink">{reply.message}</p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-ink">
            {reply.steps.map((step) => (
              <li key={step}>{step}</li>
            ))}
          </ul>
        </div>
        <VetLink>Book a video consult for follow-up advice</VetLink>
      </>
    );
  }

  if (reply.kind === "advice") {
    return (
      <>
        <p className="font-semibold text-ink">{reply.title}</p>
        <p className="mt-1 text-ink">{reply.message}</p>
        <div className="mt-3 rounded-lg border border-warning/40 bg-warning/10 p-3">
          <p className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-amber-700">
            <Warning size={14} weight="fill" aria-hidden="true" /> See a vet if
          </p>
          <ul className="mt-1.5 list-disc space-y-0.5 pl-5 text-ink">
            {reply.seeVet.map((sign) => (
              <li key={sign}>{sign}</li>
            ))}
          </ul>
        </div>
        {reply.searchKeywords.length > 0 ? (
          <ProductSuggestions keywords={reply.searchKeywords} category={reply.category} onSettled={onSettled} />
        ) : (
          <p className="mt-3 text-ink-soft">{reply.noProductsNote}</p>
        )}
        <VetLink>Book a video consult with a vet</VetLink>
      </>
    );
  }

  return (
    <>
      <p className="text-ink">{reply.message}</p>
      {reply.kind === "fallback" && (
        <>
          <div className="mt-3 flex flex-wrap gap-2">
            {TOPICS.map((topic) => (
              <button
                key={topic}
                type="button"
                onClick={() => onSend(topic)}
                className="rounded-full border border-border bg-paper px-3 py-1.5 text-xs font-medium text-ink transition-colors hover:bg-primary/5"
              >
                {topic}
              </button>
            ))}
          </div>
          <VetLink>Book a video consult with a vet</VetLink>
        </>
      )}
    </>
  );
}

/**
 * Rule-based pharmacy assistant. Replies come from pharmacyIntents.js (no AI),
 * followed by a catalogue lookup for related products. Never for emergencies.
 */
export function PharmacyChat() {
  const [messages, setMessages] = useState(INITIAL_MESSAGES);
  const [draft, setDraft] = useState("");
  const listRef = useRef(null);
  const nextId = useRef(2);

  const scrollToBottom = useCallback(() => {
    const list = listRef.current;
    if (list) list.scrollTop = list.scrollHeight;
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  function send(text) {
    const trimmed = text.trim().slice(0, MAX_MESSAGE_LENGTH);
    if (!trimmed) return;
    const userId = nextId.current++;
    const botId = nextId.current++;
    setMessages((previous) => [
      ...previous,
      { id: userId, role: "user", text: trimmed },
      { id: botId, role: "bot", reply: getReply(trimmed) },
    ]);
    setDraft("");
  }

  function handleSubmit(event) {
    event.preventDefault();
    send(draft);
  }

  const lastId = messages[messages.length - 1].id;

  return (
    <div className="flex h-[34rem] max-h-[calc(100dvh-10rem)] min-h-[26rem] flex-col overflow-hidden rounded-2xl border border-border bg-surface">
      <div className="flex items-center justify-between gap-3 border-b border-border px-4 py-3">
        <div className="flex items-center gap-3">
          <span className="flex h-9 w-9 flex-none items-center justify-center rounded-full bg-primary/10 text-primary">
            <Robot size={20} weight="duotone" aria-hidden="true" />
          </span>
          <div>
            <p className="text-[15px] font-semibold text-ink">Pharmacy assistant (automated)</p>
            <p className="text-xs text-ink-soft">Rule-based tips. Not a vet or a pharmacist.</p>
          </div>
        </div>
        {messages.length > 1 && (
          <button
            type="button"
            onClick={() => setMessages(INITIAL_MESSAGES)}
            className="flex-none text-xs font-medium text-primary hover:underline"
          >
            New chat
          </button>
        )}
      </div>

      <div
        ref={listRef}
        role="log"
        aria-live="polite"
        aria-label="Conversation with the pharmacy assistant"
        className="flex-1 space-y-3 overflow-y-auto bg-paper px-4 py-4"
      >
        {messages.map((message) =>
          message.role === "user" ? (
            <div key={message.id} className="flex justify-end">
              <p className="max-w-[85%] break-words rounded-2xl rounded-br-sm bg-primary px-4 py-2.5 text-sm text-white">
                {message.text}
              </p>
            </div>
          ) : (
            <div key={message.id} className="flex">
              <div className="max-w-[92%] rounded-2xl rounded-bl-sm border border-border bg-surface px-4 py-3 text-sm">
                <BotReply
                  reply={message.reply}
                  onSend={send}
                  onSettled={message.id === lastId ? scrollToBottom : undefined}
                />
                <p className="mt-3 border-t border-border pt-2 text-xs text-ink-soft">{DISCLAIMER}</p>
              </div>
            </div>
          ),
        )}
      </div>

      <div className="border-t border-border">
        <div className="flex gap-2 overflow-x-auto px-3 pt-3 scrollbar-none">
          {QUICK_REPLIES.map((reply) => (
            <button
              key={reply}
              type="button"
              onClick={() => send(reply)}
              className="flex-none whitespace-nowrap rounded-full border border-border bg-surface px-3 py-1.5 text-xs font-medium text-ink transition-colors hover:bg-primary/5"
            >
              {reply}
            </button>
          ))}
        </div>
        <form onSubmit={handleSubmit} className="flex items-center gap-2 p-3">
          <label htmlFor="pharmacy-message" className="sr-only">
            Describe your pet's symptoms or what you need
          </label>
          <input
            id="pharmacy-message"
            type="text"
            autoComplete="off"
            maxLength={MAX_MESSAGE_LENGTH}
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            placeholder="e.g. my cat keeps scratching her ear"
            className={`${fieldClassName(false)} !mt-0 min-w-0 flex-1`}
          />
          <Button type="submit" disabled={!draft.trim()} aria-label="Send message">
            <PaperPlaneTilt size={18} weight="fill" aria-hidden="true" />
          </Button>
        </form>
      </div>
    </div>
  );
}
