import { PencilSimple, Plus, Trash } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { AccountPageHeader, ErrorNote, LoadingNote } from "../../components/account/AccountPage";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { Field } from "../../components/ui/FormField";
import { Modal } from "../../components/ui/Modal";
import { supabase } from "../../lib/supabaseClient";
import { fieldClassName } from "../../lib/styles";
import { useAuthStore } from "../../store/authStore";

const LABELS = ["Home", "Work", "Other"];
const ADDRESS_COLUMNS = "id, label, line1, line2, city, state, zip, is_default, created_at";
const ZIP_PATTERN = /^[A-Za-z0-9][A-Za-z0-9\s-]{2,9}$/;

function validate(form) {
  const errors = {};
  if (!form.line1.trim()) errors.line1 = "Enter the street address.";
  if (!form.city.trim()) errors.city = "Enter the city.";
  if (!form.zip.trim()) errors.zip = "Enter the PIN / ZIP code.";
  else if (!ZIP_PATTERN.test(form.zip.trim())) errors.zip = "Enter a valid PIN / ZIP code.";
  return errors;
}

function RowAction({ icon: Icon, tone = "default", children, ...props }) {
  const tones = {
    default: "text-ink-soft hover:bg-primary/5 hover:text-ink",
    danger: "text-error hover:bg-error/5",
  };
  return (
    <button
      type="button"
      className={`inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium transition-colors disabled:pointer-events-none disabled:opacity-50 ${tones[tone]}`}
      {...props}
    >
      {Icon && <Icon size={16} />}
      {children}
    </button>
  );
}

function AddressForm({ address, startsAsDefault, saving, error, onSubmit, onCancel }) {
  const [form, setForm] = useState({
    label: address?.label ?? "Home",
    line1: address?.line1 ?? "",
    line2: address?.line2 ?? "",
    city: address?.city ?? "",
    state: address?.state ?? "",
    zip: address?.zip ?? "",
    isDefault: address ? address.is_default : startsAsDefault,
  });
  const [errors, setErrors] = useState({});

  // Keep a custom label from older data selectable.
  const labelOptions = LABELS.includes(form.label) ? LABELS : [form.label, ...LABELS];

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }));
  }

  function handleSubmit(event) {
    event.preventDefault();
    const nextErrors = validate(form);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;
    onSubmit({
      label: form.label,
      line1: form.line1.trim(),
      line2: form.line2.trim() || null,
      city: form.city.trim(),
      state: form.state.trim() || null,
      zip: form.zip.trim(),
      isDefault: form.isDefault,
    });
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-4">
      <Field label="Label" htmlFor="address-label">
        <select
          id="address-label"
          value={form.label}
          onChange={(event) => update("label", event.target.value)}
          className={fieldClassName(false)}
        >
          {labelOptions.map((label) => (
            <option key={label} value={label}>
              {label}
            </option>
          ))}
        </select>
      </Field>

      <Field label="Address line 1" htmlFor="address-line1" error={errors.line1}>
        <input
          id="address-line1"
          type="text"
          autoComplete="address-line1"
          value={form.line1}
          onChange={(event) => update("line1", event.target.value)}
          aria-invalid={Boolean(errors.line1)}
          className={fieldClassName(Boolean(errors.line1))}
        />
      </Field>

      <Field label="Address line 2" htmlFor="address-line2" optional>
        <input
          id="address-line2"
          type="text"
          autoComplete="address-line2"
          value={form.line2}
          onChange={(event) => update("line2", event.target.value)}
          className={fieldClassName(false)}
        />
      </Field>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field label="City" htmlFor="address-city" error={errors.city}>
          <input
            id="address-city"
            type="text"
            autoComplete="address-level2"
            value={form.city}
            onChange={(event) => update("city", event.target.value)}
            aria-invalid={Boolean(errors.city)}
            className={fieldClassName(Boolean(errors.city))}
          />
        </Field>
        <Field label="State" htmlFor="address-state" optional>
          <input
            id="address-state"
            type="text"
            autoComplete="address-level1"
            value={form.state}
            onChange={(event) => update("state", event.target.value)}
            className={fieldClassName(false)}
          />
        </Field>
      </div>

      <Field label="PIN / ZIP code" htmlFor="address-zip" error={errors.zip} className="sm:max-w-[50%]">
        <input
          id="address-zip"
          type="text"
          autoComplete="postal-code"
          value={form.zip}
          onChange={(event) => update("zip", event.target.value)}
          aria-invalid={Boolean(errors.zip)}
          className={fieldClassName(Boolean(errors.zip))}
        />
      </Field>

      <label className="flex items-center gap-2.5 text-sm text-ink">
        <input
          type="checkbox"
          checked={form.isDefault}
          onChange={(event) => update("isDefault", event.target.checked)}
          className="h-4 w-4 accent-primary"
        />
        Use as my default address
      </label>

      {error && (
        <p role="alert" className="text-sm text-error">
          {error}
        </p>
      )}

      <div className="mt-1 flex flex-wrap justify-end gap-3">
        <Button variant="outline" onClick={onCancel} disabled={saving}>
          Cancel
        </Button>
        <Button type="submit" variant="accent" disabled={saving}>
          {saving ? "Saving…" : "Save address"}
        </Button>
      </div>
    </form>
  );
}

export function AccountAddresses() {
  const userId = useAuthStore((state) => state.session?.user?.id);

  const [addresses, setAddresses] = useState(null);
  const [loadError, setLoadError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);

  const [editing, setEditing] = useState(null); // null | "new" | an address row
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [actionError, setActionError] = useState("");

  useEffect(() => {
    if (!userId) return undefined;
    let cancelled = false;

    async function load() {
      const { data, error } = await supabase
        .from("addresses")
        .select(ADDRESS_COLUMNS)
        .eq("customer_id", userId)
        .order("is_default", { ascending: false })
        .order("created_at", { ascending: false });
      if (cancelled) return;
      if (error) setLoadError(error.message);
      else setAddresses(data ?? []);
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [userId, reloadKey]);

  function reload() {
    setReloadKey((key) => key + 1);
  }

  function retryLoad() {
    setLoadError("");
    setAddresses(null);
    reload();
  }

  /** Makes one address the default, clearing the others first so there is never more than one. */
  async function makeOnlyDefault(addressId) {
    const { error: clearError } = await supabase
      .from("addresses")
      .update({ is_default: false })
      .eq("customer_id", userId)
      .eq("is_default", true)
      .neq("id", addressId);
    if (clearError) return clearError;

    const { error } = await supabase
      .from("addresses")
      .update({ is_default: true })
      .eq("id", addressId)
      .eq("customer_id", userId);
    return error;
  }

  async function handleSave(values) {
    const { isDefault, ...fields } = values;
    const isNew = editing === "new";
    const wasDefault = !isNew && editing.is_default;
    setSaving(true);
    setSaveError("");

    let error;
    let addressId = isNew ? null : editing.id;

    if (isNew) {
      // Insert as a plain address first; the default flag is applied afterwards
      // so a failed insert can never cost the customer their current default.
      const { data, error: insertError } = await supabase
        .from("addresses")
        .insert({ ...fields, customer_id: userId, is_default: false })
        .select("id")
        .single();
      error = insertError;
      addressId = data?.id ?? null;
    } else {
      const { error: updateError } = await supabase
        .from("addresses")
        .update(fields)
        .eq("id", addressId)
        .eq("customer_id", userId);
      error = updateError;
    }

    if (!error && addressId) {
      if (isDefault && !wasDefault) {
        error = await makeOnlyDefault(addressId);
      } else if (!isDefault && wasDefault) {
        const { error: unsetError } = await supabase
          .from("addresses")
          .update({ is_default: false })
          .eq("id", addressId)
          .eq("customer_id", userId);
        error = unsetError;
      }
    }

    setSaving(false);
    // Reload either way so the list reflects whatever the server actually saved.
    reload();
    if (error) {
      setSaveError(error.message);
      // The address itself was saved; retrying must edit it rather than add a duplicate.
      if (isNew && addressId) setEditing({ id: addressId, ...fields, is_default: false });
      return;
    }
    setEditing(null);
  }

  async function handleSetDefault(address) {
    setBusyId(address.id);
    setActionError("");
    const error = await makeOnlyDefault(address.id);
    setBusyId(null);
    if (error) setActionError(error.message);
    reload();
  }

  async function handleDelete(address) {
    if (!window.confirm(`Delete your ${address.label} address (${address.line1})? This can't be undone.`)) return;
    setBusyId(address.id);
    setActionError("");
    const { error } = await supabase.from("addresses").delete().eq("id", address.id).eq("customer_id", userId);
    setBusyId(null);
    if (error) {
      setActionError(error.message);
      return;
    }
    setAddresses((current) => current?.filter((candidate) => candidate.id !== address.id) ?? current);
  }

  function openForm(target) {
    setSaveError("");
    setEditing(target);
  }

  function closeForm() {
    if (!saving) setEditing(null);
  }

  const header = (
    <AccountPageHeader
      title="Addresses"
      description="Your delivery addresses for orders and gifts. Shops only get what they need to fulfil a delivery."
      action={
        addresses && addresses.length > 0 ? (
          <Button variant="accent" size="sm" onClick={() => openForm("new")}>
            <Plus size={16} weight="bold" />
            Add address
          </Button>
        ) : null
      }
    />
  );

  if (loadError) {
    return (
      <div>
        {header}
        <ErrorNote message={loadError} onRetry={retryLoad} />
      </div>
    );
  }

  if (!addresses) {
    return (
      <div>
        {header}
        <LoadingNote />
      </div>
    );
  }

  return (
    <div>
      {header}

      {actionError && (
        <p role="alert" className="mt-4 text-sm text-error">
          {actionError}
        </p>
      )}

      {addresses.length === 0 ? (
        <EmptyState
          title="No saved addresses"
          description="Add an address to speed up checkout and gifting."
          action={
            <Button variant="accent" size="sm" onClick={() => openForm("new")}>
              <Plus size={16} weight="bold" />
              Add an address
            </Button>
          }
        />
      ) : (
        <ul className="mt-6 flex flex-col gap-3">
          {addresses.map((address) => {
            const busy = busyId === address.id;
            const place = [address.city, address.state].filter(Boolean).join(", ");
            return (
              <li
                key={address.id}
                className="flex flex-col gap-3 rounded-xl border border-border bg-surface p-4 sm:p-5 md:flex-row md:items-start md:justify-between"
              >
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <h3 className="font-display text-[15px] font-semibold text-ink">{address.label}</h3>
                    {address.is_default && (
                      <span className="rounded-full bg-primary/10 px-2.5 py-1 text-xs font-medium text-primary">
                        Default
                      </span>
                    )}
                  </div>
                  <address className="mt-1.5 break-words text-[15px] not-italic leading-relaxed text-ink-soft">
                    {address.line1}
                    {address.line2 && (
                      <>
                        <br />
                        {address.line2}
                      </>
                    )}
                    <br />
                    {[place, address.zip].filter(Boolean).join(" ")}
                  </address>
                </div>

                <div className="-mx-1 flex flex-wrap items-center gap-1 md:mx-0 md:flex-none md:justify-end">
                  <RowAction icon={PencilSimple} onClick={() => openForm(address)} disabled={busy}>
                    Edit
                  </RowAction>
                  {!address.is_default && (
                    <RowAction onClick={() => handleSetDefault(address)} disabled={busy}>
                      Make default
                    </RowAction>
                  )}
                  <RowAction icon={Trash} tone="danger" onClick={() => handleDelete(address)} disabled={busy}>
                    Delete
                  </RowAction>
                </div>
              </li>
            );
          })}
        </ul>
      )}

      {editing && (
        <Modal
          open
          onClose={closeForm}
          title={editing === "new" ? "Add an address" : "Edit address"}
          description="Used for delivery of your orders and gifts."
        >
          <AddressForm
            address={editing === "new" ? null : editing}
            startsAsDefault={addresses.length === 0}
            saving={saving}
            error={saveError}
            onSubmit={handleSave}
            onCancel={closeForm}
          />
        </Modal>
      )}
    </div>
  );
}
