import { X } from "@phosphor-icons/react";
import { breedList, speciesList } from "../../data/pets";
import { shops } from "../../data/shops";

function CheckboxGroup({ legend, options, selected, onToggle }) {
  return (
    <fieldset className="border-t border-border py-6 first:border-t-0 first:pt-0">
      <legend className="text-[15px] font-medium text-ink">{legend}</legend>
      <div className="mt-3 flex flex-col gap-2.5">
        {options.map((option) => (
          <label key={option.value} className="flex items-center gap-2.5 text-sm text-ink">
            <input
              type="checkbox"
              checked={selected.includes(option.value)}
              onChange={() => onToggle(option.value)}
              className="h-4 w-4 rounded border-border accent-primary"
            />
            {option.label}
          </label>
        ))}
      </div>
    </fieldset>
  );
}

export function FilterSidebar({
  species,
  shopIds,
  breeds,
  minPrice,
  maxPrice,
  onToggleSpecies,
  onToggleShop,
  onToggleBreed,
  onPriceChange,
  onClear,
  open,
  onClose,
  hasActiveFilters,
}) {
  return (
    <>
      {open && (
        <button
          type="button"
          aria-label="Close filters"
          onClick={onClose}
          className="fixed inset-0 z-40 bg-ink/40 lg:hidden"
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-50 w-[86%] max-w-xs overflow-y-auto bg-surface px-6 pb-8 pt-5 shadow-2xl transition-transform duration-200 lg:sticky lg:top-[88px] lg:z-auto lg:w-full lg:max-w-none lg:translate-x-0 lg:self-start lg:bg-transparent lg:px-0 lg:pb-0 lg:pt-0 lg:shadow-none lg:transition-none ${
          open ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="mb-4 flex items-center justify-between lg:hidden">
          <h2 className="font-display text-lg font-semibold text-ink">Filters</h2>
          <button type="button" onClick={onClose} aria-label="Close filters" className="text-ink-soft">
            <X size={22} />
          </button>
        </div>

        <div className="flex items-center justify-between">
          <h2 className="hidden font-display text-lg font-semibold text-ink lg:block">Filters</h2>
          {hasActiveFilters && (
            <button type="button" onClick={onClear} className="text-sm text-primary hover:opacity-80">
              Clear all
            </button>
          )}
        </div>

        <CheckboxGroup
          legend="Species"
          options={speciesList.map((value) => ({ value, label: value }))}
          selected={species}
          onToggle={onToggleSpecies}
        />
        <CheckboxGroup
          legend="Breed"
          options={breedList.map((value) => ({ value, label: value }))}
          selected={breeds}
          onToggle={onToggleBreed}
        />
        <CheckboxGroup
          legend="Shop"
          options={shops.map((shop) => ({ value: shop.id, label: shop.name }))}
          selected={shopIds}
          onToggle={onToggleShop}
        />

        <fieldset className="border-t border-border py-6">
          <legend className="text-[15px] font-medium text-ink">Price range</legend>
          <div className="mt-3 flex items-center gap-3">
            <div className="flex-1">
              <label htmlFor="minPrice" className="block text-xs text-ink-soft">
                Min
              </label>
              <input
                id="minPrice"
                type="number"
                inputMode="numeric"
                min="0"
                placeholder="$0"
                value={minPrice}
                onChange={(event) => onPriceChange("minPrice", event.target.value)}
                className="mt-1 w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm text-ink placeholder:text-ink-soft/60 focus:border-primary focus:outline-none"
              />
            </div>
            <div className="flex-1">
              <label htmlFor="maxPrice" className="block text-xs text-ink-soft">
                Max
              </label>
              <input
                id="maxPrice"
                type="number"
                inputMode="numeric"
                min="0"
                placeholder="$1000"
                value={maxPrice}
                onChange={(event) => onPriceChange("maxPrice", event.target.value)}
                className="mt-1 w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm text-ink placeholder:text-ink-soft/60 focus:border-primary focus:outline-none"
              />
            </div>
          </div>
        </fieldset>
      </aside>
    </>
  );
}
