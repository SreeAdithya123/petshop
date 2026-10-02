import { formatDate } from "../../lib/format";
import { Button } from "../ui/Button";
import { StatusBadge } from "../ui/StatusBadge";
import { CustomerContact } from "./CustomerContact";
import { formatSlot, modeLabel } from "./helpers";
import { Meta, MetaList } from "./Meta";

const STATUS_LABELS = { pending: "Awaiting your response" };

export function DemoCard({ demo, customer, readOnly, onRespond }) {
  const petDetails = [demo.pet_breed, demo.pet_species].filter(Boolean).join(" · ");
  const canRespond = !readOnly && (demo.status === "pending" || demo.status === "approved");
  const confirmed = demo.confirmed_date || demo.confirmed_time;

  return (
    <article className="rounded-xl border border-border bg-surface p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[15px] font-medium text-ink">{demo.pet_name}</h3>
          <p className="text-sm text-ink-soft">
            {[petDetails, `Requested ${formatDate(demo.created_at)}`].filter(Boolean).join(" · ")}
          </p>
        </div>
        <StatusBadge status={demo.status} label={STATUS_LABELS[demo.status]} />
      </div>

      <MetaList className="mt-4">
        <Meta label="Customer">
          <CustomerContact profile={customer} />
        </Meta>
        <Meta label="Customer asked for">{formatSlot(demo.preferred_date, demo.preferred_time)}</Meta>
        <Meta label="How">{modeLabel(demo.mode)}</Meta>
        {confirmed && <Meta label="Confirmed for">{formatSlot(demo.confirmed_date, demo.confirmed_time)}</Meta>}
        {demo.meet_link && (
          <Meta label="Video link">
            <a href={demo.meet_link} target="_blank" rel="noreferrer" className="break-all text-primary hover:underline">
              {demo.meet_link}
            </a>
          </Meta>
        )}
      </MetaList>

      {demo.message && (
        <p className="mt-4 rounded-lg bg-paper px-3 py-2 text-sm text-ink">
          <span className="text-ink-soft">Customer message: </span>
          {demo.message}
        </p>
      )}
      {demo.seller_note && (
        <p className="mt-3 rounded-lg bg-paper px-3 py-2 text-sm text-ink">
          <span className="text-ink-soft">Your note: </span>
          {demo.seller_note}
        </p>
      )}

      {canRespond && (
        <div className="mt-4 border-t border-border pt-4">
          <Button
            type="button"
            variant={demo.status === "pending" ? "accent" : "outline"}
            size="sm"
            onClick={() => onRespond(demo)}
          >
            {demo.status === "pending" ? "Respond" : "Complete or update"}
          </Button>
        </div>
      )}
    </article>
  );
}
