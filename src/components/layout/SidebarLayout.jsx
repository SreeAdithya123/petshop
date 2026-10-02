import { NavLink } from "react-router-dom";
import { NestedContainerProvider } from "./Container";

/**
 * Page shell with a left sidebar (a horizontally scrolling tab strip on
 * small screens). Children render in the content column; any <Container>
 * inside automatically drops its own gutters/padding.
 *
 * items: [{ to, label, icon: PhosphorIcon, end?: boolean }]
 */
export function SidebarLayout({ heading, subheading, items, children }) {
  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8 lg:py-12">
      <div className="lg:grid lg:grid-cols-[250px_minmax(0,1fr)] lg:gap-10">
        <aside className="lg:sticky lg:top-[92px] lg:self-start">
          <div className="mb-4 hidden lg:block">
            <h2 className="font-display text-lg font-bold text-ink">{heading}</h2>
            {subheading && <p className="mt-0.5 truncate text-sm text-ink-soft">{subheading}</p>}
          </div>

          <nav
            aria-label={heading}
            className="scrollbar-none -mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:-mx-6 sm:px-6 lg:mx-0 lg:flex-col lg:gap-1 lg:overflow-visible lg:rounded-2xl lg:border lg:border-border lg:bg-surface lg:p-2 lg:pb-2"
          >
            {items.map(({ to, label, icon: Icon, end }) => (
              <NavLink
                key={to}
                to={to}
                end={end}
                className={({ isActive }) =>
                  `flex flex-none items-center gap-2.5 whitespace-nowrap rounded-full border px-4 py-2 text-sm transition-colors lg:rounded-xl lg:border-0 lg:px-3 lg:py-2.5 ${
                    isActive
                      ? "border-primary bg-primary text-white font-medium lg:bg-primary/10 lg:text-primary"
                      : "border-border bg-surface text-ink-soft hover:text-ink lg:bg-transparent lg:hover:bg-primary/5"
                  }`
                }
              >
                {Icon && <Icon size={18} className="flex-none" />}
                {label}
              </NavLink>
            ))}
          </nav>
        </aside>

        <div className="mt-6 min-w-0 lg:mt-0">
          <NestedContainerProvider value>{children}</NestedContainerProvider>
        </div>
      </div>
    </div>
  );
}
