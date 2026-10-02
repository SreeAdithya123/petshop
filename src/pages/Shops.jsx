import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { ShopCard, ShopCardSkeleton } from "../components/ui/ShopCard";
import { useCatalog } from "../store/catalogStore";

const GRID_CLASS = "mt-8 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3";

export function Shops() {
  const { shops, loading, error, reload } = useCatalog();

  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-semibold text-ink md:text-4xl">Shops</h1>
      <p className="mt-2 text-ink-soft">
        Browse licensed local pet shops and see what they currently have available.
      </p>

      {loading ? (
        <div className={GRID_CLASS} role="status" aria-label="Loading shops">
          {Array.from({ length: 6 }).map((_, index) => (
            <ShopCardSkeleton key={index} />
          ))}
        </div>
      ) : error ? (
        <EmptyState
          title="We couldn't load shops"
          description={error}
          action={
            <Button size="sm" onClick={reload}>
              Try again
            </Button>
          }
        />
      ) : shops.length === 0 ? (
        <EmptyState
          title="No shops yet"
          description="Licensed shops will appear here once they're approved. Check back soon."
          action={
            <Button to="/pets" size="sm">
              Browse pets
            </Button>
          }
        />
      ) : (
        <div className={GRID_CLASS}>
          {shops.map((shop) => (
            <ShopCard key={shop.id} shop={shop} />
          ))}
        </div>
      )}
    </Container>
  );
}
