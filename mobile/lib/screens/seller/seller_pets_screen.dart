import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../services/supabase_service.dart';
import '../../state/my_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pet_widgets.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

const _notApplied = "That didn't go through — its status may have changed.";

/// Ports src/pages/seller/Pets.jsx: a shop owner's own pet listings with an
/// Add / Edit form (name, gender, species, breed, age, price...) in a bottom
/// sheet and per-row Mark sold / Mark available / Edit / Delete actions.
class SellerPetsScreen extends ConsumerWidget {
  const SellerPetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return RoleShell(
      title: 'Pets',
      child: shopAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => _LoadFailure(
          message: "Couldn't load your shop: ${errorText(error)}",
          onRetry: () => ref.invalidate(myShopProvider),
        ),
        data: (shop) {
          if (shop == null) {
            return Padding(
              padding: kScreenPadding,
              child: EmptyState(
                title: "You haven't set up your shop yet",
                description: 'Create your shop profile to start listing pets and products.',
                action: ElevatedButton(
                  onPressed: () => context.push('/seller/store'),
                  child: const Text('Set up your shop'),
                ),
              ),
            );
          }
          return _PetsView(shop: shop);
        },
      ),
    );
  }
}

class _PetsView extends StatefulWidget {
  final Shop shop;
  const _PetsView({required this.shop});

  @override
  State<_PetsView> createState() => _PetsViewState();
}

class _PetsViewState extends State<_PetsView> {
  List<Pet> _pets = const [];
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pets = await PetsRepository().listByShop(widget.shop.id);
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _loaded = true;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_loaded) {
        // Keep showing the list we already have; just say the refresh failed.
        showSnack(context, errorText(e), error: true);
      } else {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  Future<void> _openForm([Pet? pet]) async {
    final saved = await showFormSheet<bool>(
      context,
      title: pet == null ? 'Add a pet' : 'Edit pet',
      builder: (sheetContext) => _PetForm(shopId: widget.shop.id, pet: pet),
    );
    if (saved != true || !mounted) return;
    showSnack(context, pet == null ? 'Pet added.' : 'Pet updated.');
    await _load();
  }

  Future<void> _changeStatus(Pet pet, String status) async {
    setState(() => _busyId = pet.id);
    try {
      final rows = await SupabaseService.client.from('pets').update({'status': status}).eq('id', pet.id).select('id');
      if (!mounted) return;
      if (rows.isEmpty) {
        showSnack(context, _notApplied, error: true);
      } else {
        showSnack(context, status == 'sold' ? 'Marked as sold.' : 'Marked as available.');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(Pet pet) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this listing?',
      message: '${pet.displayName} will be removed from your shop. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = pet.id);
    try {
      final rows = await SupabaseService.client.from('pets').delete().eq('id', pet.id).select('id');
      if (!mounted) return;
      if (rows.isEmpty) {
        showSnack(context, "That didn't go through — it may already have been removed.", error: true);
      } else {
        showSnack(context, 'Listing deleted.');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return _LoadFailure(message: "Couldn't load your pets: $_error", onRetry: _retry);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: [
          ScreenHeader(
            title: 'Pets',
            subtitle: 'Your pet listings.',
            trailing: ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add a pet'),
            ),
          ),
          const SizedBox(height: 20),
          if (_pets.isEmpty)
            const EmptyState(
              title: 'No pets listed yet',
              description: 'Add your first pet to start reaching customers.',
            )
          else
            for (final pet in _pets) ...[
              _PetCard(
                pet: pet,
                busy: _busyId == pet.id,
                onMarkSold: () => _changeStatus(pet, 'sold'),
                onMarkAvailable: () => _changeStatus(pet, 'available'),
                onEdit: () => _openForm(pet),
                onDelete: () => _delete(pet),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;
  final bool busy;
  final VoidCallback onMarkSold;
  final VoidCallback onMarkAvailable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PetCard({
    required this.pet,
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

    final compactOutlined = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: const Size(0, 36),
      textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
    );
    final compactText = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 36),
      textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
    );
    final compactDelete = TextButton.styleFrom(
      foregroundColor: AppColors.error,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 36),
      textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
    );

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
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : breedLine,
                      maxLines: 1,
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
              StatusBadge(status: pet.status, label: titleCase(pet.status)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatPrice(pet.price),
            style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.accent),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (pet.status == 'available')
                OutlinedButton(
                  style: compactOutlined,
                  onPressed: busy ? null : onMarkSold,
                  child: const Text('Mark sold'),
                ),
              if (pet.status == 'reserved')
                OutlinedButton(
                  style: compactOutlined,
                  onPressed: busy ? null : onMarkAvailable,
                  child: const Text('Mark available'),
                ),
              TextButton(
                style: compactText,
                onPressed: busy ? null : onEdit,
                child: const Text('Edit'),
              ),
              TextButton(
                style: compactDelete,
                onPressed: busy ? null : onDelete,
                child: const Text('Delete'),
              ),
            ],
          ),
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

String _numberText(num value) => value == value.roundToDouble() ? value.round().toString() : value.toString();

num? _parseNonNegative(String raw) {
  final value = num.tryParse(raw.trim());
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

class _PetFormState extends State<_PetForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _speciesCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _photoUrlsCtrl;
  late String _gender; // '' = Unknown (stored as null)
  bool _submitting = false;
  String _formError = '';

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    _nameCtrl = TextEditingController(text: pet?.name ?? '');
    _speciesCtrl = TextEditingController(text: pet?.species ?? '');
    _breedCtrl = TextEditingController(text: pet?.breed ?? '');
    _ageCtrl = TextEditingController(text: pet == null ? '' : '${pet.ageMonths}');
    _priceCtrl = TextEditingController(text: pet == null ? '' : _numberText(pet.price));
    _descriptionCtrl = TextEditingController(text: pet?.description ?? '');
    _photoUrlsCtrl = TextEditingController(text: pet?.photoUrls.join(', ') ?? '');
    final gender = pet?.gender;
    _gender = (gender == 'Male' || gender == 'Female') ? gender! : '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _speciesCtrl.dispose();
    _breedCtrl.dispose();
    _ageCtrl.dispose();
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    _photoUrlsCtrl.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) => (value ?? '').trim().isEmpty ? message : null;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _formError = '');
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final description = _descriptionCtrl.text.trim();
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'gender': _gender.isEmpty ? null : _gender,
        'species': _speciesCtrl.text.trim(),
        'breed': _breedCtrl.text.trim(),
        'age_months': _parseNonNegative(_ageCtrl.text)!.round(),
        'price': _parseNonNegative(_priceCtrl.text)!,
        'description': description.isEmpty ? null : description,
        'photo_urls': _photoUrlsCtrl.text
            .split(',')
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toList(),
      };

      final pet = widget.pet;
      if (pet == null) {
        await PetsRepository().insert({'shop_id': widget.shopId, ...payload});
      } else {
        final rows = await SupabaseService.client.from('pets').update(payload).eq('id', pet.id).select('id');
        if (rows.isEmpty) {
          throw Exception("That didn't go through — this listing may have been removed.");
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = errorText(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.pet != null;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) => _required(value, 'Enter a name for this pet.'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Unknown')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
            onChanged: (value) => setState(() => _gender = value ?? ''),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _speciesCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Species'),
            validator: (value) => _required(value, 'Enter a species.'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _breedCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Breed'),
            validator: (value) => _required(value, 'Enter a breed.'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ageCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age (months)'),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return "Enter the pet's age in months.";
              return _parseNonNegative(value!) == null ? 'Enter a valid age in months.' : null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price (INR)'),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'Enter a price.';
              return _parseNonNegative(value!) == null ? 'Enter a valid price.' : null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descriptionCtrl,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _photoUrlsCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Photo URLs',
              hintText: 'https://example.com/photo1.jpg, https://example.com/photo2.jpg',
            ),
          ),
          const SizedBox(height: 6),
          Text('Separate multiple URLs with commas.', style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
          if (_formError.isNotEmpty) ...[
            const SizedBox(height: 14),
            NoticeBox.error(message: _formError),
          ],
          const SizedBox(height: 20),
          LoadingButton(
            label: editing ? 'Save changes' : 'Add pet',
            loading: _submitting,
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Centered "couldn't load" note with a retry button.
class _LoadFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: AppTheme.body(color: AppColors.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
