import {
  ArrowCounterClockwise,
  ArrowRight,
  BookOpen,
  CalendarCheck,
  Heart,
  MapPinLine,
  Package,
  ShieldCheck,
  SignOut,
  SquaresFour,
  Storefront,
} from "@phosphor-icons/react";
import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { AccountPageHeader } from "../../components/account/AccountPage";
import { Button } from "../../components/ui/Button";
import { Field } from "../../components/ui/FormField";
import { formatDate } from "../../lib/format";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { roleHomePath, useAuthStore } from "../../store/authStore";

const ROLE_LABELS = {
  customer: "Customer",
  shop_owner: "Shop owner",
  admin: "Admin",
};

const SECTION_LINKS = [
  { to: "/account/orders", label: "My orders", description: "Purchases, reservations and gifts.", icon: Package },
  { to: "/account/wishlist", label: "Wishlist", description: "Pets you've saved for later.", icon: Heart },
  {
    to: "/account/refunds",
    label: "Refunds",
    description: "Request a refund and track its status.",
    icon: ArrowCounterClockwise,
  },
  { to: "/account/addresses", label: "Addresses", description: "Where your orders and gifts go.", icon: MapPinLine },
  {
    to: "/account/demos",
    label: "Demo requests",
    description: "Meet a pet before you decide.",
    icon: CalendarCheck,
  },
  { to: "/account/learn", label: "Learn", description: "Pet care videos.", icon: BookOpen },
];

const SELL_LINK = {
  to: "/account/sell",
  label: "Sell on PETSTA",
  description: "Apply to list your shop.",
  icon: Storefront,
};

const PHONE_PATTERN = /^[\d\s()+-]{7,}$/;

function quickLinksFor(role) {
  if (role === "customer") return [...SECTION_LINKS, SELL_LINK];
  const dashboard = {
    to: roleHomePath(role),
    label: role === "admin" ? "Admin dashboard" : "Seller dashboard",
    description: role === "admin" ? "Manage shops, services and orders." : "Manage your shop.",
    icon: role === "admin" ? ShieldCheck : SquaresFour,
  };
  return [dashboard, ...SECTION_LINKS];
}

function ProfileForm({ profile }) {
  const [name, setName] = useState(profile.name ?? "");
  const [phone, setPhone] = useState(profile.phone ?? "");
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);

  const email = useAuthStore((state) => state.session?.user?.email) ?? profile.email ?? "";
  const dirty = name.trim() !== (profile.name ?? "") || phone.trim() !== (profile.phone ?? "");

  function edit(setter) {
    return (event) => {
      setter(event.target.value);
      setSaved(false);
    };
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setFormError("");
    setSaved(false);

    const nextErrors = {};
    if (!name.trim()) nextErrors.name = "Enter your name.";
    if (phone.trim() && !PHONE_PATTERN.test(phone.trim())) nextErrors.phone = "Enter a valid phone number.";
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSaving(true);
    const { data, error } = await supabase
      .from("profiles")
      .update({ name: name.trim(), phone: phone.trim() })
      .eq("id", profile.id)
      .select("id, role, name, phone, email")
      .maybeSingle();
    setSaving(false);

    if (error) {
      setFormError(error.message);
      return;
    }
    if (!data) {
      setFormError("Couldn't save your changes. Please try again.");
      return;
    }
    // Keep the header/sidebar (which read the profile from the store) in sync.
    useAuthStore.setState({ profile: data });
    setSaved(true);
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="mt-4 flex max-w-lg flex-col gap-5">
      <Field label="Name" htmlFor="profile-name" error={errors.name}>
        <input
          id="profile-name"
          type="text"
          autoComplete="name"
          value={name}
          onChange={edit(setName)}
          aria-invalid={Boolean(errors.name)}
          className={fieldClassName(Boolean(errors.name))}
        />
      </Field>

      <Field label="Phone" htmlFor="profile-phone" error={errors.phone} optional>
        <input
          id="profile-phone"
          type="tel"
          autoComplete="tel"
          value={phone}
          onChange={edit(setPhone)}
          aria-invalid={Boolean(errors.phone)}
          className={fieldClassName(Boolean(errors.phone))}
        />
      </Field>

      <Field label="Email" htmlFor="profile-email" hint="Your email is your login, so it can't be changed here.">
        <input
          id="profile-email"
          type="email"
          value={email}
          readOnly
          disabled
          className={`${fieldClassName(false)} cursor-not-allowed bg-paper text-ink-soft`}
        />
      </Field>

      {formError && (
        <p role="alert" className="text-sm text-error">
          {formError}
        </p>
      )}

      <div className="flex flex-wrap items-center gap-4">
        <Button type="submit" variant="accent" disabled={saving || !dirty}>
          {saving ? "Saving…" : "Save changes"}
        </Button>
        {saved && (
          <p role="status" className="text-sm text-trust">
            Profile updated.
          </p>
        )}
      </div>
    </form>
  );
}

export function AccountProfile() {
  const navigate = useNavigate();
  const profile = useAuthStore((state) => state.profile);
  const session = useAuthStore((state) => state.session);
  const signOut = useAuthStore((state) => state.signOut);
  const [loggingOut, setLoggingOut] = useState(false);
  const [logoutError, setLogoutError] = useState("");

  async function handleLogout() {
    setLoggingOut(true);
    setLogoutError("");
    try {
      await signOut();
      navigate("/");
    } catch (error) {
      setLogoutError(error.message || "Couldn't log you out. Please try again.");
      setLoggingOut(false);
    }
  }

  // The account layout already gates on a loaded profile.
  if (!profile) return null;

  const memberSince = session?.user?.created_at;
  const initial = (profile.name || profile.email || "?").trim().charAt(0).toUpperCase();

  return (
    <div>
      <AccountPageHeader title="Profile" description="Your details, and shortcuts to everything in your account." />

      <div className="mt-6 flex flex-wrap items-center gap-4 rounded-xl border border-border bg-surface p-5">
        <span
          aria-hidden="true"
          className="flex h-14 w-14 flex-none items-center justify-center rounded-full bg-primary/10 font-display text-xl font-bold text-primary"
        >
          {initial}
        </span>
        <div className="min-w-0 flex-1">
          <p className="truncate font-display text-lg font-semibold text-ink">{profile.name || "Your account"}</p>
          {profile.email && <p className="truncate text-sm text-ink-soft">{profile.email}</p>}
          <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-ink-soft">
            <span className="rounded-full bg-primary/10 px-2.5 py-1 text-xs font-medium text-primary">
              {ROLE_LABELS[profile.role] ?? profile.role}
            </span>
            {memberSince && <span>Member since {formatDate(memberSince)}</span>}
          </div>
        </div>
        <Button variant="outline" size="sm" onClick={handleLogout} disabled={loggingOut}>
          <SignOut size={16} />
          {loggingOut ? "Logging out…" : "Log out"}
        </Button>
        {logoutError && (
          <p role="alert" className="w-full text-sm text-error">
            {logoutError}
          </p>
        )}
      </div>

      <section className="mt-10">
        <h2 className="font-display text-xl font-semibold text-ink">Your details</h2>
        <ProfileForm key={profile.id} profile={profile} />
      </section>

      <section className="mt-10">
        <h2 className="font-display text-xl font-semibold text-ink">Quick links</h2>
        <ul className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
          {quickLinksFor(profile.role).map(({ to, label, description, icon: Icon }) => (
            <li key={to}>
              <Link
                to={to}
                className="group flex h-full items-center gap-3 rounded-xl border border-border bg-surface p-4 transition-colors hover:border-primary/40 hover:bg-primary/5"
              >
                <span className="flex h-10 w-10 flex-none items-center justify-center rounded-lg bg-primary/10 text-primary">
                  <Icon size={20} />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-[15px] font-medium text-ink">{label}</span>
                  <span className="block text-sm text-ink-soft">{description}</span>
                </span>
                <ArrowRight
                  size={16}
                  className="flex-none text-ink-soft transition-transform group-hover:translate-x-0.5"
                />
              </Link>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
