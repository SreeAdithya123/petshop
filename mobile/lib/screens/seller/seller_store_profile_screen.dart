import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Mirrors src/pages/seller/StoreProfile.jsx: create-or-edit form for the
/// signed-in shop owner's own shop.
class SellerStoreProfileScreen extends ConsumerStatefulWidget {
  const SellerStoreProfileScreen({super.key});

  @override
  ConsumerState<SellerStoreProfileScreen> createState() => _SellerStoreProfileScreenState();
}

const Map<String, String> _shopStatusLabel = {
  'approved': 'Approved',
  'pending': 'Pending approval',
  'suspended': 'Suspended',
};

class _SellerStoreProfileScreenState extends ConsumerState<SellerStoreProfileScreen> {
  Shop? _shop;
  bool _loading = true;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _bannerController = TextEditingController();

  final Map<String, String> _errors = {};
  String _formError = '';
  bool _submitting = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _descriptionController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadShop() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      if (!mounted) return;
      setState(() {
        _shop = null;
        _loading = false;
      });
      return;
    }

    final shop = await ShopsRepository().getByOwnerId(profile.id);
    if (!mounted) return;
    setState(() {
      _shop = shop;
      _loading = false;
      if (shop != null) _fillForm(shop);
    });
  }

  void _fillForm(Shop shop) {
    _nameController.text = shop.name;
    _addressController.text = shop.address;
    _phoneController.text = shop.phone;
    _licenseController.text = shop.licenseNumber;
    _descriptionController.text = shop.description ?? '';
    _bannerController.text = shop.bannerUrl ?? '';
  }

  void _markDirty() {
    if (_saved) setState(() => _saved = false);
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_nameController.text.trim().isEmpty) errors['name'] = "Enter your shop's name.";
    if (_addressController.text.trim().isEmpty) errors['address'] = "Enter your shop's address.";
    if (_phoneController.text.trim().isEmpty) errors['phone'] = 'Enter a contact phone number.';
    if (_licenseController.text.trim().isEmpty) errors['license_number'] = 'Enter your license number.';
    return errors;
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _formError = '';
      _saved = false;
    });

    final validationErrors = _validate();
    setState(() => _errors
      ..clear()
      ..addAll(validationErrors));
    if (validationErrors.isNotEmpty) return;

    setState(() => _submitting = true);
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'license_number': _licenseController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'banner_url': _bannerController.text.trim().isEmpty ? null : _bannerController.text.trim(),
      };

      if (_shop != null) {
        await ShopsRepository().update(_shop!.id, payload);
        if (!mounted) return;
        setState(() => _saved = true);
      } else {
        final profile = ref.read(authControllerProvider).profile;
        await ShopsRepository().insert({...payload, 'owner_id': profile?.id});
      }
      await _loadShop();
    } catch (submitError) {
      if (!mounted) return;
      setState(() => _formError = submitError.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color _statusColor(String status) {
    if (status == 'approved') return AppColors.trust;
    if (status == 'suspended') return AppColors.error;
    return AppColors.ink;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const RoleShell(
        title: 'My Store',
        child: LoadingView(),
      );
    }

    final shopExists = _shop != null;

    return RoleShell(
      title: 'My Store',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shopExists ? 'Shop profile' : 'Set up your shop',
              style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              shopExists
                  ? "Keep your shop's details up to date. Customers see this information across PETSTA."
                  : 'Tell us about your shop. An admin will review and approve it before it goes live.',
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
            if (shopExists) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surface,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                          const SizedBox(height: 2),
                          Text(
                            _shopStatusLabel[_shop!.status] ?? _shop!.status,
                            style: AppTheme.body(fontWeight: FontWeight.w600, color: _statusColor(_shop!.status)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('License number', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                          const SizedBox(height: 2),
                          Text(_shop!.licenseNumber, style: AppTheme.body()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            _Field(
              label: 'Shop name',
              controller: _nameController,
              error: _errors['name'],
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Address',
              controller: _addressController,
              error: _errors['address'],
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Phone number',
              controller: _phoneController,
              error: _errors['phone'],
              keyboardType: TextInputType.phone,
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'License number',
              controller: _licenseController,
              error: _errors['license_number'],
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Description',
              controller: _descriptionController,
              maxLines: 4,
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Banner image URL',
              controller: _bannerController,
              keyboardType: TextInputType.url,
              onChanged: (_) => _markDirty(),
            ),
            if (_formError.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_formError, style: AppTheme.body(color: AppColors.error)),
            ],
            if (_saved) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Saved.', style: AppTheme.body(color: AppColors.trust)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _saved = false),
                    child: Text(
                      'Dismiss',
                      style: AppTheme.body(color: AppColors.inkSoft, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _handleSubmit,
                child: Text(_submitting ? 'Saving…' : (shopExists ? 'Save changes' : 'Create shop')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? error;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.controller,
    this.error,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.body(fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: AppTheme.body(),
          decoration: InputDecoration(
            errorText: error,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
