import { Phone, User } from "@phosphor-icons/react";

/** A requester's name and phone (shop owners may see these for their own requests). */
export function CustomerContact({ profile }) {
  return (
    <span className="inline-flex flex-wrap items-center gap-x-3 gap-y-1">
      <span className="inline-flex items-center gap-1.5">
        <User size={15} aria-hidden="true" className="flex-none text-ink-soft" />
        {profile?.name || "Customer"}
      </span>
      {profile?.phone && (
        <a href={`tel:${profile.phone}`} className="inline-flex items-center gap-1.5 text-primary hover:underline">
          <Phone size={15} aria-hidden="true" className="flex-none" />
          {profile.phone}
        </a>
      )}
    </span>
  );
}
