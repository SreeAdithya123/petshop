import { Check, VideoCamera, X } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { AccountPageHeader, ErrorNote, LoadingNote } from "../../components/account/AccountPage";
import { formatTimeOfDay, safeExternalUrl } from "../../components/account/accountHelpers";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { formatDate, formatOrderDate } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { useAuthStore } from "../../store/authStore";
import { useCatalog } from "../../store/catalogStore";

const DEMO_COLUMNS =
  "id, pet_id, pet_name, pet_breed, pet_species, shop_name, preferred_date, preferred_time, mode, message, status, meet_link, seller_note, confirmed_date, confirmed_time, created_at";

const ACTIVE_STATUSES = ["pending", "approved"];
const MODE_LABELS = { video: "Video call", in_person: "In person" };

const FILTERS = [
  { id: "all", label: "All", matches: () => true },
  { id: "active", label: "Active", matches: (demo) => ACTIVE_STATUSES.includes(demo.status) },
  { id: "past", label: "Past", matches: (demo) => !ACTIVE_STATUSES.includes(demo.status) },
];

/** Requested -> Approved -> Completed, or Requested -> a terminal "Rejected" / "Cancelled". */
function progressSteps(status) {
  if (status === "rejected" || status === "cancelled") {
    return {
      steps: [
        { label: "Requested", state: "done" },
        { label: status === "rejected" ? "Rejected" : "Cancelled", state: "ended" },
      ],
      reached: 1,
    };
  }
  const reached = { pending: 0, approved: 1, completed: 2 }[status] ?? 0;
  const steps = ["Requested", "Approved", "Completed"].map((label, index) => ({
    label,
    state: index <= reached ? "done" : index === reached + 1 ? "next" : "todo",
  }));
  return { steps, reached };
}

const STEP_DOT = {
  done: "bg-primary text-white",
  next: "border-2 border-primary bg-surface text-primary",
  todo: "border border-border bg-surface text-ink-soft",
  ended: "bg-error text-white",
};

const STEP_LABEL = {
  done: "font-medium text-ink",
  next: "text-ink-soft",
  todo: "text-ink-soft",
  ended: "font-medium text-error",
};

function Stepper({ status }) {
  const { steps, reached } = progressSteps(status);
  return (
    <ol aria-label="Request progress" className="mt-4 flex items-center">
      {steps.map((step, index) => (
        <li
          key={step.label}
          aria-current={index === reached ? "step" : undefined}
          className={`flex items-center gap-2 ${index < steps.length - 1 ? "flex-1" : "flex-none"}`}
        >
          <span
            className={`flex h-6 w-6 flex-none items-center justify-center rounded-full text-xs font-medium ${STEP_DOT[step.state]}`}
          >
            {step.state === "done" && <Check size={13} weight="bold" aria-hidden="true" />}
            {step.state === "ended" && <X size={13} weight="bold" aria-hidden="true" />}
            {(step.state === "next" || step.state === "todo") && index + 1}
          </span>
          <span className={`text-xs sm:text-sm ${STEP_LABEL[step.state]}`}>{step.label}</span>
          {index < steps.length - 1 && (
            <span
              aria-hidden="true"
              className={`mx-1 h-px min-w-3 flex-1 ${index < reached ? "bg-primary" : "bg-border"}`}
            />
          )}
        </li>
      ))}
    </ol>
  );
}

function DemoCard({ demo, pet, cancelling, error, onCancel }) {
  const petName = demo.pet_name || demo.pet_breed || "Pet";
  const details = [demo.pet_breed, demo.pet_species].filter(Boolean).join(" · ");
  const meetLink = safeExternalUrl(demo.meet_link);
  const isActive = ACTIVE_STATUSES.includes(demo.status);
  const confirmedWhen = [
    demo.confirmed_date ? formatDate(demo.confirmed_date) : null,
    demo.confirmed_time ? formatTimeOfDay(demo.confirmed_time) : null,
  ]
    .filter(Boolean)
    .join(" at ");

  return (
    <article className="rounded-xl border border-border bg-surface p-4 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-2">
        <div className="min-w-0">
          <h3 className="text-[15px] font-medium text-ink">
            {pet ? (
              <Link to={`/pets/${pet.id}`} className="hover:text-primary hover:underline">
                {petName}
              </Link>
            ) : (
              petName
            )}
          </h3>
          {details && <p className="mt-0.5 text-sm text-ink-soft">{details}</p>}
          {demo.shop_name && <p className="mt-0.5 text-sm text-ink-soft">at {demo.shop_name}</p>}
        </div>
        <StatusBadge status={demo.status} />
      </div>

      <Stepper status={demo.status} />

      <dl className="mt-4 grid grid-cols-1 gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
        <div>
          <dt className="text-ink-soft">You asked for</dt>
          <dd className="text-ink">
            {formatDate(demo.preferred_date)}
            {demo.preferred_time && ` at ${formatTimeOfDay(demo.preferred_time)}`}
          </dd>
        </div>
        <div>
          <dt className="text-ink-soft">Format</dt>
          <dd className="text-ink">{MODE_LABELS[demo.mode] ?? demo.mode}</dd>
        </div>
        {confirmedWhen && (
          <div className="sm:col-span-2">
            <dt className="text-ink-soft">Confirmed for</dt>
            <dd className="font-medium text-ink">{confirmedWhen}</dd>
          </div>
        )}
      </dl>

      {demo.message && <p className="mt-3 break-words text-sm text-ink-soft">Your message: “{demo.message}”</p>}

      {demo.seller_note && (
        <div className="mt-3 rounded-lg bg-primary/5 px-3.5 py-3 text-sm">
          <p className="font-medium text-ink">Note from the shop</p>
          <p className="mt-0.5 whitespace-pre-line break-words text-ink-soft">{demo.seller_note}</p>
        </div>
      )}

      {demo.status === "approved" && demo.mode === "video" && (
        <div className="mt-4">
          {meetLink ? (
            <a
              href={meetLink}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:opacity-90"
            >
              <VideoCamera size={16} />
              Join video demo
            </a>
          ) : (
            <p className="text-sm text-ink-soft">The shop will add the video link here before your demo.</p>
          )}
        </div>
      )}

      {demo.status === "approved" && demo.mode === "in_person" && (
        <p className="mt-4 text-sm text-ink-soft">The shop will confirm the visit details with you.</p>
      )}

      {error && (
        <p role="alert" className="mt-3 text-sm text-error">
          {error}
        </p>
      )}

      <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-ink-soft">Requested {formatOrderDate(demo.created_at)}</p>
        {isActive && (
          <Button variant="outline" size="sm" onClick={() => onCancel(demo)} disabled={cancelling}>
            {cancelling ? "Cancelling…" : "Cancel request"}
          </Button>
        )}
      </div>
    </article>
  );
}

export function AccountDemos() {
  const userId = useAuthStore((state) => state.session?.user?.id);
  const { getPetById } = useCatalog();

  const [demos, setDemos] = useState(null);
  const [loadError, setLoadError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [filter, setFilter] = useState("all");
  const [cancellingId, setCancellingId] = useState(null);
  const [cancelError, setCancelError] = useState({ id: null, message: "" });

  useEffect(() => {
    if (!userId) return undefined;
    let cancelled = false;

    async function load() {
      const { data, error } = await supabase
        .from("demo_requests")
        .select(DEMO_COLUMNS)
        .eq("customer_id", userId)
        .order("created_at", { ascending: false });
      if (cancelled) return;
      if (error) setLoadError(error.message);
      else setDemos(data ?? []);
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [userId, reloadKey]);

  function retryLoad() {
    setLoadError("");
    setDemos(null);
    setReloadKey((key) => key + 1);
  }

  async function handleCancel(demo) {
    const petName = demo.pet_name || demo.pet_breed || "this pet";
    if (!window.confirm(`Cancel your demo request for ${petName}?`)) return;

    setCancellingId(demo.id);
    setCancelError({ id: null, message: "" });
    const { data, error } = await supabase
      .from("demo_requests")
      .update({ status: "cancelled" })
      .eq("id", demo.id)
      .select("id");
    setCancellingId(null);

    if (error) {
      setCancelError({ id: demo.id, message: error.message });
      return;
    }
    if (!data || data.length === 0) {
      // Nothing changed: the shop most likely just completed or rejected it, so show the latest.
      setCancelError({
        id: demo.id,
        message: "This request can't be cancelled any more. The shop may have just updated it.",
      });
      setReloadKey((key) => key + 1);
      return;
    }
    setDemos((current) =>
      current.map((candidate) => (candidate.id === demo.id ? { ...candidate, status: "cancelled" } : candidate)),
    );
  }

  const header = (
    <AccountPageHeader
      title="Demo requests"
      description="Follow the demos you've asked for, from request to confirmation. The shop confirms the meeting details with you."
    />
  );

  if (loadError) {
    return (
      <div>
        {header}
        <ErrorNote message={loadError} onRetry={retryLoad} />
      </div>
    );
  }

  if (!demos) {
    return (
      <div>
        {header}
        <LoadingNote />
      </div>
    );
  }

  if (demos.length === 0) {
    return (
      <div>
        {header}
        <EmptyState
          title="No demo requests yet"
          description="Ask for a video or in-person demo from any pet's page to meet them before you decide."
          action={
            <Button to="/pets" size="sm">
              Browse pets
            </Button>
          }
        />
      </div>
    );
  }

  const activeFilter = FILTERS.find((candidate) => candidate.id === filter) ?? FILTERS[0];
  const visibleDemos = demos.filter(activeFilter.matches);

  return (
    <div>
      {header}

      <div className="mt-6 flex flex-wrap gap-2" role="group" aria-label="Filter demo requests">
        {FILTERS.map((option) => {
          const selected = option.id === activeFilter.id;
          return (
            <button
              key={option.id}
              type="button"
              aria-pressed={selected}
              onClick={() => setFilter(option.id)}
              className={`rounded-full border px-4 py-1.5 text-sm transition-colors ${
                selected
                  ? "border-primary bg-primary font-medium text-white"
                  : "border-border bg-surface text-ink-soft hover:text-ink"
              }`}
            >
              {option.label}
              <span className={`ml-1.5 ${selected ? "text-white/80" : "text-ink-soft"}`}>
                {demos.filter(option.matches).length}
              </span>
            </button>
          );
        })}
      </div>

      {visibleDemos.length > 0 ? (
        <div className="mt-4 flex flex-col gap-3">
          {visibleDemos.map((demo) => (
            <DemoCard
              key={demo.id}
              demo={demo}
              pet={getPetById(demo.pet_id)}
              cancelling={cancellingId === demo.id}
              error={cancelError.id === demo.id ? cancelError.message : ""}
              onCancel={handleCancel}
            />
          ))}
        </div>
      ) : (
        <p className="mt-6 text-[15px] text-ink-soft">
          {activeFilter.id === "active" ? "No active demo requests right now." : "No past demo requests yet."}
        </p>
      )}
    </div>
  );
}
