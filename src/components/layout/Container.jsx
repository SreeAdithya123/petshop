import { createContext, useContext } from "react";

const NestedContainerContext = createContext(false);

/**
 * Wrap content that already lives inside a page shell (e.g. a sidebar
 * layout) so any <Container> rendered by a page drops its own max-width,
 * horizontal gutters and vertical page padding instead of doubling them up.
 */
export const NestedContainerProvider = NestedContainerContext.Provider;

const PAGE_VERTICAL_PADDING = /(?:^|\s)(?:(?:sm|md|lg|xl):)?py-\d+(?=\s|$)/g;

export function Container({ className = "", children }) {
  const nested = useContext(NestedContainerContext);
  if (nested) {
    return <div className={className.replace(PAGE_VERTICAL_PADDING, " ").trim()}>{children}</div>;
  }
  return <div className={`mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 ${className}`}>{children}</div>;
}
