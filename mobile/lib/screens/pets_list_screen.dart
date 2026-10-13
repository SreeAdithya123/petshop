import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../utils/pet_filters.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// Sort options in the order the web SortSelect lists them.
const _sortOptions = [
  (value: PetSort.newest, label: 'Just listed'),
  (value: PetSort.priceAsc, label: 'Price: low to high'),
  (value: PetSort.priceDesc, label: 'Price: high to low'),
  (value: PetSort.ageAsc, label: 'Age: youngest first'),
];

PetSort _sortFromParam(String? raw) {
  switch (raw) {
    case 'price-asc':
      return PetSort.priceAsc;
    case 'price-desc':
      return PetSort.priceDesc;
    case 'age-asc':
      return PetSort.ageAsc;
    default:
      return PetSort.newest;
  }
}

List<String> _listParam(Map<String, String> query, String key) {
  final raw = query[key];
  if (raw == null || raw.isEmpty) return const [];
  return raw.split(',').where((value) => value.isNotEmpty).toList();
}

/// Mirrors src/pages/PetsList.jsx: every available pet from the shared
/// catalog with species / breed / shop / price filters and a sort. The
/// species, breed, shop, minPrice, maxPrice and sort query parameters seed the
/// filters (the home screen links here with ?species= and ?breed=).
class PetsListScreen extends ConsumerStatefulWidget {
  const PetsListScreen({super.key});

  @override
  ConsumerState<PetsListScreen> createState() => _PetsListScreenState();
}

class _PetsListScreenState extends ConsumerState<PetsListScreen> {
  final Set<String> _species = {};
  final Set<String> _shopIds = {};
  final Set<String> _breeds = {};
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  PetSort _sort = PetSort.newest;
  bool _readInitialParams = false;

  // GoRouterState.of(context) depends on an InheritedWidget, which cannot be
  // read from initState() (it would throw in debug mode -- see
  // Element.dependOnInheritedElement's assertion). didChangeDependencies()
  // runs immediately after initState() and before the first build, so this
  // still seeds the filters exactly once before anything renders.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readInitialParams) return;
    _readInitialParams = true;
    final query = GoRouterState.of(context).uri.queryParameters;
    _species.addAll(_listParam(query, 'species'));
    _shopIds.addAll(_listParam(query, 'shop'));
    _breeds.addAll(_listParam(query, 'breed'));
    _minPriceController.text = query['minPrice'] ?? '';
    _maxPriceController.text = query['maxPrice'] ?? '';
    _sort = _sortFromParam(query['sort']);
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _species.isNotEmpty ||
      _shopIds.isNotEmpty ||
      _breeds.isNotEmpty ||
      _minPriceController.text.trim().isNotEmpty ||
      _maxPriceController.text.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _species.clear();
      _shopIds.clear();
      _breeds.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  List<Pet> _filteredPets(Catalog catalog) {
    final minPrice = double.tryParse(_minPriceController.text.trim());
    final maxPrice = double.tryParse(_maxPriceController.text.trim());
    final filtered = applyPetFilters(
      catalog.pets,
      PetFilterParams(
        species: _species.toList(),
        shops: _shopIds.toList(),
        breeds: _breeds.toList(),
        minPrice: minPrice,
        maxPrice: maxPrice,
      ),
    );
    return sortPets(filtered, _sort);
  }

  Future<void> _refresh() async {
    ref.invalidate(catalogProvider);
    try {
      await ref.read(catalogProvider.future).timeout(const Duration(seconds: 15));
    } catch (_) {
      // The screen renders the error state itself.
    }
  }

  void _openFilters(Catalog catalog) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return _FilterSheet(
          species: _species,
          shopIds: _shopIds,
          breeds: _breeds,
          speciesOptions: catalog.speciesList,
          breedOptions: catalog.breedList,
          shopOptions: catalog.shops,
          minPriceController: _minPriceController,
          maxPriceController: _maxPriceController,
          onChanged: () => setState(() {}),
          onClear: () {
            _clearFilters();
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final loading = catalogAsync.isLoading && !catalogAsync.hasValue;
    final failed = catalogAsync.hasError && !catalogAsync.isLoading;
    final catalog = failed ? null : catalogAsync.value;
    final pets = catalog == null ? const <Pet>[] : _filteredPets(catalog);

    final String subtitle;
    if (loading) {
      subtitle = 'Loading pets…';
    } else if (catalog == null) {
      subtitle = 'Pets from licensed local shops';
    } else {
      subtitle = '${pets.length} ${pets.length == 1 ? 'pet' : 'pets'} across every shop';
    }

    Widget body;
    if (loading) {
      body = const PetGridSkeleton(count: 6);
    } else if (failed || catalog == null) {
      body = _scrollableMessage(
        EmptyState(
          title: "We couldn't load pets",
          description: errorText(catalogAsync.error ?? 'Something went wrong.'),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(catalogProvider),
            child: const Text('Try again'),
          ),
        ),
      );
    } else if (catalog.pets.isEmpty) {
      body = _scrollableMessage(
        EmptyState(
          title: 'No pets listed right now',
          description: "Shops haven't listed any pets yet. Check back soon.",
          action: ElevatedButton(
            onPressed: () => context.push('/sellers'),
            child: const Text('Browse shops'),
          ),
        ),
      );
    } else if (pets.isEmpty) {
      body = _scrollableMessage(
        EmptyState(
          title: 'No pets match these filters',
          description: 'Try widening your price range or clearing a filter.',
          action: OutlinedButton(
            onPressed: _clearFilters,
            child: const Text('Clear filters'),
          ),
        ),
      );
    } else {
      body = GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        gridDelegate: kPetGridDelegate,
        itemCount: pets.length,
        itemBuilder: (context, index) {
          final pet = pets[index];
          return PetCard(pet: pet, shopName: catalog.shopById(pet.shopId)?.name);
        },
      );
    }

    return RoleShell(
      title: 'Shop pets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop pets', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(subtitle, style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: catalog == null ? null : () => _openFilters(catalog),
                      icon: Icon(
                        Icons.filter_list,
                        size: 18,
                        color: _hasActiveFilters ? AppColors.primary : AppColors.ink,
                      ),
                      label: Text(_hasActiveFilters ? 'Filters •' : 'Filters'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SortDropdown(
                        value: _sort,
                        onChanged: (value) => setState(() => _sort = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: loading ? body : RefreshIndicator(onRefresh: _refresh, child: body),
          ),
        ],
      ),
    );
  }

  /// Wraps a state message so pull-to-refresh still works on it.
  Widget _scrollableMessage(Widget message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: kScreenPadding,
      children: [message],
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final PetSort value;
  final ValueChanged<PetSort> onChanged;
  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PetSort>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: AppTheme.body(fontSize: 14),
          items: [
            for (final option in _sortOptions)
              DropdownMenuItem(value: option.value, child: Text(option.label, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Filter panel shown as a modal bottom sheet on mobile, mirroring
/// src/components/ui/FilterSidebar.jsx's species/breed/shop checkbox
/// groups + min/max price fields + "Clear all" action.
class _FilterSheet extends StatefulWidget {
  final Set<String> species;
  final Set<String> shopIds;
  final Set<String> breeds;
  final List<String> speciesOptions;
  final List<String> breedOptions;
  final List<Shop> shopOptions;
  final TextEditingController minPriceController;
  final TextEditingController maxPriceController;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.species,
    required this.shopIds,
    required this.breeds,
    required this.speciesOptions,
    required this.breedOptions,
    required this.shopOptions,
    required this.minPriceController,
    required this.maxPriceController,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  bool get _hasActiveFilters =>
      widget.species.isNotEmpty ||
      widget.shopIds.isNotEmpty ||
      widget.breeds.isNotEmpty ||
      widget.minPriceController.text.trim().isNotEmpty ||
      widget.maxPriceController.text.trim().isNotEmpty;

  void _toggle(Set<String> set, String value) {
    setState(() {
      if (!set.remove(value)) set.add(value);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + keyboardInset),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600)),
                  if (_hasActiveFilters)
                    TextButton(onPressed: widget.onClear, child: const Text('Clear all')),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.speciesOptions.isNotEmpty)
                _FilterSection(
                  legend: 'Species',
                  children: [
                    for (final value in widget.speciesOptions)
                      _FilterChip(
                        label: value,
                        selected: widget.species.contains(value),
                        onTap: () => _toggle(widget.species, value),
                      ),
                  ],
                ),
              if (widget.breedOptions.isNotEmpty)
                _FilterSection(
                  legend: 'Breed',
                  children: [
                    for (final value in widget.breedOptions)
                      _FilterChip(
                        label: value,
                        selected: widget.breeds.contains(value),
                        onTap: () => _toggle(widget.breeds, value),
                      ),
                  ],
                ),
              if (widget.shopOptions.isNotEmpty)
                _FilterSection(
                  legend: 'Shop',
                  children: [
                    for (final shop in widget.shopOptions)
                      _FilterChip(
                        label: shop.name,
                        selected: widget.shopIds.contains(shop.id),
                        onTap: () => _toggle(widget.shopIds, shop.id),
                      ),
                  ],
                ),
              const Divider(height: 32, color: AppColors.border),
              Text('Price range', style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PriceField(
                      label: 'Min (₹)',
                      hint: '₹0',
                      controller: widget.minPriceController,
                      onChanged: () {
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PriceField(
                      label: 'Max (₹)',
                      hint: '₹50,000',
                      controller: widget.maxPriceController,
                      onChanged: () {
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Show results'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PriceField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _PriceField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          decoration: InputDecoration(hintText: hint),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String legend;
  final List<Widget> children;
  const _FilterSection({required this.legend, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(legend, style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: AppTheme.body(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: selected ? Colors.white : AppColors.ink,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
