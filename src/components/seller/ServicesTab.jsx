import { PencilSimple, Plus, Trash } from "@phosphor-icons/react";
import { useState } from "react";
import { formatPrice } from "../../lib/format";
import { Button } from "../ui/Button";
import { EmptyState } from "../ui/EmptyState";
import { StatusBadge } from "../ui/StatusBadge";
import { ConfirmModal } from "./ConfirmModal";
import { categoryLabel, formatDuration } from "./helpers";
import { ListSkeleton } from "./ListSkeleton";
import { LoadError } from "./LoadError";
import { deleteRow } from "./mutations";
import { Notice } from "./Notice";
import { ServiceFormModal } from "./ServiceFormModal";

const STATUS_LABELS = { pending: "Awaiting admin approval" };

/** "My services": the shop's catalogue, with add / edit / delete. */
export function ServicesTab({ shopId, readOnly, query }) {
  const [formTarget, setFormTarget] = useState(null); // { service } while the form is open; service is null when adding
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [flash, setFlash] = useState("");

  const services = query.data ?? [];

  async function handleDelete() {
    // A service with bookings can't be deleted; the database's message is shown as-is.
    const message = await deleteRow("services", deleteTarget.id);
    if (message) return message;
    setDeleteTarget(null);
    setFlash("Service deleted.");
    query.reload();
    return null;
  }

  function handleSaved(message) {
    setFormTarget(null);
    setFlash(message);
    query.reload();
  }

  function openForm(service) {
    setFlash("");
    setFormTarget({ service });
  }

  if (query.loading) return <ListSkeleton rows={3} />;
  if (query.error && !query.data) {
    return <LoadError what="your services" message={query.error} onRetry={query.reload} />;
  }

  const addButton = (
    <Button type="button" variant="accent" size="sm" onClick={() => openForm(null)}>
      <Plus size={16} aria-hidden="true" />
      Add service
    </Button>
  );

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-ink-soft">Services customers can book. New services go live after admin approval.</p>
        {!readOnly && services.length > 0 && addButton}
      </div>

      {flash && <Notice tone="success">{flash}</Notice>}
      {query.error && <LoadError what="your services" message={query.error} onRetry={query.reload} />}

      {services.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border bg-surface">
          <EmptyState
            title="No services yet"
            description="Offer grooming, vet visits, training and more. Each new service is reviewed by an admin before customers can book it."
            action={readOnly ? null : addButton}
          />
        </div>
      ) : (
        <ul className="divide-y divide-border rounded-xl border border-border bg-surface">
          {services.map((service) => (
            <li key={service.id} className="flex flex-col gap-3 px-5 py-4 md:flex-row md:items-center md:gap-6">
              <div className="min-w-0 flex-1">
                <p className="text-[15px] font-medium text-ink">{service.name}</p>
                <p className="text-sm text-ink-soft">
                  {[categoryLabel(service.category), formatDuration(service.duration_minutes)]
                    .filter(Boolean)
                    .join(" · ")}
                </p>
                {service.description && <p className="mt-1 line-clamp-2 text-sm text-ink-soft">{service.description}</p>}
              </div>

              <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
                <p className="text-[15px] font-medium text-accent">{formatPrice(service.price)}</p>
                <StatusBadge status={service.status} label={STATUS_LABELS[service.status]} />
              </div>

              {!readOnly && (
                <div className="flex gap-2">
                  <Button type="button" variant="outline" size="sm" onClick={() => openForm(service)}>
                    <PencilSimple size={16} aria-hidden="true" />
                    Edit
                  </Button>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    aria-label={`Delete ${service.name}`}
                    onClick={() => setDeleteTarget(service)}
                  >
                    <Trash size={16} aria-hidden="true" />
                    Delete
                  </Button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}

      {formTarget && (
        <ServiceFormModal
          shopId={shopId}
          service={formTarget.service}
          onClose={() => setFormTarget(null)}
          onSaved={handleSaved}
        />
      )}

      {deleteTarget && (
        <ConfirmModal
          title="Delete this service?"
          description={`"${deleteTarget.name}" will be removed from your shop. This can't be undone.`}
          confirmLabel="Delete service"
          destructive
          onConfirm={handleDelete}
          onClose={() => setDeleteTarget(null)}
        />
      )}
    </div>
  );
}
