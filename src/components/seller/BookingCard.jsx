import { useState } from "react";
import { formatDate, formatPrice } from "../../lib/format";
import { fieldClassName } from "../../lib/styles";
import { Button } from "../ui/Button";
import { StatusBadge } from "../ui/StatusBadge";
import { ConfirmModal } from "./ConfirmModal";
import { CustomerContact } from "./CustomerContact";
import { categoryLabel, formatSlot, isHttpsUrl, modeLabel } from "./helpers";
import { Meta, MetaList } from "./Meta";
import { updateRow } from "./mutations";
import { Notice } from "./Notice";

const LINK_ERROR = "Video links must start with https://";

export function BookingCard({ booking, customer, readOnly, onChanged }) {
  const [linkDraft, setLinkDraft] = useState(booking.video_room_url ?? "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [confirmingCancel, setConfirmingCancel] = useState(false);

  const isVideo = booking.delivery_mode === "video";
  const isOpen = booking.status === "pending" || booking.status === "confirmed";
  const canAct = !readOnly && isOpen;

  async function apply(patch, fromStatus) {
    setBusy(true);
    setError("");
    const message = await updateRow("service_bookings", booking.id, patch, fromStatus && { status: fromStatus });
    setBusy(false);
    if (message) setError(message);
    else onChanged();
  }

  function confirmBooking() {
    const link = linkDraft.trim();
    // A video link is optional here, but if one is typed it has to be usable.
    if (isVideo && link && !isHttpsUrl(link)) {
      setError(LINK_ERROR);
      return;
    }
    apply({ status: "confirmed", ...(isVideo && link ? { video_room_url: link } : {}) }, "pending");
  }

  function saveLink() {
    const link = linkDraft.trim();
    if (!isHttpsUrl(link)) {
      setError(LINK_ERROR);
      return;
    }
    apply({ video_room_url: link });
  }

  async function cancelBooking() {
    const message = await updateRow("service_bookings", booking.id, { status: "cancelled" });
    if (message) return message;
    setConfirmingCancel(false);
    onChanged();
    return null;
  }

  return (
    <article className="rounded-xl border border-border bg-surface p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[15px] font-medium text-ink">{booking.service_name}</h3>
          <p className="text-sm text-ink-soft">
            {[categoryLabel(booking.service_category), `Booked ${formatDate(booking.created_at)}`]
              .filter(Boolean)
              .join(" · ")}
          </p>
        </div>
        <StatusBadge status={booking.status} />
      </div>

      <MetaList className="mt-4">
        <Meta label="Customer">
          <CustomerContact profile={customer} />
        </Meta>
        <Meta label="When">{formatSlot(booking.booking_date, booking.booking_time)}</Meta>
        <Meta label="How">{modeLabel(booking.delivery_mode)}</Meta>
        <Meta label="Price">{formatPrice(booking.price_at_booking)}</Meta>
        {booking.video_room_url && !(canAct && isVideo) && (
          <Meta label="Video link">
            <a
              href={booking.video_room_url}
              target="_blank"
              rel="noreferrer"
              className="break-all text-primary hover:underline"
            >
              {booking.video_room_url}
            </a>
          </Meta>
        )}
      </MetaList>

      {booking.notes && (
        <p className="mt-4 rounded-lg bg-paper px-3 py-2 text-sm text-ink">
          <span className="text-ink-soft">Customer note: </span>
          {booking.notes}
        </p>
      )}

      {canAct && isVideo && (
        <div className="mt-4 rounded-lg bg-paper p-3">
          <label htmlFor={`video-link-${booking.id}`} className="block text-sm font-medium text-ink">
            Video link
          </label>
          <p className="mt-0.5 text-xs text-ink-soft">
            Paste a Google Meet/Zoom link; the customer sees it on their Services &amp; Health pages.
          </p>
          <div className="mt-2 flex flex-col gap-2 sm:flex-row">
            <input
              id={`video-link-${booking.id}`}
              type="url"
              inputMode="url"
              placeholder="https://meet.google.com/..."
              value={linkDraft}
              onChange={(event) => setLinkDraft(event.target.value)}
              className={`${fieldClassName(false)} mt-0! flex-1`}
            />
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={saveLink}
              disabled={busy || !linkDraft.trim() || linkDraft.trim() === (booking.video_room_url ?? "")}
            >
              Save link
            </Button>
          </div>
        </div>
      )}

      {error && (
        <Notice tone="error" className="mt-4">
          {error}
        </Notice>
      )}

      {canAct && (
        <div className="mt-4 flex flex-wrap gap-2 border-t border-border pt-4">
          {booking.status === "pending" && (
            <Button type="button" variant="accent" size="sm" onClick={confirmBooking} disabled={busy}>
              Confirm
            </Button>
          )}
          {booking.status === "confirmed" && (
            <Button
              type="button"
              variant="primary"
              size="sm"
              onClick={() => apply({ status: "completed" }, "confirmed")}
              disabled={busy}
            >
              Mark completed
            </Button>
          )}
          <Button type="button" variant="outline" size="sm" onClick={() => setConfirmingCancel(true)} disabled={busy}>
            Cancel booking
          </Button>
        </div>
      )}

      {confirmingCancel && (
        <ConfirmModal
          title="Cancel this booking?"
          description={`${booking.service_name} on ${formatSlot(
            booking.booking_date,
            booking.booking_time,
          )} will be marked as cancelled and the customer will see that.`}
          confirmLabel="Cancel booking"
          cancelLabel="Keep booking"
          destructive
          onConfirm={cancelBooking}
          onClose={() => setConfirmingCancel(false)}
        />
      )}
    </article>
  );
}
