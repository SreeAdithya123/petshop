# Paws Nearby

Frontend for a multi-vendor pet marketplace: browse pets across every
licensed local pet shop, add them to a cart, and check out. There's no
shipping — checkout ends on an order-placed confirmation, and pickup plus
final payment happen in person at each pet's shop.

This is the frontend/UI layer only. There is no backend, payment provider,
or auth: pet and shop data is seeded in `src/data/`, and the cart/wishlist
live in a Zustand store persisted to `localStorage` (`src/store/cartStore.js`).
See [`docs/decisions.md`](docs/decisions.md) for notable implementation
decisions, the image-sourcing approach, and workarounds.

## Stack

Vite + React 19, Tailwind CSS v4, React Router v6, Zustand.

## Getting started

```bash
npm install
npm run dev
```

Other scripts: `npm run build`, `npm run lint`, `npm run preview`.

If a production build fails with a memory-allocation error on Windows,
it's very likely the `%TEMP%` drive being near-full, not the app — check
free space and, if needed, point `TEMP`/`TMP` at a drive with room before
building.
