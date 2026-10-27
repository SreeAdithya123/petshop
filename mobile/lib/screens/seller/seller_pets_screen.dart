import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/photo_upload.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pet_widgets.dart';
import '../../widgets/photos/photo_picker_field.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

/// Ports src/pages/seller/Pets.jsx: a shop owner's own pet listings with an
/// Add / Edit form (name, gender, species, breed, age, price, photos...) in a
/// bottom sheet and per-row Mark sold / Mark available / Edit / Delete actions.
class SellerPetsScreen extends StatelessWidget {
  const SellerPetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Pets',
      subtitle: 'Your pet listings.',
      builder: (context, shop) => _PetsWorkspace(shop: shop),
    );
  }
}

const _filters = <StatusFilter>[
  StatusFilter('all', 'All'),
  StatusFilter('available', 'Available'),
  StatusFilter('reserved', 'Reserved'),
  StatusFilter('sold', 'Sold'),
];

const _statusLabels = {'available': 'Available', 'reserved': 'Reserved', 'sold': 'Sold'};

String _statusOf(Pet pet) => pet.status;

Future<List<Pet>> _fetchPets(String shopId) async {
  final rows = await fetchAllRows(() => SupabaseService.client.from('pets').select().eq('shop_id', shopId));
  final pets = rows.map(Pet.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return pets;
}

class _PetsWorkspace extends ConsumerStatefulWidget {
  final Shop shop;
  const _PetsWorkspace({required this.shop});

  @override
  ConsumerState<_PetsWorkspace> createState() => _PetsWorkspaceState();
}

class _PetsWorkspaceState extends ConsumerState<_PetsWorkspace> {
  late final SellerQuery<List<Pet>> _query;
  String _filter = 'all';
  int _limit = kPageSize;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    final shopId = widget.shop.id;
    _query = SellerQuery<List<Pet>>(() => _fetchPets(shopId));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _openForm([Pet? pet]) async {
    final saved = await showFormSheet<bool>(
      context,
      title: pet == null ? 'Add a pet' : 'Edit pet',
      description: pet == null ? 'Customers can reserve it once your shop is approved.' : null,
      builder: (sheetContext) => _PetForm(shopId: widget.shop.id, pet: pet),
    );
    if (saved != true || !mounted) return;
    showSnack(context, pet == null ? 'Pet added.' : 'Pet updated.');
    _query.reload();
  }

  Future<void> _setStatus(Pet pet, String status) async {
    if (_busyId != null) return;
    final selling = status == 'sold';
    final confirmed = await confirmAction(
      context,
      title: selling ? 'Mark ${pet.displayName} as sold?' : 'Make ${pet.displayName} available again?',
      message: selling
          ? 'It will no longer be offered to customers.'
          : 'The reservation stops holding this pet and customers can reserve it again. '
              'To release a specific customer\'s reservation, cancel their order from Orders instead.',
      confirmLabel: selling ? 'Mark sold' : 'Make available',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = pet.id);
    // Guard on the status the card showed so a newer change isn't overwritten.
    final failure = await updateRow('pets', pet.id, {'status': status}, match: {'status': pet.status});
    if (!mounted) return;
    setState(() => _busyId = null);

    if (failure != null) {
      showSnack(context, failure, error: true);
      // A reservation or sale may have changed the pet meanwhile: show its real state.
      if (failure == kNothingChanged) _query.reload();
      return;
    }
    showSnack(context, selling ? 'Marked as sold.' : 'Marked as available.');
    _query.reload();
  }

  Future<void> _delete(Pet pet) async {
    if (_busyId != null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this listing?',
      message: '${pet.displayName} will be removed from your shop. This can\'t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = pet.id);
    final failure = await deleteRow('pets', pet.id);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (failure != null) {
      showSnack(context, failure, error: true);
      return;
    }
    showSnack(context, 'Listing deleted.');
    _query.reload();
  }

  @override
  Widget build(BuildContext context) {
    listenForShopRefresh(ref, _query.reload);
    final readOnly = widget.shop.status == 'suspended';

    return SellerQueryPanel<List<Pet>>(
      query: _query,
      what: 'your pets',
      builder: (context, pets) {
        final visible = applyStatusFilter(_filters, _filter, pets, _statusOf);
        final shown = math.min(_limit, visible.length);
        final addButton = ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a pet'),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!readOnly && pets.isNotEmpty) ...[
              Align(alignment: Alignment.centerLeft, child: addButton),
              const SizedBox(height: 16),
            ],
            if (pets.isNotEmpty) ...[
              FilterChipBar<String>(
                options: filterOptions(_filters, pets, _statusOf),
                selected: _filter,
                onSelected: (value) => setState(() {
                  _filter = value;
                  _limit = kPageSize;
                }),
              ),
              const SizedBox(height: 16),
            ],
            if (pets.isEmpty)
              CardBox(
                child: EmptyState(
                  title: 'No pets listed yet',
                  description: 'Add your first pet to start reaching customers.',
                  action: readOnly ? null : addButton,
                ),
              )
            else if (visible.isEmpty)
              const CardBox(
                child: EmptyState(title: 'Nothing here', description: 'No pets match this filter.'),
              )
            else ...[
              for (final pet in visible.take(shown))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PetCard(
                    key: ValueKey(pet.id),
                    pet: pet,
                    readOnly: readOnly,
                    busy: _busyId == pet.id,
                    onMarkSold: () => _setStatus(pet, 'sold'),
                    onMarkAvailable: () => _setStatus(pet, 'available'),
                    onEdit: () => _openForm(pet),
                    onDelete: () => _delete(pet),
                  ),
                ),
              LoadMoreButton(
                shown: shown,
                total: visible.length,
                onPressed: () => setState(() => _limit += kPageSize),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;
  final bool readOnly;
  final bool busy;
  final VoidCallback onMarkSold;
  final VoidCallback onMarkAvailable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PetCard({
    super.key,
    required this.pet,
    required this.readOnly,
    required this.busy,
    required this.onMarkSold,
    required this.onMarkAvailable,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = (pet.name ?? '').trim();
    final breedLine = pet.breed.isNotEmpty ? '${pet.breed} (${pet.species})' : pet.species;
    final detail = [
      if (pet.gender != null && pet.gender!.isNotEmpty) pet.gender!,
      formatAge(pet.ageMonths),
    ].where((part) => part.isNotEmpty).join(' · ');
    final title = name.isNotEmpty ? name : breedLine;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: PetPhotoView(
                    src: pet.photoUrls.isNotEmpty ? pet.photoUrls.first : null,
                    species: pet.species,
                    cacheWidth: 112,
                    semanticLabel: 'Photo of $title',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (name.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        breedLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                      ),
                    ],
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(detail, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: pet.status, label: _statusLabels[pet.status] ?? titleCase(pet.status)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatPrice(pet.price),
            style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.accent),
          ),
          if (pet.status == 'reserved') ...[
            const SizedBox(height: 8),
            Text(
              'A customer has reserved this pet. Mark their order paid or handed over, or cancel it, from Orders.',
              style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/seller/orders'),
                child: const Text('Go to Orders'),
              ),
            ),
          ],
          if (!readOnly) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (pet.status == 'available')
                  OutlinedButton(
                    onPressed: busy ? null : onMarkSold,
                    child: const Text('Mark sold'),
                  ),
                if (pet.status == 'reserved')
                  OutlinedButton(
                    onPressed: busy ? null : onMarkAvailable,
                    child: const Text('Mark available'),
                  ),
                TextButton(
                  onPressed: busy ? null : onEdit,
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: busy ? null : onDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Delete'),
                ),
                if (busy)
                  Semantics(
                    label: 'Saving',
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Add / edit form shown in a bottom sheet. Pops with `true` once saved.
class _PetForm extends StatefulWidget {
  final String shopId;
  final Pet? pet;
  const _PetForm({required this.shopId, this.pet});

  @override
  State<_PetForm> createState() => _PetFormState();
}

class _PetFormState extends State<_PetForm> {
  late final TextEditingController _name;
  late final TextEditingController _species;
  late final TextEditingController _breed;
  late final TextEditingController _age;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final ListingPhotoTracker _photoTracker;
  late List<String> _photoUrls;
  late String _gender; // '' = Unknown (stored as null)

  String? _nameError;
  String? _speciesError;
  String? _breedError;
  String? _ageError;
  String? _priceError;
  String? _formError;
  bool _submitting = false;
  bool _photosBusy = false;

  bool get _editing => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    _name = TextEditingController(text: pet?.name ?? '');
    _species = TextEditingController(text: pet?.species ?? '');
    _breed = TextEditingController(text: pet?.breed ?? '');
    _age = TextEditingController(text: pet == null ? '' : '${pet.ageMonths}');
    _price = TextEditingController(text: pet == null ? '' : plainNumber(pet.price));
    _description = TextEditingController(text: pet?.description ?? '');
    _photoUrls = List<String>.of(pet?.photoUrls ?? const <String>[]);
    _photoTracker = ListingPhotoTracker(_photoUrls);
    final gender = pet?.gender;
    _gender = (gender == 'Male' || gender == 'Female') ? gender! : '';
  }

  @override
  void dispose() {
    // Closed without saving: photos uploaded during this edit are not needed.
    _photoTracker.discard(_photoUrls);
    _name.dispose();
    _species.dispose();
    _breed.dispose();
    _age.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  bool _validate() {
    String? nameError;
    String? speciesError;
    String? breedError;
    String? ageError;
    String? priceError;

    if (_name.text.trim().isEmpty) nameError = 'Enter a name for this pet.';
    if (_species.text.trim().isEmpty) speciesError = 'Enter a species, like Dog or Cat.';
    if (_breed.text.trim().isEmpty) breedError = 'Enter a breed.';

    final ageText = _age.text.trim();
    final months = int.tryParse(ageText);
    if (ageText.isEmpty) {
      ageError = "Enter the pet's age in months.";
    } else if (months == null || months < 0 || months > 600) {
      ageError = 'Enter a whole number of months (0 to 600).';
    }

    final priceText = _price.text.trim();
    final price = parseAmount(priceText);
    if (priceText.isEmpty) {
      priceError = 'Enter a price.';
    } else if (price == null || price <= 0) {
      priceError = 'Price must be greater than zero.';
    }

    setState(() {
      _nameError = nameError;
      _speciesError = speciesError;
      _breedError = breedError;
      _ageError = ageError;
      _priceError = priceError;
    });
    return nameError == null && speciesError == null && breedError == null && ageError == null && priceError == null;
  }

  Future<void> _submit() async {
    if (_submitting || _photosBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    if (!_validate()) return;

    final description = _description.text.trim();
    final photoUrls = List<String>.of(_photoUrls);
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'gender': _gender.isEmpty ? null : _gender,
      'species': _species.text.trim(),
      'breed': _breed.text.trim(),
      'age_months': int.parse(_age.text.trim()),
      'price': parseAmount(_price.text)!,
      'description': description.isEmpty ? null : description,
      'photo_urls': photoUrls,
    };

    setState(() => _submitting = true);
    _photoTracker.saveStarted();
    final pet = widget.pet;
    // The database forces the shop, status and any seller-protected columns.
    final failure = pet == null
        ? await insertRow('pets', {'shop_id': widget.shopId, ...payload})
        : await updateRow('pets', pet.id, payload);
    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _submitting = false;
        _formError = failure;
      });
      return;
    }
    _photoTracker.saveSucceeded(photoUrls);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_submitting;
    return PopScope(
      canPop: !_submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            decoration: InputDecoration(labelText: 'Name', errorText: _nameError, errorMaxLines: 2),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Unknown')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
            onChanged: enabled ? (value) => setState(() => _gender = value ?? '') : null,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _species,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            decoration: InputDecoration(labelText: 'Species', errorText: _speciesError, errorMaxLines: 2),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _breed,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            decoration: InputDecoration(labelText: 'Breed', errorText: _breedError, errorMaxLines: 2),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _age,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: InputDecoration(labelText: 'Age (months)', errorText: _ageError, errorMaxLines: 2),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _price,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: 'Price (INR)',
              prefixText: '₹ ',
              errorText: _priceError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
          ),
          const SizedBox(height: 14),
          PhotoPickerField(
            shopId: widget.shopId,
            kind: 'pets',
            label: 'Photos',
            urls: _photoUrls,
            enabled: enabled,
            onChanged: (urls) => setState(() => _photoUrls = urls),
            onBusyChanged: (busy) => setState(() => _photosBusy = busy),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 14),
            NoticeBox.error(message: _formError!),
          ],
          const SizedBox(height: 20),
          LoadingButton(
            label: _editing ? 'Save changes' : 'Add pet',
            loading: _submitting,
            expand: true,
            onPressed: _photosBusy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
