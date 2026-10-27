import { useRef, useState } from "react";
import { formatDate, formatPrice } from "../../lib/format";
import { jitsiRoomUrl } from "../../lib/videoRoom";
import { Button } from "../ui/Button";
import { StatusBadge } from "../ui/StatusBadge";
import { ConfirmModal } from "./ConfirmModal";
import { CustomerContact } from "./CustomerContact";
import { categoryLabel, formatSlot, modeLabel, resolveVideoLink } from "./helpers";
import { Meta, MetaList } from "./Meta";
import { NOTHING_CHANGED, updateRow } from "./mutations";
import { Notice } from "./Notice";
import { VideoLink } from "./VideoLink";
import { VideoLinkField } from "./VideoLinkField";

/**
 * One customer booking of this shop's service, with Confirm / Mark completed /
 * Cancel and the video-link field. A video booking gets a free PETSTA video room
 * by default, so confirming never needs a pasted link.
 */
export function BookingCard({ booking, customer, readOnly, onChanged }) {
  const savedLink = (booking.video_room_url ?? "").trim();
  const [linkDraft, setLinkDraft] = useState(savedLink || jitsiRoomUrl(booking.id));
  const [busyAction, setBusyAction] = useState(null);
  const [error, setError] = useState("");
  const [linkError, setLinkError] = useState("");
  const [confirmingCancel, setConfirmingCancel] = useState(false);
  const inFlight = useRef(false);

  const isVideo = booking.delivery_mode === "video";
  const isOpen = booking.status === "pending" || booking.status === "confirmed";
  const canAct = !readOnly && isOpen;
  const editingLink = canAct && isVideo;
  const busy = busyAction !== null;

  /** Saves `patch` while the booking is still in `fromStatus`; resolves to true on success. */
  async function apply(action, patch, fromStatus) {
    if (inFlight.current) return false;
    inFlight.current = true;
    setBusyAction(action);
    setError("");
    setLinkError("");
    const message = await updateRow("service_bookings", booking.id, patch, { status: fromStatus });
    inFlight.current = false;
    setBusyAction(null);
    if (message) setError(message);
    // After a stale-status refusal the list reloads too, so the card shows the real state.
    if (!message || message === NOTHING_CHANGED) onChanged();
    return !message;
  }

  async function confirmBooking() {
    const patch = { status: "confirmed" };
    let resolvedLink = null;
    if (isVideo) {
      // An empty field means the free PETSTA room; a typed link must be https.
      const resolved = resolveVideoLink(linkDraft, booking.id);
      if (resolved.error) {
        setLinkError(resolved.error);
        return;
      }
      resolvedLink = resolved.link;
      patch.video_room_url = resolvedLink;
    }
    const saved = await apply("confirm", patch, "pending");
    if (saved && resolvedLink) setLinkDraft(resolvedLink);
  }

  async function saveLink() {
    const resolved = resolveVideoLink(linkDraft, booking.id);
    if (resolved.error) {
      setLinkError(resolved.error);
      return;
    }
    const saved = await apply("link", { video_room_url: resolved.link }, booking.status);
    if (saved) setLinkDraft(resolved.link);
  }

  async function cancelBooking() {
    if (inFlight.current) return "Another update is still being saved. Please wait a moment.";
    inFlight.current = true;
    setBusyAction("cancel");
    const message = await updateRow("service_bookings", booking.id, { status: "cancelled" }, { status: booking.status });
    inFlight.current = false;
    setBusyAction(null);
    if (message) {
      if (message === NOTHING_CHANGED) onChanged();
      return message;
    }
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
        {savedLink && !editingLink && (
          <Meta label="Video link">
            <VideoLink url={savedLink} />
          </Meta>
        )}
      </MetaList>

      {booking.notes && (
        <p className="mt-4 rounded-lg bg-paper px-3 py-2 text-sm text-ink">
          <span className="text-ink-soft">Customer note: </span>
          {booking.notes}
        </p>
      )}

      {editingLink && (
        <div className="mt-4 rounded-lg bg-paper p-3">
          <VideoLinkField
            id={`video-link-${booking.id}`}
            roomId={booking.id}
            value={linkDraft}
            onChange={(next) => {
              setLinkDraft(next);
              setLinkError("");
            }}
            error={linkError}
            disabled={busy}
          />
          {booking.status === "confirmed" ? (
            <div className="mt-3 flex justify-end">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={saveLink}
                disabled={busy || linkDraft.trim() === savedLink}
              >
                {busyAction === "link" ? "Saving…" : "Save link"}
              </Button>
            </div>
          ) : (
            <p className="mt-2 text-xs text-ink-soft">The link is saved when you confirm the booking.</p>
          )}
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
              {busyAction === "confirm" ? "Confirming…" : "Confirm"}
            </Button>
          )}
          {booking.status === "confirmed" && (
            <Button
              type="button"
              variant="primary"
              size="sm"
              onClick={() => apply("complete", { status: "completed" }, "confirmed")}
              disabled={busy}
            >
              {busyAction === "complete" ? "Saving…" : "Mark completed"}
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
