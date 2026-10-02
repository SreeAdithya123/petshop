/**
 * Underlined tab strip with optional count badges and arrow-key navigation.
 * tabs: [{ value, label, count?, countLabel?, attention? }]. A badge turns
 * accent-coloured when `attention` is set and the count is above zero.
 * Pair each tab with a <TabPanel> using the same idPrefix.
 */
export function Tabs({ tabs, value, onChange, label, idPrefix = "tab" }) {
  function handleKeyDown(event) {
    const index = tabs.findIndex((tab) => tab.value === value);
    let next = null;
    if (event.key === "ArrowRight") next = tabs[(index + 1) % tabs.length];
    if (event.key === "ArrowLeft") next = tabs[(index - 1 + tabs.length) % tabs.length];
    if (!next) return;
    event.preventDefault();
    onChange(next.value);
    document.getElementById(`${idPrefix}-${next.value}`)?.focus();
  }

  return (
    <div
      role="tablist"
      aria-label={label}
      onKeyDown={handleKeyDown}
      className="scrollbar-none flex gap-1 overflow-x-auto border-b border-border"
    >
      {tabs.map((tab) => {
        const active = tab.value === value;
        const highlighted = tab.attention && tab.count > 0;
        return (
          <button
            key={tab.value}
            id={`${idPrefix}-${tab.value}`}
            type="button"
            role="tab"
            aria-selected={active}
            aria-controls={`${idPrefix}-panel-${tab.value}`}
            tabIndex={active ? 0 : -1}
            onClick={() => onChange(tab.value)}
            className={`-mb-px flex flex-none items-center gap-2 whitespace-nowrap border-b-2 px-4 py-3 text-sm font-medium transition-colors ${
              active ? "border-primary text-primary" : "border-transparent text-ink-soft hover:text-ink"
            }`}
          >
            {tab.label}
            {tab.count != null && (
              <span
                className={`rounded-full px-2 py-0.5 text-xs ${
                  highlighted ? "bg-accent text-white" : "bg-ink/5 text-ink-soft"
                }`}
              >
                {tab.count}
                {tab.countLabel && <span className="sr-only"> {tab.countLabel}</span>}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

export function TabPanel({ value, idPrefix = "tab", children }) {
  return (
    <div role="tabpanel" id={`${idPrefix}-panel-${value}`} aria-labelledby={`${idPrefix}-${value}`} className="mt-6">
      {children}
    </div>
  );
}
