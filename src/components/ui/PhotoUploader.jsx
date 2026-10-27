import { CircleNotch, ImageBroken, Link as LinkIcon, Plus, X } from "@phosphor-icons/react";
import { useEffect, useId, useRef, useState } from "react";
import {
  MAX_LISTING_PHOTOS,
  MAX_PHOTO_BYTES,
  deleteListingPhotoByUrl,
  parsePhotoLink,
  uploadListingPhoto,
} from "../../lib/listingPhotos";
import { fieldClassName } from "../../lib/styles";
import { Button } from "./Button";

const NO_URLS = [];
const ACCEPT = "image/jpeg,image/png,image/webp";
const MAX_MEGABYTES = Math.round(MAX_PHOTO_BYTES / (1024 * 1024));

/** One photo, or a quiet placeholder if the URL no longer loads. */
function Thumb({ src, alt }) {
  const [failed, setFailed] = useState(false);
  if (failed) {
    return (
      <div className="flex h-full w-full flex-col items-center justify-center gap-1 px-2 text-center text-xs text-ink-soft">
        <ImageBroken size={24} aria-hidden="true" />
        <span>Can't load this photo</span>
      </div>
    );
  }
  return (
    <img
      src={src}
      alt={alt}
      draggable={false}
      decoding="async"
      onError={() => setFailed(true)}
      className="h-full w-full object-cover"
    />
  );
}

/** Dashed "Add photo" button that also accepts dropped files. */
function AddTile({ onPick, onDropFiles, disabled, text }) {
  return (
    <button
      type="button"
      onClick={onPick}
      disabled={disabled}
      onDragOver={(event) => {
        if (!disabled) event.preventDefault();
      }}
      onDrop={(event) => {
        event.preventDefault();
        if (!disabled) onDropFiles(Array.from(event.dataTransfer.files));
      }}
      className="flex h-full w-full flex-col items-center justify-center gap-1.5 rounded-lg border-2 border-dashed border-border bg-surface px-2 text-center text-sm font-medium text-ink-soft transition-colors hover:border-primary hover:text-primary disabled:pointer-events-none disabled:opacity-50"
    >
      <Plus size={22} aria-hidden="true" />
      {text}
    </button>
  );
}

/**
 * Photo picker for seller forms. It is controlled: `urls` is the list the form
 * will save, `onChange(nextUrls)` reports every change. Files are shrunk and
 * uploaded to the listing-photos bucket as soon as they are picked; a link can
 * be pasted instead. The first photo is the cover.
 *
 * - `savedUrls`: what the saved row already holds. A photo uploaded in this
 *   form and removed again before saving is deleted from storage right away;
 *   anything in `savedUrls` is left for the page to clean up after a save.
 * - `onBusyChange(bool)`: true while uploads run, so the page can hold back
 *   its Save button (a photo still uploading would be lost).
 * - `single`: one photo only (the shop banner); a new pick replaces the old.
 */
export function PhotoUploader({
  shopId,
  kind,
  urls = NO_URLS,
  onChange,
  max = MAX_LISTING_PHOTOS,
  single = false,
  label,
  hint,
  disabled = false,
  savedUrls = NO_URLS,
  onBusyChange,
}) {
  const limit = single ? 1 : Math.max(1, Math.min(max, MAX_LISTING_PHOTOS));
  const title = label ?? (single ? "Photo" : "Photos");
  const baseId = useId();
  const labelId = `${baseId}-label`;
  const hintId = `${baseId}-hint`;
  const linkPanelId = `${baseId}-link-panel`;
  const linkInputId = `${baseId}-link`;
  const linkErrorId = `${baseId}-link-error`;

  const [pending, setPending] = useState([]); // files waiting to upload; the first is in flight
  const [problems, setProblems] = useState([]);
  const [linkOpen, setLinkOpen] = useState(false);
  const [linkValue, setLinkValue] = useState("");
  const [linkError, setLinkError] = useState("");

  const inputRef = useRef(null);
  const mountedRef = useRef(true);
  const runningRef = useRef(false);
  const uploadedRef = useRef(new Set()); // URLs uploaded by this instance
  const urlsRef = useRef(urls);
  const savedRef = useRef(savedUrls);
  const onChangeRef = useRef(onChange);
  const onBusyRef = useRef(onBusyChange);

  // Async upload callbacks must see the latest props, not the ones they closed over.
  useEffect(() => {
    urlsRef.current = urls;
    savedRef.current = savedUrls;
    onChangeRef.current = onChange;
    onBusyRef.current = onBusyChange;
  });

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      onBusyRef.current?.(false);
    };
  }, []);

  const busy = pending.length > 0;
  useEffect(() => {
    onBusyRef.current?.(busy);
  }, [busy]);

  const locked = disabled || !shopId;
  const full = !single && urls.length + pending.length >= limit;
  const defaultHint = !shopId
    ? "Photos can be added once your shop has loaded."
    : single
      ? `JPEG, PNG or WebP, up to ${MAX_MEGABYTES} MB. Large photos are shrunk for you.`
      : `Up to ${limit} photos; the first is the cover. JPEG, PNG or WebP, up to ${MAX_MEGABYTES} MB each. Large photos are shrunk for you.`;

  function emit(next) {
    urlsRef.current = next;
    onChangeRef.current?.(next);
  }

  // A photo this form uploaded that no saved listing references can go now.
  function releaseUrl(url) {
    if (uploadedRef.current.delete(url) && !savedRef.current.includes(url)) {
      deleteListingPhotoByUrl(url);
    }
  }

  function openPicker() {
    inputRef.current?.click();
  }

  async function addFiles(files) {
    if (files.length === 0 || locked || runningRef.current) return;

    const room = single ? 1 : limit - urlsRef.current.length;
    if (room <= 0) {
      setProblems([`You can add up to ${limit} photos. Remove one to add another.`]);
      return;
    }

    const batch = files.slice(0, room);
    const notes = [];
    if (files.length > batch.length) {
      notes.push(
        single
          ? "Only one photo can be used here, so the extra files were skipped."
          : `Only ${room} more ${room === 1 ? "photo fits" : "photos fit"} (up to ${limit}), so the extra files were skipped.`,
      );
    }

    runningRef.current = true;
    setProblems([]);
    setPending(batch.map((file, index) => ({ key: `${index}-${file.name}-${file.size}`, name: file.name })));

    for (const file of batch) {
      try {
        const url = await uploadListingPhoto({ shopId, kind, file });
        if (!mountedRef.current) {
          // The form was closed while this was uploading: nothing will ever reference it.
          deleteListingPhotoByUrl(url);
          break;
        }
        uploadedRef.current.add(url);
        if (single) {
          const previous = urlsRef.current[0];
          emit([url]);
          if (previous) releaseUrl(previous);
        } else {
          emit([...urlsRef.current, url]);
        }
      } catch (error) {
        notes.push(`${file.name}: ${error.message || "The upload failed."}`);
      }
      if (mountedRef.current) setPending((current) => current.slice(1));
    }

    runningRef.current = false;
    if (mountedRef.current) {
      setPending([]);
      setProblems(notes);
    }
  }

  function handleInputChange(event) {
    // Copy before clearing: resetting the input empties the live FileList.
    const files = Array.from(event.target.files ?? []);
    event.target.value = "";
    addFiles(files);
  }

  function removeUrl(url) {
    setProblems([]);
    emit(urlsRef.current.filter((item) => item !== url));
    releaseUrl(url);
  }

  function makeCover(url) {
    emit([url, ...urlsRef.current.filter((item) => item !== url)]);
  }

  function addLink() {
    const result = parsePhotoLink(linkValue);
    if (result.error) {
      setLinkError(result.error);
      return;
    }
    if (urlsRef.current.includes(result.url)) {
      setLinkError("That photo is already added.");
      return;
    }
    if (!single && urlsRef.current.length + pending.length >= limit) {
      setLinkError(`You can add up to ${limit} photos. Remove one first.`);
      return;
    }
    const previous = single ? urlsRef.current[0] : null;
    emit(single ? [result.url] : [...urlsRef.current, result.url]);
    if (previous) releaseUrl(previous);
    setProblems([]);
    setLinkValue("");
    setLinkError("");
    if (single) setLinkOpen(false);
  }

  const spinner = (text) => (
    <>
      <CircleNotch size={22} className="animate-spin text-primary" aria-hidden="true" />
      <span className="max-w-full truncate">{text}</span>
    </>
  );

  return (
    <div role="group" aria-labelledby={labelId} aria-describedby={hintId}>
      <p id={labelId} className="text-sm text-ink">
        {title}
      </p>

      <input
        ref={inputRef}
        type="file"
        accept={ACCEPT}
        multiple={!single}
        tabIndex={-1}
        aria-hidden="true"
        onChange={handleInputChange}
        className="sr-only"
      />

      {single ? (
        <div className="mt-1.5 max-w-md">
          <div className="relative aspect-[16/7] overflow-hidden rounded-lg border border-border bg-paper">
            {urls[0] ? (
              <Thumb key={urls[0]} src={urls[0]} alt={title} />
            ) : (
              <AddTile onPick={openPicker} onDropFiles={addFiles} disabled={locked || busy} text="Add photo" />
            )}
            {busy && (
              <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-surface/85 px-2 text-sm text-ink-soft">
                {spinner("Uploading…")}
              </div>
            )}
          </div>
          {urls[0] && (
            <div className="mt-2 flex flex-wrap gap-2">
              <Button type="button" variant="outline" size="sm" disabled={locked || busy} onClick={openPicker}>
                Replace photo
              </Button>
              <Button type="button" variant="ghost" size="sm" disabled={locked || busy} onClick={() => removeUrl(urls[0])}>
                Remove
              </Button>
            </div>
          )}
        </div>
      ) : (
        <ul className="mt-1.5 grid grid-cols-2 gap-3 xs:grid-cols-3 sm:grid-cols-4">
          {urls.map((url, index) => (
            <li key={url} className="relative aspect-square overflow-hidden rounded-lg border border-border bg-paper">
              <Thumb src={url} alt={index === 0 ? "Cover photo" : `Photo ${index + 1}`} />
              {index === 0 && (
                <span className="absolute left-1.5 top-1.5 rounded-full bg-ink/75 px-2 py-0.5 text-[11px] font-medium text-white">
                  Cover
                </span>
              )}
              <button
                type="button"
                disabled={disabled}
                onClick={() => removeUrl(url)}
                aria-label={index === 0 ? "Remove cover photo" : `Remove photo ${index + 1}`}
                className="absolute right-1.5 top-1.5 flex h-8 w-8 items-center justify-center rounded-full bg-ink/75 text-white transition-colors hover:bg-ink disabled:pointer-events-none disabled:opacity-50"
              >
                <X size={16} weight="bold" aria-hidden="true" />
              </button>
              {index > 0 && (
                <button
                  type="button"
                  disabled={disabled}
                  onClick={() => makeCover(url)}
                  aria-label={`Make cover, photo ${index + 1}`}
                  className="absolute inset-x-0 bottom-0 bg-ink/70 py-1.5 text-xs font-medium text-white transition-colors hover:bg-ink disabled:pointer-events-none disabled:opacity-50"
                >
                  Make cover
                </button>
              )}
            </li>
          ))}
          {pending.map((item, index) => (
            <li
              key={item.key}
              className="flex aspect-square flex-col items-center justify-center gap-2 rounded-lg border border-border bg-paper px-2 text-center text-xs text-ink-soft"
            >
              {spinner(index === 0 ? "Uploading…" : "Queued")}
            </li>
          ))}
          {!full && (
            <li className="aspect-square">
              <AddTile onPick={openPicker} onDropFiles={addFiles} disabled={locked || busy} text="Add photo" />
            </li>
          )}
        </ul>
      )}

      <p className="sr-only" aria-live="polite">
        {busy ? "Uploading photos" : ""}
      </p>

      <p id={hintId} className="mt-2 text-xs text-ink-soft">
        {hint ?? defaultHint}
      </p>

      {problems.length > 0 && (
        <div role="alert" className="mt-2 flex flex-col gap-1">
          {problems.map((message, index) => (
            <p key={`${index}-${message}`} className="text-sm text-error">
              {message}
            </p>
          ))}
        </div>
      )}

      <div className="mt-3">
        <button
          type="button"
          onClick={() => setLinkOpen((open) => !open)}
          disabled={locked || busy}
          aria-expanded={linkOpen}
          aria-controls={linkPanelId}
          className="inline-flex items-center gap-1.5 text-sm text-primary hover:underline disabled:pointer-events-none disabled:opacity-50"
        >
          <LinkIcon size={16} aria-hidden="true" />
          {linkOpen ? "Hide link option" : "Add by link instead"}
        </button>

        {linkOpen && (
          <div id={linkPanelId} className="mt-2">
            <label htmlFor={linkInputId} className="block text-sm text-ink">
              Photo link
            </label>
            <input
              id={linkInputId}
              type="url"
              inputMode="url"
              autoComplete="off"
              placeholder="https://example.com/photo.jpg"
              value={linkValue}
              disabled={locked || busy}
              onChange={(event) => {
                setLinkValue(event.target.value);
                setLinkError("");
              }}
              onKeyDown={(event) => {
                // Enter must add the link, not submit the form this sits in.
                if (event.key === "Enter") {
                  event.preventDefault();
                  addLink();
                }
              }}
              aria-invalid={Boolean(linkError)}
              aria-describedby={linkError ? linkErrorId : undefined}
              className={fieldClassName(Boolean(linkError))}
            />
            {linkError && (
              <p id={linkErrorId} role="alert" className="mt-1.5 text-sm text-error">
                {linkError}
              </p>
            )}
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={locked || busy}
              onClick={addLink}
              className="mt-2"
            >
              Add this link
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
