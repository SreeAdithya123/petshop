import { supabase } from "./supabaseClient";

/**
 * Photo upload helpers for pet / product / service / shop listings.
 *
 * Files live in the public `listing-photos` bucket at
 * `<shop_id>/<kind>/<random>.<ext>`; only the owning shop (or an admin) can
 * write inside its own `<shop_id>` folder. The PUBLIC URL is what gets stored
 * in `photo_urls` / `banner_url`.
 */

export const MAX_LISTING_PHOTOS = 6;
export const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
export const LISTING_PHOTOS_BUCKET = "listing-photos";
export const LISTING_PHOTO_KINDS = ["pets", "products", "services", "shop"];

// Phone photos are often 5-12 MB, more than the bucket accepts. They are
// shrunk before upload, so MAX_PHOTO_BYTES is enforced on what is actually
// sent and the original only has to be a sane size to decode.
const MAX_SOURCE_BYTES = 30 * 1024 * 1024;

const MIME_BY_EXTENSION = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp" };
const EXTENSION_BY_MIME = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };
const PUBLIC_PATH_MARKER = `/storage/v1/object/public/${LISTING_PHOTOS_BUCKET}/`;
const MAX_MEGABYTES = Math.round(MAX_PHOTO_BYTES / (1024 * 1024));

function normalizeExtension(extension) {
  return String(extension ?? "")
    .trim()
    .replace(/^\./, "")
    .toLowerCase();
}

/** True for jpg / jpeg / png / webp, with or without a leading dot, any case. */
export function isAllowedPhotoExtension(extension) {
  return Object.hasOwn(MIME_BY_EXTENSION, normalizeExtension(extension));
}

/** "image/jpeg" etc. for an allowed extension, else null. */
export function mimeTypeForExtension(extension) {
  const normalized = normalizeExtension(extension);
  return Object.hasOwn(MIME_BY_EXTENSION, normalized) ? MIME_BY_EXTENSION[normalized] : null;
}

/** Lower-case extension of a file name without the dot, or "" when there is none. */
export function extensionOfFileName(name) {
  const text = String(name ?? "");
  const dot = text.lastIndexOf(".");
  return dot === -1 ? "" : text.slice(dot + 1).toLowerCase();
}

function randomHexId(length = 16) {
  const bytes = new Uint8Array(Math.ceil(length / 2));
  globalThis.crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, length);
}

/**
 * Object path for a new photo: `<shopId>/<kind>/<id>.<ext>`. `id` defaults to
 * 16 random hex characters; "jpeg" is normalised to "jpg".
 */
export function listingPhotoPath({ shopId, kind, extension, id }) {
  if (!shopId) throw new Error("A shop is needed to upload photos.");
  if (!LISTING_PHOTO_KINDS.includes(kind)) {
    throw new Error(`Unknown photo kind "${kind}". Use one of: ${LISTING_PHOTO_KINDS.join(", ")}.`);
  }
  const normalized = normalizeExtension(extension);
  if (!isAllowedPhotoExtension(normalized)) throw new Error("Use a JPEG, PNG or WebP image.");
  const objectId = id || randomHexId();
  if (!/^[A-Za-z0-9_-]+$/.test(objectId)) throw new Error("Invalid photo id.");
  return `${shopId}/${kind}/${objectId}.${normalized === "jpeg" ? "jpg" : normalized}`;
}

/**
 * The object path inside the listing-photos bucket for one of this project's
 * public URLs (query string stripped), or null for anything else, including
 * external image links. `supabaseUrl` is only overridable for testing.
 */
export function listingPhotoPathFromUrl(url, supabaseUrl = import.meta.env.VITE_SUPABASE_URL) {
  if (typeof url !== "string" || !url) return null;
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") return null;
  if (supabaseUrl) {
    try {
      if (new URL(supabaseUrl).origin !== parsed.origin) return null;
    } catch {
      return null;
    }
  }
  const at = parsed.pathname.indexOf(PUBLIC_PATH_MARKER);
  if (at === -1) return null;
  let path;
  try {
    path = decodeURIComponent(parsed.pathname.slice(at + PUBLIC_PATH_MARKER.length));
  } catch {
    return null;
  }
  if (!path || path.split("/").some((part) => part === "" || part === "..")) return null;
  return path;
}

/** Photos in `currentUrls` that the saved row does not have yet (uploaded or linked this session). */
export function unsavedPhotoUrls(savedUrls, currentUrls) {
  const saved = new Set(savedUrls ?? []);
  return (currentUrls ?? []).filter((url) => !saved.has(url));
}

/** Photos the saved row has that the edited list no longer includes. */
export function removedPhotoUrls(savedUrls, currentUrls) {
  const current = new Set(currentUrls ?? []);
  return (savedUrls ?? []).filter((url) => !current.has(url));
}

/**
 * Checks a pasted photo link. Resolves to `{ url }` (normalised) or
 * `{ error }`. Links into our own bucket are refused: they would let two
 * listings share one file, and deleting it from one would break the other.
 */
export function parsePhotoLink(input) {
  const text = String(input ?? "").trim();
  if (!text) return { error: "Paste a link to the photo." };
  let parsed;
  try {
    parsed = new URL(text);
  } catch {
    return { error: "That doesn't look like a link. Paste the full address, starting with https://." };
  }
  if (parsed.protocol !== "https:") return { error: "The link must start with https://." };
  if (!parsed.hostname.includes(".")) return { error: "That doesn't look like a link to a photo." };
  if (parsed.href.length > 2000) return { error: "That link is too long." };
  if (listingPhotoPathFromUrl(parsed.href)) {
    return { error: "That photo is already hosted here. Upload the file instead of linking to it." };
  }
  return { url: parsed.href };
}

/** A friendly message when `file` can't be uploaded, otherwise null. */
export function validatePhotoFile(file) {
  if (!file || typeof file.size !== "number") return "That file couldn't be read.";
  const extension = extensionOfFileName(file.name);
  const type = String(file.type ?? "").toLowerCase();
  const typeAllowed = type ? Object.hasOwn(EXTENSION_BY_MIME, type) : isAllowedPhotoExtension(extension);
  if (!typeAllowed) {
    if (/hei[cf]/.test(type) || /^hei[cf]$/.test(extension)) {
      return "HEIC photos aren't supported. Save it as a JPEG, PNG or WebP image first.";
    }
    return "Use a JPEG, PNG or WebP image.";
  }
  if (file.size === 0) return "That photo is empty.";
  if (file.size > MAX_SOURCE_BYTES) return `That photo is too large. Choose one under ${MAX_SOURCE_BYTES / (1024 * 1024)} MB.`;
  return null;
}

function replaceExtension(name, extension) {
  const base = String(name || "").replace(/\.[^./\\]+$/, "");
  return `${base || "photo"}.${extension}`;
}

function canvasToBlob(canvas, type, quality) {
  return new Promise((resolve) => canvas.toBlob(resolve, type, quality));
}

// Decodes with EXIF orientation applied. createImageBitmap is preferred; an
// <img> element is the fallback for browsers that reject its options.
async function decodeImage(file) {
  if (typeof createImageBitmap === "function") {
    try {
      const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
      return { source: bitmap, width: bitmap.width, height: bitmap.height, release: () => bitmap.close() };
    } catch {
      // fall through to the <img> path
    }
  }
  const objectUrl = URL.createObjectURL(file);
  try {
    const element = new Image();
    element.src = objectUrl;
    await element.decode();
    return {
      source: element,
      width: element.naturalWidth,
      height: element.naturalHeight,
      release: () => URL.revokeObjectURL(objectUrl),
    };
  } catch (error) {
    URL.revokeObjectURL(objectUrl);
    throw error;
  }
}

/**
 * Shrinks a photo so its longest side is at most `maxSize` pixels and
 * re-encodes it as JPEG (transparent areas become white). A photo that is
 * already small enough and within the size limit is returned untouched. If
 * anything goes wrong the original file is returned.
 */
export async function resizeImage(file, maxSize = 1600, quality = 0.85) {
  try {
    const image = await decodeImage(file);
    try {
      const longest = Math.max(image.width, image.height);
      if (!longest) return file;
      const needsShrink = longest > maxSize;
      if (!needsShrink && file.size <= MAX_PHOTO_BYTES) return file;

      const scale = needsShrink ? maxSize / longest : 1;
      const width = Math.max(1, Math.round(image.width * scale));
      const height = Math.max(1, Math.round(image.height * scale));
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const context = canvas.getContext("2d");
      if (!context) return file;
      context.fillStyle = "#ffffff";
      context.fillRect(0, 0, width, height);
      context.imageSmoothingQuality = "high";
      context.drawImage(image.source, 0, 0, width, height);

      const blob = await canvasToBlob(canvas, "image/jpeg", quality);
      if (!blob) return file;
      return new File([blob], replaceExtension(file.name, "jpg"), { type: "image/jpeg", lastModified: Date.now() });
    } finally {
      image.release();
    }
  } catch {
    return file;
  }
}

function storageErrorMessage(error) {
  const message = String(error?.message ?? "");
  if (/row-level security|unauthorized|not authorized|permission denied/i.test(message)) {
    return "You can only upload photos for your own shop.";
  }
  if (/maximum allowed size|payload too large|exceeded the maximum/i.test(message)) {
    return `That photo is too large. The limit is ${MAX_MEGABYTES} MB.`;
  }
  if (/mime type|not supported|invalid mime/i.test(message)) return "Use a JPEG, PNG or WebP image.";
  if (/failed to fetch|network|load failed/i.test(message)) {
    return "Couldn't reach the server. Check your connection and try again.";
  }
  return message || "The upload failed. Please try again.";
}

/**
 * Validates, shrinks and uploads one photo for a shop, then resolves to its
 * public URL. Throws an Error with a message that is safe to show.
 */
export async function uploadListingPhoto({ shopId, kind, file }) {
  if (!shopId) throw new Error("Your shop isn't ready yet, so photos can't be uploaded.");
  if (!LISTING_PHOTO_KINDS.includes(kind)) throw new Error(`Unknown photo kind "${kind}".`);
  const problem = validatePhotoFile(file);
  if (problem) throw new Error(problem);

  const prepared = await resizeImage(file);
  if (prepared.size > MAX_PHOTO_BYTES) {
    throw new Error(`That photo is still over ${MAX_MEGABYTES} MB after shrinking it. Choose a smaller image.`);
  }

  const preparedType = String(prepared.type ?? "").toLowerCase();
  const contentType = Object.hasOwn(EXTENSION_BY_MIME, preparedType)
    ? preparedType
    : mimeTypeForExtension(extensionOfFileName(file.name));
  if (!contentType) throw new Error("Use a JPEG, PNG or WebP image.");

  const path = listingPhotoPath({ shopId, kind, extension: EXTENSION_BY_MIME[contentType] });
  // The storage client reads the content type from the Blob itself.
  const body = prepared.type === contentType ? prepared : new Blob([prepared], { type: contentType });

  let uploadError = null;
  try {
    const { error } = await supabase.storage
      .from(LISTING_PHOTOS_BUCKET)
      .upload(path, body, { contentType, upsert: false, cacheControl: "31536000" });
    uploadError = error;
  } catch (error) {
    uploadError = error;
  }
  if (uploadError) throw new Error(storageErrorMessage(uploadError));

  const { data } = supabase.storage.from(LISTING_PHOTOS_BUCKET).getPublicUrl(path);
  return data.publicUrl;
}

/**
 * Best-effort removal of listing photos from storage. Only URLs that point
 * into the listing-photos bucket are touched (external links are ignored),
 * and failures are swallowed: a leftover file is harmless, a thrown error
 * mid-save is not. Resolves to true when something was removed.
 */
export async function deleteListingPhotosByUrls(urls) {
  const paths = [...new Set((urls ?? []).map((url) => listingPhotoPathFromUrl(url)).filter(Boolean))];
  if (paths.length === 0) return false;
  try {
    const { error } = await supabase.storage.from(LISTING_PHOTOS_BUCKET).remove(paths);
    return !error;
  } catch {
    return false;
  }
}

/** Best-effort removal of a single listing photo; see deleteListingPhotosByUrls. */
export async function deleteListingPhotoByUrl(url) {
  return deleteListingPhotosByUrls([url]);
}
