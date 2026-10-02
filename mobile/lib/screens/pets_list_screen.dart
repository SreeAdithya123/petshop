import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/seed_data.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/PetsList.jsx.
class PetsListScreen extends StatefulWidget {
  const PetsListScreen({super.key});

  @override
  State<PetsListScreen> createState() => _PetsListScreenState();
}

class _PetsListScreenState extends State<PetsListScreen> {
  final Set<String> _species = {};
  final Set<String> _shopIds = {};
  final Set<String> _breeds = {};
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  PetSort _sort = PetSort.newest;
  bool _readInitialSpecies = false;

  // GoRouterState.of(context) depends on an InheritedWidget, which cannot be
  // read from initState() (it would throw in debug mode -- see
  // Element.dependOnInheritedElement's assertion). didChangeDependencies()
  // runs immediately after initState() and before the first build, so this
  // still seeds the filter exactly once before anything renders.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readInitialSpecies) return;
    _readInitialSpecies = true;
    final initialSpecies = GoRouterState.of(
      context,
    ).uri.queryParameters['species'];
    if (initialSpecies != null && initialSpecies.isNotEmpty) {
      _species.add(initialSpecies);
    }
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
      _sort = PetSort.newest;
    });
  }

  List<SeedPet> get _filteredPets {
    final minPrice = double.tryParse(_minPriceController.text.trim());
    final maxPrice = double.tryParse(_maxPriceController.text.trim());
    final filtered = applyPetFilters(
      seedPets,
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

  void _openFilters() {
    showModalBottomSheet(
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
          minPriceController: _minPriceController,
          maxPriceController: _maxPriceController,
          hasActiveFilters: _hasActiveFilters,
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
    final pets = _filteredPets;

    return RoleShell(
      title: 'Shop pets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop pets',
                  style: AppTheme.display(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${pets.length} ${pets.length == 1 ? 'pet' : 'pets'} across every shop',
                  style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openFilters,
                      icon: Icon(
                        Icons.filter_list,
                        size: 18,
                        color: _hasActiveFilters
                            ? AppColors.primary
                            : AppColors.ink,
                      ),
                      label: Text(_hasActiveFilters ? 'Filters •' : 'Filters'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
            child: pets.isEmpty
                ? Padding(
                    padding: kScreenPadding,
                    child: EmptyState(
                      title: 'No pets match these filters',
                      description:
                          'Try widening your price range or clearing a filter.',
                      action: OutlinedButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters'),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.66,
                        ),
                    itemCount: pets.length,
                    itemBuilder: (context, index) =>
                        _PetGridCard(pet: pets[index]),
                  ),
          ),
        ],
      ),
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
          items: const [
            DropdownMenuItem(value: PetSort.newest, child: Text('Newest')),
            DropdownMenuItem(
              value: PetSort.priceAsc,
              child: Text('Price: low to high'),
            ),
            DropdownMenuItem(
              value: PetSort.priceDesc,
              child: Text('Price: high to low'),
            ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _PetGridCard extends StatelessWidget {
  final SeedPet pet;
  const _PetGridCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final isSold = pet.status == 'sold';
    return InkWell(
      onTap: () => context.push('/pets/${pet.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: isSold ? 0.5 : 1,
                    child: PetPhotoView(
                      src: pet.photos?.isNotEmpty == true
                          ? pet.photos!.first
                          : null,
                      species: pet.species,
                    ),
                  ),
                  if (isSold)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Sold',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: AppTheme.body(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pet.species} · ${pet.breed}',
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(pet.price),
                    style: AppTheme.display(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
  final TextEditingController minPriceController;
  final TextEditingController maxPriceController;
  final bool hasActiveFilters;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.species,
    required this.shopIds,
    required this.breeds,
    required this.minPriceController,
    required this.maxPriceController,
    required this.hasActiveFilters,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  void _toggle(Set<String> set, String value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: AppTheme.display(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.hasActiveFilters)
                    TextButton(
                      onPressed: widget.onClear,
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _FilterSection(
                legend: 'Species',
                children: speciesList
                    .map(
                      (value) => _FilterChip(
                        label: value,
                        selected: widget.species.contains(value),
                        onTap: () => _toggle(widget.species, value),
                      ),
                    )
                    .toList(),
              ),
              _FilterSection(
                legend: 'Breed',
                children: breedList
                    .map(
                      (value) => _FilterChip(
                        label: value,
                        selected: widget.breeds.contains(value),
                        onTap: () => _toggle(widget.breeds, value),
                      ),
                    )
                    .toList(),
              ),
              _FilterSection(
                legend: 'Shop',
                children: seedShops
                    .map(
                      (shop) => _FilterChip(
                        label: shop.name,
                        selected: widget.shopIds.contains(shop.id),
                        onTap: () => _toggle(widget.shopIds, shop.id),
                      ),
                    )
                    .toList(),
              ),
              const Divider(height: 32, color: AppColors.border),
              Text(
                'Price range',
                style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Min',
                          style: AppTheme.body(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: widget.minPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: false,
                          ),
                          decoration: const InputDecoration(hintText: r'$0'),
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Max',
                          style: AppTheme.body(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: widget.maxPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: false,
                          ),
                          decoration: const InputDecoration(hintText: r'$1000'),
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ],
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
          Text(
            legend,
            style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500),
          ),
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
