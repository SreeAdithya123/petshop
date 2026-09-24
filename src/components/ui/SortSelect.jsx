const options = [
  { value: "newest", label: "Just listed" },
  { value: "price-asc", label: "Price: low to high" },
  { value: "price-desc", label: "Price: high to low" },
];

export function SortSelect({ value, onChange }) {
  return (
    <div className="flex items-center gap-2">
      <label htmlFor="sort" className="text-sm text-ink-soft">
        Sort
      </label>
      <select
        id="sort"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="rounded-lg border border-border bg-surface px-3 py-2 text-sm text-ink focus:border-primary focus:outline-none"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </div>
  );
}
