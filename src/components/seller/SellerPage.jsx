import { Container } from "../layout/Container";
import { Button } from "../ui/Button";
import { EmptyState } from "../ui/EmptyState";
import { ListSkeleton } from "./ListSkeleton";
import { Notice } from "./Notice";

function Heading({ title, description }) {
  return (
    <div>
      <h1 className="font-display text-3xl font-bold text-ink">{title}</h1>
      {description && <p className="mt-2 text-[15px] text-ink-soft">{description}</p>}
    </div>
  );
}

/**
 * Shared frame for the shop-owner pages: heading, a loading skeleton while the
 * shop loads, a "set up your shop" prompt when there isn't one, and a
 * read-only notice until an admin has approved the shop. `children` only
 * render once a shop exists, so they can read `shop` freely; they should treat
 * `shop.status !== "approved"` as read-only. `unlocks` is a verb phrase that
 * completes "You'll be able to {unlocks} once it is approved."
 */
export function SellerPage({ title, description, unlocks, shop, loading, error, children }) {
  if (loading) {
    return (
      <Container className="py-12">
        <Heading title={title} description={description} />
        <div className="mt-8">
          <ListSkeleton tiles={3} />
        </div>
      </Container>
    );
  }

  if (!shop) {
    return (
      <Container className="py-12">
        {error ? (
          <>
            <Heading title={title} description={description} />
            <Notice tone="error" className="mt-8">
              Couldn&rsquo;t load your shop: {error}
            </Notice>
          </>
        ) : (
          <EmptyState
            title="You haven't set up your shop yet"
            description="Create your shop profile first. Once an admin approves it, this page unlocks."
            action={
              <Button to="/seller/store" size="sm">
                Set up your shop
              </Button>
            }
          />
        )}
      </Container>
    );
  }

  return (
    <Container className="py-12">
      <Heading title={title} description={description} />

      {shop.status !== "approved" && (
        <Notice tone="warning" title="This page is read-only for now" className="mt-6">
          {shop.status === "suspended"
            ? "Your shop is currently suspended. You can review existing records here, but changes are switched off."
            : `Your shop is awaiting admin approval. You'll be able to ${unlocks} once it is approved.`}
        </Notice>
      )}

      <div className="mt-8">{children}</div>
    </Container>
  );
}
