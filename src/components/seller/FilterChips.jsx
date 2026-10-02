/** Pill filters with a count each. options: [{ value, label, count }] */
export function FilterChips({ options, value, onChange, label }) {
  return (
    <div role="group" aria-label={label} className="flex flex-wrap gap-2">
      {options.map((option) => {
        const active = option.value === value;
        return (
          <button
            key={option.value}
            type="button"
            aria-pressed={active}
            onClick={() => onChange(option.value)}
            className={`inline-flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-sm transition-colors ${
              active
                ? "border-primary bg-primary font-medium text-white"
                : "border-border bg-surface text-ink-soft hover:text-ink"
            }`}
          >
            {option.label}
            <span className={`text-xs ${active ? "text-white/80" : "text-ink-soft"}`}>{option.count}</span>
          </button>
        );
      })}
    </div>
  );
}
