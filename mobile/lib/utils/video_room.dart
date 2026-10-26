/// Video-call links for vet consultations and pet demos.
///
/// Rooms are free Jitsi Meet rooms named after the booking/demo id, so each
/// booking gets its own unguessable room and both sides open the same link.
/// Note: on the public meet.jit.si server the first person to join (the
/// clinic/shop) may be asked to sign in once; customers join without logging in.
String jitsiRoomUrl(String bookingId) => 'https://meet.jit.si/PETSTA-${bookingId.replaceAll('-', '')}';

/// True for a plain http(s) link that is safe to open in the browser.
bool isSafeWebLink(String? value) {
  if (value == null || value.trim().isEmpty) return false;
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}
