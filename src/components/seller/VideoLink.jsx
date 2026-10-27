import { ArrowSquareOut } from "@phosphor-icons/react";
import { isSafeWebLink } from "../../lib/videoRoom";

/**
 * A saved video-call link with an "Open" link beside it. Only http(s) links are
 * made clickable; anything else (stored text is not trusted) shows as plain text.
 */
export function VideoLink({ url }) {
  if (!isSafeWebLink(url)) return <span className="break-all">{url}</span>;

  return (
    <span className="inline-flex flex-wrap items-center gap-x-3 gap-y-1">
      <span className="break-all text-ink-soft">{url}</span>
      <a
        href={url}
        target="_blank"
        rel="noopener noreferrer"
        aria-label="Open video call link (opens in a new tab)"
        className="inline-flex items-center gap-1 font-medium text-primary hover:underline"
      >
        Open
        <ArrowSquareOut size={14} aria-hidden="true" />
      </a>
    </span>
  );
}
