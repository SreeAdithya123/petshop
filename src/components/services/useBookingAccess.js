import { useAuthStore } from "../../store/authStore";

/**
 * Who is looking at a booking / request form. Only signed-in customers can
 * book; signed-out visitors get a login prompt and other roles a short note.
 */
export function useBookingAccess() {
  const session = useAuthStore((state) => state.session);
  const profile = useAuthStore((state) => state.profile);
  const status = useAuthStore((state) => state.status);

  return {
    session,
    status,
    role: profile?.role ?? null,
    userId: session?.user?.id ?? null,
    canBook: Boolean(session) && profile?.role === "customer",
  };
}
