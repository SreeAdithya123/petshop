import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Ports src/pages/seller/Pets.jsx: a shop owner's own pet listings, with an
/// inline "Add a pet" form and per-row Mark sold / Delete actions.
class SellerPetsScreen extends ConsumerStatefulWidget {
  const SellerPetsScreen({super.key});

  @override
  ConsumerState<SellerPetsScreen> createState() => _SellerPetsScreenState();
}

class _SellerPetsScreenState extends ConsumerState<SellerPetsScreen> {
  Shop? _shop;
  bool _shopLoading = true;

  List<Pet> _pets = const [];
  bool _petsLoading = true;
  String? _petsError;

  bool _formOpen = false;
  Map<String, String> _errors = {};
  String _formError = '';
  bool _submitting = false;

  final _speciesCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _photoUrlsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  @override
  void dispose() {
    _speciesCtrl.dispose();
    _breedCtrl.dispose();
    _ageCtrl.dispose();
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    _photoUrlsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShop() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      setState(() {
        _shopLoading = false;
        _petsLoading = false;
      });
      return;
    }
    try {
      final shop = await ShopsRepository().getByOwnerId(profile.id);
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _shopLoading = false;
      });
      if (shop != null) {
        await _loadPets(shop.id);
      } else {
        setState(() => _petsLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _shopLoading = false;
        _petsLoading = false;
      });
    }
  }

  Future<void> _loadPets([String? shopId]) async {
    final id = shopId ?? _shop?.id;
    if (id == null) return;
    setState(() {
      _petsLoading = true;
      _petsError = null;
    });
    try {
      final pets = await PetsRepository().listByShop(id);
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _petsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _petsError = _describeError(e, 'Something went wrong loading your pets.');
        _petsLoading = false;
      });
    }
  }

  String _describeError(Object error, String fallback) {
    if (error is PostgrestException) {
      return error.message.isNotEmpty ? error.message : fallback;
    }
    final text = error.toString();
    return text.isNotEmpty ? text : fallback;
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_speciesCtrl.text.trim().isEmpty) errors['species'] = 'Enter a species.';
    if (_breedCtrl.text.trim().isEmpty) errors['breed'] = 'Enter a breed.';

    final ageText = _ageCtrl.text.trim();
    if (ageText.isEmpty) {
      errors['age_months'] = "Enter the pet's age in months.";
    } else {
      final age = num.tryParse(ageText);
      if (age == null || age < 0) errors['age_months'] = 'Enter a valid age in months.';
    }

    final priceText = _priceCtrl.text.trim();
    if (priceText.isEmpty) {
      errors['price'] = 'Enter a price.';
    } else {
      final price = num.tryParse(priceText);
      if (price == null || price < 0) errors['price'] = 'Enter a valid price.';
    }

    return errors;
  }

  void _clearForm() {
    _speciesCtrl.clear();
    _breedCtrl.clear();
    _ageCtrl.clear();
    _priceCtrl.clear();
    _descriptionCtrl.clear();
    _photoUrlsCtrl.clear();
  }

  Future<void> _submit() async {
    setState(() => _formError = '');
    final errors = _validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _submitting = true);
    try {
      final photoUrls = _photoUrlsCtrl.text
          .split(',')
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList();
      final description = _descriptionCtrl.text.trim();

      await PetsRepository().insert({
        'shop_id': _shop!.id,
        'species': _speciesCtrl.text.trim(),
        'breed': _breedCtrl.text.trim(),
        'age_months': num.parse(_ageCtrl.text.trim()).round(),
        'price': num.parse(_priceCtrl.text.trim()),
        'description': description.isEmpty ? null : description,
        'photo_urls': photoUrls,
      });

      _clearForm();
      if (!mounted) return;
      setState(() {
        _errors = {};
        _formOpen = false;
      });
      await _loadPets();
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = _describeError(e, 'Something went wrong adding this pet.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _markSold(String petId) async {
    try {
      await PetsRepository().update(petId, {'status': 'sold'});
      await _loadPets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_describeError(e, 'Could not update this listing.'))));
    }
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppTheme.body(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deletePet(String petId) async {
    final confirmed = await _confirmDelete();
    if (!confirmed) return;
    try {
      await PetsRepository().delete(petId);
      await _loadPets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_describeError(e, 'Could not delete this listing.'))));
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.trust;
      case 'sold':
        return AppColors.error;
      default:
        return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Pets',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_shopLoading) return const LoadingView();

    if (_shop == null) {
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

    return ListView(
      padding: kScreenPadding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text('Pets', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle: AppTheme.body(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onPressed: () => setState(() => _formOpen = !_formOpen),
              child: Text(_formOpen ? 'Cancel' : 'Add a pet'),
            ),
          ],
        ),
        if (_formOpen) ...[
          const SizedBox(height: 20),
          _buildForm(),
        ],
        const SizedBox(height: 28),
        _buildPetsList(),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _speciesCtrl,
            decoration: InputDecoration(labelText: 'Species', errorText: _errors['species']),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _breedCtrl,
            decoration: InputDecoration(labelText: 'Breed', errorText: _errors['breed']),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ageCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(labelText: 'Age (months)', errorText: _errors['age_months']),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Price', errorText: _errors['price']),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _photoUrlsCtrl,
            decoration: const InputDecoration(
              labelText: 'Photo URLs',
              hintText: 'https://example.com/photo1.jpg, https://example.com/photo2.jpg',
            ),
          ),
          const SizedBox(height: 6),
          Text('Separate multiple URLs with commas.', style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
          if (_formError.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_formError, style: AppTheme.body(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Adding…' : 'Add pet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetsList() {
    if (_petsLoading) return const LoadingView();
    if (_petsError != null) return ErrorView(message: _petsError!);
    if (_pets.isEmpty) {
      if (_formOpen) return const SizedBox.shrink();
      return const EmptyState(
        title: 'No pets listed yet',
        description: 'Add your first pet to start reaching customers.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _pets.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _buildPetRow(_pets[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPetRow(Pet pet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: pet.breed, style: AppTheme.body(fontWeight: FontWeight.w600)),
                TextSpan(text: ' (${pet.species})', style: AppTheme.body(color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('${pet.ageMonths} months old', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(formatPrice(pet.price), style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.accent)),
              Text(
                _capitalize(pet.status),
                style: AppTheme.body(fontWeight: FontWeight.w600, color: _statusColor(pet.status)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (pet.status == 'available')
                OutlinedButton(
                  onPressed: () => _markSold(pet.id),
                  child: const Text('Mark sold'),
                ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                onPressed: () => _deletePet(pet.id),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
