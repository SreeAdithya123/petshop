import { create } from "zustand";
import { supabase } from "../lib/supabaseClient";

const GENERIC_ERROR = "Something went wrong. Please try again.";
const OFFLINE_ERROR = "You're offline or the connection is unstable. Check your internet and try again.";
const SERVER_ERROR = "We're having trouble on our side. Please try again in a moment.";
const RATE_LIMIT_ERROR = "Too many attempts. Please wait a minute and try again.";
const WEAK_PASSWORD_ERROR = "Choose a stronger password: at least 8 characters and not easy to guess.";
const EXPIRED_LINK_ERROR = "This link has expired or was already used. Please request a new one.";

/**
 * Turns anything the auth API throws into one short sentence a customer can
 * act on. Raw error text from the auth server is only shown when it is short
 * and written for people.
 */
export function authErrorMessage(error, fallback = GENERIC_ERROR) {
  if (!error) return fallback;

  const code = String(error.code ?? "").toLowerCase();
  const message = String(error.message ?? "").trim();
  const lower = message.toLowerCase();
  const status = Number(error.status) || 0;

  if (
    error.name === "AuthRetryableFetchError" ||
    /failed to fetch|networkerror|network request failed|load failed/.test(lower) ||
    (typeof navigator !== "undefined" && navigator.onLine === false)
  ) {
    return OFFLINE_ERROR;
  }

  switch (code) {
    case "invalid_credentials":
      return "Incorrect email or password. Please try again.";
    case "email_not_confirmed":
      return "Please confirm your email address first. Check your inbox for the link.";
    case "user_already_exists":
    case "email_exists":
      return "An account with this email already exists. Try logging in instead.";
    case "over_request_rate_limit":
    case "over_email_send_rate_limit":
    case "over_sms_send_rate_limit":
      return RATE_LIMIT_ERROR;
    case "weak_password":
      return WEAK_PASSWORD_ERROR;
    case "same_password":
      return "Your new password must be different from your current one.";
    case "user_banned":
      return "This account has been suspended. Please contact support.";
    case "signup_disabled":
    case "email_provider_disabled":
      return "Sign-ups are unavailable right now. Please try again later.";
    case "otp_expired":
    case "flow_state_expired":
    case "flow_state_not_found":
    case "bad_code_verifier":
      return EXPIRED_LINK_ERROR;
    case "validation_failed":
    case "bad_json":
      return "Please check your details and try again.";
    case "email_address_invalid":
      return "That email address doesn't look valid.";
    case "email_address_not_authorized":
      return "We can't send email to that address right now.";
    case "session_expired":
    case "session_not_found":
    case "refresh_token_not_found":
    case "bad_jwt":
      return "Your session has expired. Please log in again.";
    case "reauthentication_needed":
    case "reauthentication_not_valid":
      return "For your security, please log in again to do that.";
    case "unexpected_failure":
    case "hook_timeout":
    case "hook_timeout_after_retry":
      return SERVER_ERROR;
    default:
      break;
  }

  // Older auth servers send no machine-readable code.
  if (lower.includes("invalid login credentials")) return "Incorrect email or password. Please try again.";
  if (lower.includes("email not confirmed")) {
    return "Please confirm your email address first. Check your inbox for the link.";
  }
  if (lower.includes("already registered") || lower.includes("already been registered")) {
    return "An account with this email already exists. Try logging in instead.";
  }
  if (lower.includes("rate limit") || lower.includes("too many requests") || status === 429) {
    return RATE_LIMIT_ERROR;
  }
  if (lower.includes("password should be") || lower.includes("weak password")) return WEAK_PASSWORD_ERROR;
  if (lower.includes("different from the old password")) {
    return "Your new password must be different from your current one.";
  }
  if (status >= 500) return SERVER_ERROR;

  if (message && message.length <= 140 && !lower.includes("exception")) return message;
  return fallback;
}

export const PASSWORD_HINT = "At least 8 characters, with a letter and a number.";

/** Returns a message when a new password isn't acceptable, otherwise "". */
export function passwordProblem(value) {
  if (!value) return "Create a password.";
  if (value.length < 8) return "Use at least 8 characters.";
  if (value.length > 72) return "Use 72 characters or fewer.";
  if (!/[A-Za-z]/.test(value) || !/\d/.test(value)) return "Include at least one letter and one number.";
  return "";
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

export function isValidEmail(value) {
  const email = String(value ?? "").trim();
  return email.length <= 254 && EMAIL_PATTERN.test(email);
}

/** True when the page was opened from a password-reset email (implicit-flow link). */
function recoveryLinkInUrl() {
  if (typeof window === "undefined") return false;
  const params = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  return params.get("type") === "recovery" && params.has("access_token");
}

// initialize() runs once per mount (twice under StrictMode in development);
// the auth listener must only ever be attached once.
let authListenerAttached = false;

/**
 * Session + profile (role) state. `status` starts "loading" until the
 * initial getSession() resolves, so route guards can tell "not signed in
 * yet" apart from "still checking."
 *
 * `passwordRecovery` is true after the visitor opened a password-reset link
 * and until they choose a new password (or sign out). App.jsx sends them to
 * /reset-password while it is set.
 */
export const useAuthStore = create((set, get) => ({
  session: null,
  profile: null,
  status: "loading",
  passwordRecovery: false,

  initialize: async () => {
    // Listen before reading the session so the PASSWORD_RECOVERY event that
    // the client raises while it processes a reset link can't be missed.
    if (!authListenerAttached) {
      authListenerAttached = true;
      supabase.auth.onAuthStateChange((event, nextSession) => {
        // initialize() applies the stored session itself.
        if (event === "INITIAL_SESSION") return;
        if (event === "PASSWORD_RECOVERY") set({ passwordRecovery: true });
        if (event === "SIGNED_OUT") set({ passwordRecovery: false });
        get()._applySession(nextSession);
      });
    }
    if (recoveryLinkInUrl()) set({ passwordRecovery: true });

    const {
      data: { session },
    } = await supabase.auth.getSession();
    await get()._applySession(session);
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
      // Supabase answers "success" for an address that is already registered
      // but hands back a user with no identities.
      if (Array.isArray(data.user?.identities) && data.user.identities.length === 0) {
        throw new Error("An account with this email already exists. Try logging in or resetting your password.");
      }
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
    set({ session: null, profile: null, status: "signed-out", passwordRecovery: false });
  },

  // Emails a reset link that opens /reset-password. An unknown address is
  // treated exactly like a known one so the form can't be used to find out
  // who has an account.
  resetPassword: async (email) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    if (error && String(error.code ?? "").toLowerCase() !== "user_not_found") throw error;
  },

  // Sets a new password for the current session (the temporary one that a
  // reset link creates, or a normal signed-in session).
  updatePassword: async (newPassword) => {
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    if (error) throw error;
    set({ passwordRecovery: false });
  },

  // Sends the sign-up confirmation email again.
  resendConfirmation: async (email) => {
    const { error } = await supabase.auth.resend({ type: "signup", email: email.trim() });
    if (error) throw error;
  },
}));

export function roleHomePath(role) {
  if (role === "admin") return "/admin/dashboard";
  if (role === "shop_owner") return "/seller/dashboard";
  return "/account";
}
