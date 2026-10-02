import { LoginPrompt } from "../ui/LoginPrompt";
import { BookingList } from "./BookingList";
import { RequestList } from "./RequestList";

function TabButton({ active, onClick, children }) {
  return (
    <button
      type="button"
      aria-pressed={active}
      onClick={onClick}
      className={`rounded-md px-4 py-2 text-sm font-medium transition-colors ${
        active ? "bg-primary text-white" : "text-ink hover:bg-primary/5"
      }`}
    >
      {children}
    </button>
  );
}

/**
 * "My bookings & requests" at the bottom of /services (anchor #my-bookings).
 * `bookings` / `requests` are the useServiceBookings / useCustomRequests results.
 */
export function MyServicesSection({ access, bookings, requests, tab, onTabChange }) {
  // Sellers and admins don't book services, so they get no section at all.
  if (access.status === "loading" || (access.session && !access.canBook)) return null;

  return (
    <section id="my-bookings" aria-labelledby="my-bookings-heading" className="mt-14 scroll-mt-24">
      <h2 id="my-bookings-heading" className="font-display text-2xl font-bold text-ink">
        My bookings &amp; requests
      </h2>
      <p className="mt-1 text-sm text-ink-soft">Track the slots you've booked and the quotes on your custom requests.</p>

      {!access.session ? (
        <div className="mt-5 rounded-xl border border-border bg-surface p-5">
          <LoginPrompt compact description="to see your bookings and custom requests." />
        </div>
      ) : (
        <>
          <div role="group" aria-label="Show" className="mt-5 inline-flex gap-1 rounded-lg border border-border bg-surface p-1">
            <TabButton active={tab === "bookings"} onClick={() => onTabChange("bookings")}>
              Bookings{!bookings.loading && ` (${bookings.bookings.length})`}
            </TabButton>
            <TabButton active={tab === "requests"} onClick={() => onTabChange("requests")}>
              Custom requests{!requests.loading && ` (${requests.requests.length})`}
            </TabButton>
          </div>

          <div className="mt-4">
            {tab === "bookings" ? (
              <BookingList state={bookings} emptyMessage="No bookings yet — pick a service above to book your first slot." />
            ) : (
              <RequestList state={requests} emptyMessage="No custom requests yet — describe what you need and shops will quote." />
            )}
          </div>
        </>
      )}
    </section>
  );
}
