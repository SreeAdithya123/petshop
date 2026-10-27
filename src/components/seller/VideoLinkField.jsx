import { ArrowCounterClockwise, ArrowSquareOut } from "@phosphor-icons/react";
import { fieldClassName } from "../../lib/styles";
import { isSafeWebLink, jitsiRoomUrl } from "../../lib/videoRoom";
import { Button } from "../ui/Button";

/**
 * Editable video-call link. It starts pre-filled with the free PETSTA room
 * (`jitsiRoomUrl(roomId)`) so confirming a booking or demo never needs a pasted
 * link; the shop can replace it with its own Meet/Zoom link, reset it, or open
 * it to try it. An empty field also means "use the PETSTA room" (see
 * `resolveVideoLink` in helpers.js). `error` is the validation message.
 */
export function VideoLinkField({ id, roomId, value, onChange, error, disabled = false, label = "Video call link" }) {
  const room = jitsiRoomUrl(roomId);
  const text = value.trim();
  const isRoom = text === room;
  const hintId = `${id}-hint`;
  const errorId = `${id}-error`;

  return (
    <div>
      <label htmlFor={id} className="block text-sm text-ink">
        {label}
      </label>
      <input
        id={id}
        type="url"
        inputMode="url"
        autoComplete="off"
        spellCheck={false}
        placeholder={room}
        value={value}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value)}
        aria-invalid={Boolean(error)}
        aria-describedby={error ? `${hintId} ${errorId}` : hintId}
        className={fieldClassName(Boolean(error))}
      />
      <p id={hintId} className="mt-1.5 text-xs text-ink-soft">
        A free PETSTA video room is ready. Leave it as is, or paste your own Meet/Zoom link. The customer sees it on
        their Services &amp; Health pages.
        {!text && " Left empty, the PETSTA room is used."}
      </p>
      {error && (
        <p id={errorId} className="mt-1.5 text-sm text-error">
          {error}
        </p>
      )}

      <div className="mt-2 flex flex-wrap items-center gap-2">
        {!isRoom && (
          <Button type="button" variant="ghost" size="sm" onClick={() => onChange(room)} disabled={disabled}>
            <ArrowCounterClockwise size={16} aria-hidden="true" />
            Use PETSTA room
          </Button>
        )}
        {isSafeWebLink(text) && !disabled ? (
          <a
            href={text}
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Open video call link (opens in a new tab)"
            className="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg border border-border px-4 py-2 text-sm font-medium text-ink transition-colors duration-150 hover:bg-primary/5"
          >
            Open
            <ArrowSquareOut size={16} aria-hidden="true" />
          </a>
        ) : (
          <Button type="button" variant="outline" size="sm" disabled>
            Open
            <ArrowSquareOut size={16} aria-hidden="true" />
          </Button>
        )}
      </div>
    </div>
  );
}
