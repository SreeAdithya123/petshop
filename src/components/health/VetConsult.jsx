import { Clock, Stethoscope, VideoCamera } from "@phosphor-icons/react";
import { useState } from "react";
import { formatPrice } from "../../lib/format";
import { BookingList } from "../services/BookingList";
import { BookingModal } from "../services/BookingModal";
import { formatDuration } from "../services/serviceCategories";
import { useApprovedServices } from "../services/useApprovedServices";
import { useBookingAccess } from "../services/useBookingAccess";
import { useHashScroll } from "../services/useHashScroll";
import { useServiceBookings } from "../services/useServiceBookings";
import { Button } from "../ui/Button";
import { EmptyState } from "../ui/EmptyState";
import { LoginPrompt } from "../ui/LoginPrompt";

const FLOW = [
  { title: "Book a slot", text: "Pick a vet, a date and a time that suits you." },
  { title: "Clinic confirms", text: "The clinic confirms your slot and shares a video link in your booking." },
  { title: "Join from here", text: "At your slot time, open My consultations below and tap Join video consult." },
];

function VetRow({ service, onBook }) {
  const duration = formatDuration(service.duration_minutes);

  return (
    <li className="rounded-xl border border-border bg-surface p-4">
      <div className="flex items-start gap-3">
        <span className="flex h-11 w-11 flex-none items-center justify-center rounded-full bg-primary/10 text-primary">
          <Stethoscope size={22} weight="duotone" aria-hidden="true" />
        </span>
        <div className="min-w-0 flex-1">
          {service.shops?.name && <p className="truncate text-sm text-ink-soft">{service.shops.name}</p>}
          <h3 className="text-[15px] font-medium text-ink">{service.name}</h3>
          {service.description && <p className="mt-1 line-clamp-3 text-sm text-ink-soft">{service.description}</p>}
        </div>
        <p className="flex-none font-display text-lg font-semibold text-accent">{formatPrice(service.price)}</p>
      </div>
      <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
        <span className="inline-flex items-center gap-1 text-xs text-ink-soft">
          {duration && (
            <>
              <Clock size={14} aria-hidden="true" /> {duration}
            </>
          )}
        </span>
        <Button size="sm" onClick={() => onBook(service)}>
          <VideoCamera size={16} aria-hidden="true" /> Book video consult
        </Button>
      </div>
    </li>
  );
}

/** The vet teleconsultation flow: how it works, bookable vets, and the customer's own consultations. */
export function VetConsult() {
  const access = useBookingAccess();
  const { services, loading, error, reload } = useApprovedServices({ category: "vet" });
  const consultations = useServiceBookings({
    userId: access.canBook ? access.userId : null,
    category: "vet",
  });
  const [active, setActive] = useState(null);

  // The page anchors (#vet, #pharmacy, #consultations) sit below content that
  // loads asynchronously, so wait for it before scrolling to them.
  useHashScroll(!loading && access.status !== "loading");

  function viewConsultations() {
    setActive(null);
    // Wait a tick so the modal's scroll lock is released first.
    setTimeout(
      () => document.getElementById("consultations")?.scrollIntoView({ behavior: "smooth", block: "start" }),
      0,
    );
  }

  // Sellers and admins don't book consultations, so they don't get the list.
  const showMyConsultations = access.status !== "loading" && (!access.session || access.canBook);

  return (
    <div>
      <ol className="grid gap-3 sm:grid-cols-3">
        {FLOW.map((step, index) => (
          <li key={step.title} className="rounded-xl border border-border bg-surface p-4">
            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary text-sm font-semibold text-white">
              {index + 1}
            </span>
            <p className="mt-2 text-sm font-medium text-ink">{step.title}</p>
            <p className="mt-1 text-sm text-ink-soft">{step.text}</p>
          </li>
        ))}
      </ol>
      <p className="mt-3 text-xs text-ink-soft">
        Video links are provided by the clinic. PETSTA doesn't host the calls itself.
      </p>

      <div className="mt-6">
        {loading ? (
          <div role="status" aria-label="Loading vets" className="space-y-3">
            <div className="h-32 animate-pulse rounded-xl bg-ink/5" />
            <div className="h-32 animate-pulse rounded-xl bg-ink/5" />
          </div>
        ) : error ? (
          <div role="alert" className="rounded-xl border border-error/30 bg-error/5 p-5 text-sm text-error">
            <p>Couldn't load vets: {error}</p>
            <Button variant="outline" size="sm" className="mt-3" onClick={reload}>
              Try again
            </Button>
          </div>
        ) : services.length === 0 ? (
          <EmptyState
            title="No vet consultations yet"
            description="No vet has listed a teleconsultation so far. Send a custom request and nearby vets can reply with a quote."
            action={
              <Button to="/services#custom" size="sm">
                Request a custom service
              </Button>
            }
          />
        ) : (
          <ul className="space-y-3">
            {services.map((service) => (
              <VetRow key={service.id} service={service} onBook={setActive} />
            ))}
          </ul>
        )}
      </div>

      {showMyConsultations && (
        <div id="consultations" className="mt-10 scroll-mt-24">
          <h3 className="font-display text-xl font-semibold text-ink">My consultations</h3>
          <div className="mt-4">
            {access.canBook ? (
              <BookingList state={consultations} emptyMessage="No consultations yet. Book a vet above to get started." />
            ) : (
              <div className="rounded-xl border border-border bg-surface p-5">
                <LoginPrompt compact description="to see your consultations and join video calls." />
              </div>
            )}
          </div>
        </div>
      )}

      {active && (
        <BookingModal
          consult
          service={active}
          onClose={() => setActive(null)}
          onBooked={consultations.reload}
          onViewMine={viewConsultations}
          viewMineLabel="View my consultations"
        />
      )}
    </div>
  );
}
