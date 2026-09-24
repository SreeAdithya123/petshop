import { Container } from "../components/layout/Container";
import { ShopCard } from "../components/ui/ShopCard";
import { shops } from "../data/shops";

export function Shops() {
  return (
    <Container className="py-12">
      <h1 className="font-display text-3xl font-semibold text-ink md:text-4xl">Shops</h1>
      <p className="mt-2 text-ink-soft">
        Browse licensed local pet shops and see what they currently have available.
      </p>

      <div className="mt-8 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {shops.map((shop) => (
          <ShopCard key={shop.id} shop={shop} />
        ))}
      </div>
    </Container>
  );
}
