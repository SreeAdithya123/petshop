import { create } from "zustand";
import { supabase } from "../lib/supabaseClient";

/**
 * Session + profile (role) state. `status` starts "loading" until the
 * initial getSession() resolves, so route guards can tell "not signed in
 * yet" apart from "still checking."
 */
export const useAuthStore = create((set, get) => ({
  session: null,
  profile: null,
  status: "loading",

  initialize: async () => {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    await get()._applySession(session);

    supabase.auth.onAuthStateChange((_event, nextSession) => {
      get()._applySession(nextSession);
    });
  },

  _applySession: async (session) => {
    if (!session) {
      set({ session: null, profile: null, status: "signed-out" });
      return;
    }
    const { data: profile } = await supabase
      .from("profiles")
      .select("id, role, name, phone, email")
      .eq("id", session.user.id)
      .single();
    set({ session, profile: profile ?? null, status: "signed-in" });
  },

  // Returns { needsEmailConfirmation: boolean, profile } — signUp doesn't
  // always come back with an active session (depends on the project's
  // "confirm email" auth setting), so the caller can't assume it's safe to
  // redirect to a role-gated page immediately.
  signUp: async ({ email, password, name, phone, role }) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { name, full_name: name, phone, role } },
    });
    if (error) throw error;

    if (!data.session) {
      return { needsEmailConfirmation: true, profile: null };
    }
    await get()._applySession(data.session);
    return { needsEmailConfirmation: false, profile: get().profile };
  },

  signIn: async ({ email, password }) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    await get()._applySession(data.session);
    return get().profile;
  },

  signOut: async () => {
    await supabase.auth.signOut();
    set({ session: null, profile: null, status: "signed-out" });
  },
}));

export function roleHomePath(role) {
  if (role === "admin") return "/admin/dashboard";
  if (role === "shop_owner") return "/seller/dashboard";
  return "/account";
}
