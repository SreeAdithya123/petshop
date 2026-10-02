import { HeartBreak } from "@phosphor-icons/react";
import { useState } from "react";
import { AccountPageHeader, ErrorNote, LoadingNote } from "../../components/account/AccountPage";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";
import { PetCard } from "../../components/ui/PetCard";
import { useAuthStore } from "../../store/authStore";
import { useCatalog } from "../../store/catalogStore";
import { useWishlist, useWishlistStore } from "../../store/wishlistStore";

export function AccountWishlist() {
  const userId = useAuthStore((state) => state.session?.user?.id ?? null);
  const { petIds, toggle } = useWishlist();
  const wishlistLoaded = useWishlistStore((state) => state.loadedFor === userId);
  const { getPetById, loading: catalogLoading, error: catalogError, reload } = useCatalog();

  const [removing, setRemoving] = useState(() => new Set());
  const [removeError, setRemoveError] = useState("");

  const header = (
    <AccountPageHeader
      title="Wishlist"
      description="Pets you've saved. Only pets that are still available show up here."
    />
  );

  if (catalogError) {
    return (
      <div>
        {header}
        <ErrorNote message={catalogError} onRetry={reload} />
      </div>
    );
  }

  if (!wishlistLoaded || catalogLoading) {
    return (
      <div>
        {header}
        <LoadingNote />
      </div>
    );
  }

  const availablePets = petIds.map((id) => getPetById(id)).filter(Boolean);
  const unavailableIds = petIds.filter((id) => !getPetById(id));

  async function remove(ids) {
    setRemoveError("");
    setRemoving((current) => new Set([...current, ...ids]));
    const results = await Promise.all(ids.map((id) => toggle(id)));
    setRemoving((current) => {
      const next = new Set(current);
      ids.forEach((id) => next.delete(id));
      return next;
    });
    if (results.includes(false)) {
      setRemoveError("Couldn't update your wishlist. Please try again.");
    }
  }

  if (petIds.length === 0) {
    return (
      <div>
        {header}
        <EmptyState
          title="Your wishlist is empty"
          description="Tap the heart on any pet to save it here for later."
          action={
            <Button to="/pets" size="sm">
              Browse pets
            </Button>
          }
        />
      </div>
    );
  }

  return (
    <div>
      {header}

      {unavailableIds.length > 0 && (
        <div className="mt-6 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border bg-surface px-4 py-3">
          <p className="text-sm text-ink-soft">
            {unavailableIds.length === 1
              ? "1 pet on your wishlist is no longer available."
              : `${unavailableIds.length} pets on your wishlist are no longer available.`}
          </p>
          <Button
            variant="outline"
            size="sm"
            onClick={() => remove(unavailableIds)}
            disabled={unavailableIds.some((id) => removing.has(id))}
          >
            Remove {unavailableIds.length === 1 ? "it" : "them"}
          </Button>
        </div>
      )}

      {removeError && (
        <p role="alert" className="mt-4 text-sm text-error">
          {removeError}
        </p>
      )}

      {availablePets.length > 0 ? (
        <ul className="mt-6 grid grid-cols-1 gap-4 xs:grid-cols-2 lg:grid-cols-3">
          {availablePets.map((pet) => (
            <li key={pet.id} className="flex flex-col gap-2">
              <div className="flex-1">
                <PetCard pet={pet} />
              </div>
              <Button variant="outline" size="sm" onClick={() => remove([pet.id])} disabled={removing.has(pet.id)}>
                <HeartBreak size={16} />
                {removing.has(pet.id) ? "Removing…" : "Remove from wishlist"}
              </Button>
            </li>
          ))}
        </ul>
      ) : (
        <EmptyState
          title="Nothing available right now"
          description="The pets you saved have found homes. Browse more to save new favourites."
          action={
            <Button to="/pets" size="sm">
              Browse pets
            </Button>
          }
        />
      )}
    </div>
  );
}
