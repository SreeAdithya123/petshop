import { CalendarBlank, VideoCamera } from "@phosphor-icons/react";
import { formatDate, formatPrice } from "../../lib/format";
import { StatusBadge } from "../ui/StatusBadge";
import { ConfirmButton } from "./ConfirmButton";
import { ListState } from "./ListState";
import { DELIVERY_MODES, formatTime, safeExternalUrl } from "./serviceCategories";

function BookingRow({ booking, busy, onCancel }) {
  const mode = DELIVERY_MODES[booking.delivery_mode] ?? DELIVERY_MODES.in_person;
  const ModeIcon = mode.icon;
  const canCancel = booking.status === "pending" || booking.status === "confirmed";
  const videoUrl = booking.status === "confirmed" ? safeExternalUrl(booking.video_room_url) : null;

  return (
    <li className="flex flex-col gap-4 rounded-xl border border-border bg-surface p-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="text-[15px] font-medium text-ink">{booking.service_name || "Service"}</h3>
          <StatusBadge status={booking.status} />
        </div>
        {booking.shop_name && <p className="mt-0.5 text-sm text-ink-soft">by {booking.shop_name}</p>}
        <p className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-ink-soft">
          <span className="inline-flex items-center gap-1.5">
            <CalendarBlank size={16} aria-hidden="true" />
            {formatDate(booking.booking_date)} at {formatTime(booking.booking_time)}
          </span>
          <span className="inline-flex items-center gap-1.5">
            <ModeIcon size={16} aria-hidden="true" />
            {mode.label}
          </span>
          {booking.price_at_booking != null && (
            <span className="font-medium text-ink">{formatPrice(booking.price_at_booking)}</span>
          )}
        </p>
        {booking.notes && <p className="mt-2 line-clamp-2 text-sm text-ink-soft">{booking.notes}</p>}
        {booking.status === "confirmed" && booking.delivery_mode === "video" && !videoUrl && (
          <p className="mt-2 text-sm text-ink-soft">The clinic hasn't added a video link yet — check back soon.</p>
        )}
      </div>

      <div className="flex flex-wrap items-center gap-2 sm:justify-end">
        {videoUrl && (
          <a
            href={videoUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:opacity-90"
          >
            <VideoCamera size={16} aria-hidden="true" /> Join video consult
          </a>
        )}
        {canCancel && (
          <ConfirmButton
            label="Cancel"
            confirmLabel="Yes, cancel"
            prompt="Cancel this booking?"
            busy={busy}
            onConfirm={() => onCancel(booking.id)}
          />
        )}
      </div>
    </li>
  );
}

/** Own service bookings with status, join link and cancel. State comes from useServiceBookings. */
export function BookingList({ state, emptyMessage = "No bookings yet." }) {
  const { bookings, loading, error, reload, cancelBooking, busyId, actionError } = state;

  return (
    <ListState
      loading={loading}
      error={error}
      onRetry={reload}
      isEmpty={bookings.length === 0}
      emptyMessage={emptyMessage}
    >
      {actionError && (
        <p role="alert" className="mb-3 text-sm text-error">
          {actionError}
        </p>
      )}
      <ul className="space-y-3">
        {bookings.map((booking) => (
          <BookingRow
            key={booking.id}
            booking={booking}
            busy={busyId === booking.id}
            onCancel={cancelBooking}
          />
        ))}
      </ul>
    </ListState>
  );
}
