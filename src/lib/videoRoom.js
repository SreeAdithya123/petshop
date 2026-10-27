/**
 * Video-call links for vet consultations and pet demos.
 *
 * Rooms are free Jitsi Meet rooms named after the booking/demo id, so each
 * booking gets its own unguessable room and both sides open the same link.
 * On the public meet.jit.si server the first person to join (the clinic or
 * shop) may be asked to sign in once; customers join without logging in.
 */
export function jitsiRoomUrl(id) {
  return `https://meet.jit.si/PETSTA-${String(id ?? "").replace(/-/g, "")}`;
}

/** True for a plain http(s) link with a host, safe to open in a new tab. */
export function isSafeWebLink(url) {
  try {
    const parsed = new URL(String(url ?? "").trim());
    return (parsed.protocol === "https:" || parsed.protocol === "http:") && Boolean(parsed.hostname);
  } catch {
    return false;
  }
}
