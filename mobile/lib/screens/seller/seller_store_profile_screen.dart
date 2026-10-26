import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_utils.dart' show withTimeout;
import '../../models/models.dart';
import '../../repositories/shop_contact_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/my_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/content_width.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/ui_kit.dart';

/// Mirrors src/pages/seller/StoreProfile.jsx: create-or-edit form for the
/// signed-in shop owner's own shop.
///
/// This screen doesn't use SellerScaffold because that gates everything behind
/// "set up your shop first", which is exactly what this form does.
///
/// The shop's street address and phone are private: they are read and written
/// only through [ShopContactRepository], never through the public shop row.
class SellerStoreProfileScreen extends ConsumerWidget {
  const SellerStoreProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return RoleShell(
      title: 'My store',
      child: shopAsync.when(
        skipLoadingOnReload: true,
        loading: () => const _ProfileSkeleton(),
        error: (error, _) => SingleChildScrollView(
          padding: kScreenPadding,
          child: ContentWidth(
            child: SellerLoadError(
              what: 'your shop',
              message: describeError(error),
              onRetry: () => ref.invalidate(myShopProvider),
            ),
          ),
        ),
        data: (shop) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myShopProvider);
            try {
              await ref.read(myShopProvider.future);
            } catch (_) {
              // The error state reports it.
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: kScreenPadding,
            child: ContentWidth(
              maxWidth: 640,
              child: _StoreForm(key: ValueKey(shop?.id ?? 'new-shop'), shop: shop),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: kScreenPadding,
      child: ContentWidth(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 180, height: 26),
            SizedBox(height: 10),
            SkeletonBox(height: 14),
            SizedBox(height: 24),
            ListSkeleton(count: 3, itemHeight: 70),
          ],
        ),
      ),
    );
  }
}

const _shopStatusLabels = {
  'approved': 'Approved',
  'pending': 'Pending approval',
  'suspended': 'Suspended',
};

const _kPrivacyNote = 'Your address and phone are private - customers never see them.';

class _StoreForm extends ConsumerStatefulWidget {
  final Shop? shop;
  const _StoreForm({super.key, required this.shop});

  @override
  ConsumerState<_StoreForm> createState() => _StoreFormState();
}

class _StoreFormState extends ConsumerState<_StoreForm> {
  final ShopContactRepository _contacts = ShopContactRepository();

  late final TextEditingController _name = TextEditingController(text: widget.shop?.name ?? '');
  late final TextEditingController _address = TextEditingController();
  late final TextEditingController _phone = TextEditingController();
  late final TextEditingController _license = TextEditingController(text: widget.shop?.licenseNumber ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.shop?.description ?? '');
  late final TextEditingController _banner = TextEditingController(text: widget.shop?.bannerUrl ?? '');

  String? _nameError;
  String? _addressError;
  String? _phoneError;
  String? _licenseError;
  String? _bannerError;
  String? _formError;
  bool _submitting = false;

  /// Address and phone arrive separately (they are private): the fields stay
  /// locked until they have loaded so a save can never overwrite them blind.
  bool _contactLoading = false;
  bool _contactReady = true;
  String? _contactError;

  bool get _exists => widget.shop != null;

  @override
  void initState() {
    super.initState();
    if (_exists) {
      _contactReady = false;
      _contactLoading = true;
      _fetchContact();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _license.dispose();
    _description.dispose();
    _banner.dispose();
    super.dispose();
  }

  void _retryContact() {
    setState(() {
      _contactLoading = true;
      _contactError = null;
    });
    _fetchContact();
  }

  Future<void> _fetchContact() async {
    final shop = widget.shop;
    if (shop == null) return;
    try {
      final contact = await withTimeout(_contacts.fetch(shop.id));
      if (!mounted) return;
      setState(() {
        _address.text = contact?.address ?? '';
        _phone.text = contact?.phone ?? '';
        _contactLoading = false;
        _contactReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contactLoading = false;
        _contactError = describeError(e);
      });
    }
  }

  bool _validate() {
    String? nameError;
    String? addressError;
    String? phoneError;
    String? licenseError;
    String? bannerError;

    if (_name.text.trim().isEmpty) nameError = "Enter your shop's name.";
    if (_address.text.trim().isEmpty) addressError = "Enter your shop's address.";

    final phone = _phone.text.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      phoneError = 'Enter a contact phone number.';
    } else if (digits.length < 7 || digits.length > 15) {
      phoneError = 'Enter a valid phone number, like +91 98765 43210.';
    }

    if (_license.text.trim().isEmpty) licenseError = 'Enter your license number.';

    final banner = _banner.text.trim();
    if (banner.isNotEmpty && !isHttpsUrl(banner)) bannerError = 'The banner link must start with https://';

    setState(() {
      _nameError = nameError;
      _addressError = addressError;
      _phoneError = phoneError;
      _licenseError = licenseError;
      _bannerError = bannerError;
    });
    return nameError == null &&
        addressError == null &&
        phoneError == null &&
        licenseError == null &&
        bannerError == null;
  }

  Future<void> _submit() async {
    if (_submitting || !_contactReady) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    if (!_validate()) return;

    final description = _description.text.trim();
    final banner = _banner.text.trim();
    final address = _address.text.trim();
    final phone = _phone.text.trim();
    // Public shop columns only. The status is never sent: the database forces
    // new shops to "pending" and blocks owners from changing it.
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'license_number': _license.text.trim(),
      'description': description.isEmpty ? null : description,
      'banner_url': banner.isEmpty ? null : banner,
    };

    final shop = widget.shop;
    final profile = ref.read(authControllerProvider).profile;
    if (shop == null && profile == null) {
      setState(() => _formError = 'Please log in again to set up your shop.');
      return;
    }

    setState(() => _submitting = true);
    String? failure;
    if (shop == null) {
      try {
        await withTimeout(_contacts.createShop({...fields, 'owner_id': profile!.id}, address: address, phone: phone));
      } catch (e) {
        failure = describeError(e);
      }
    } else {
      // Contact first: if it fails, nothing has changed yet.
      try {
        final saved = await withTimeout(_contacts.save(shop.id, address: address, phone: phone));
        if (!saved) failure = "Your address and phone couldn't be saved. Please try again.";
      } catch (e) {
        failure = describeError(e);
      }
      if (failure == null) {
        final publicFailure = await updateRow('shops', shop.id, fields);
        if (publicFailure != null) {
          failure = 'Your address and phone were saved, but the other details were not. $publicFailure';
        }
      }
    }
    if (!mounted) return;

    setState(() {
      _submitting = false;
      _formError = failure;
    });
    if (failure != null) return;

    showSnack(
      context,
      shop == null ? 'Shop submitted. An admin will review it soon.' : 'Shop details saved.',
    );
    ref.invalidate(myShopProvider);
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final enabled = !_submitting;
    final contactEnabled = enabled && _contactReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            _exists ? 'Shop profile' : 'Set up your shop',
            style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _exists
              ? 'Customers see your shop name, description, banner and license number. '
                  'Your address and phone number stay private.'
              : 'Tell us about your shop. An admin will review and approve it before it goes live.',
          style: AppTheme.body(color: AppColors.inkSoft),
        ),
        if (shop != null) ...[
          const SizedBox(height: 20),
          CardBox(
            child: Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _Fact(
                  label: 'Status',
                  child: StatusBadge(
                    status: shop.status,
                    label: _shopStatusLabels[shop.status] ?? titleCase(shop.status),
                  ),
                ),
                _Fact(
                  label: 'License number',
                  child: Text(shop.licenseNumber.isEmpty ? '–' : shop.licenseNumber, style: AppTheme.body()),
                ),
              ],
            ),
          ),
          if (shop.status == 'pending') ...[
            const SizedBox(height: 12),
            const NoticeBox(
              message: 'Your shop is waiting for admin approval. You can keep adding listings meanwhile; '
                  'customers see them once it is approved.',
            ),
          ],
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: InputDecoration(labelText: 'Shop name', errorText: _nameError, errorMaxLines: 2),
        ),
        const SizedBox(height: 16),
        const NoticeBox(message: _kPrivacyNote, icon: Icons.lock_outline),
        const SizedBox(height: 12),
        if (_contactLoading) ...[
          Semantics(
            label: 'Loading your address and phone',
            child: Column(
              children: [
                SkeletonBox(height: 56, radius: 12),
                SizedBox(height: 16),
                SkeletonBox(height: 56, radius: 12),
              ],
            ),
          ),
        ] else if (_contactError != null) ...[
          SellerLoadError(what: 'your address and phone', message: _contactError!, onRetry: _retryContact),
        ] else ...[
          TextField(
            controller: _address,
            enabled: contactEnabled,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            decoration: InputDecoration(
              labelText: 'Address',
              helperText: 'Only visible to you and PETSTA admins.',
              errorText: _addressError,
              errorMaxLines: 2,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            enabled: contactEnabled,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-()\s]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              labelText: 'Phone number',
              helperText: 'Only visible to you and PETSTA admins.',
              errorText: _phoneError,
              errorMaxLines: 2,
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _license,
          enabled: enabled,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          decoration: InputDecoration(labelText: 'License number', errorText: _licenseError, errorMaxLines: 2),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _description,
          enabled: enabled,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(1000)],
          decoration: const InputDecoration(labelText: 'Description (optional)', alignLabelWithHint: true),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _banner,
          enabled: enabled,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Banner image URL (optional)',
            hintText: 'https://example.com/banner.jpg',
            errorText: _bannerError,
            errorMaxLines: 2,
          ),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 16),
          NoticeBox.error(message: _formError!),
        ],
        const SizedBox(height: 24),
        LoadingButton(
          label: _exists ? 'Save changes' : 'Create shop',
          loading: _submitting,
          expand: true,
          onPressed: _contactReady ? _submit : null,
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final Widget child;
  const _Fact({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
