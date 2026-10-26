import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../state/catalog_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../pet_widgets.dart';
import '../ui_kit.dart';

/// Bottom-sheet version of src/components/pets/GiftPetModal.jsx: reserve
/// [pet] as a gift for someone else (no online payment, the shop arranges
/// pickup).
///
/// Resolves to true when the gift order was placed. Once the sheet closes
/// after a placed gift the catalog is refreshed, because the pet is now
/// reserved and no longer for sale.
Future<bool> showGiftPetSheet(
  BuildContext context, {
  required Pet pet,
  String? shopName,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  var placed = false;
  await showFormSheet<void>(
    context,
    title: 'Send as a gift',
    description: shopName == null ? pet.displayName : '${pet.displayName} · sold by $shopName',
    builder: (sheetContext) => _GiftPetForm(
      pet: pet,
      onPlaced: () => placed = true,
    ),
  );
  if (placed) container.invalidate(catalogProvider);
  return placed;
}

const _messageLimit = 300;

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _phonePattern = RegExp(r'^[\d\s()+-]+$');
final _nonDigits = RegExp(r'\D');

/// Accepts an email address or a phone number (7-15 digits, common
/// separators allowed), like isEmailOrPhone in the web modal.
bool isEmailOrPhone(String value) {
  if (_emailPattern.hasMatch(value)) return true;
  final digits = value.replaceAll(_nonDigits, '');
  return _phonePattern.hasMatch(value) && digits.length >= 7 && digits.length <= 15;
}

class _GiftPetForm extends ConsumerStatefulWidget {
  final Pet pet;
  final VoidCallback onPlaced;
  const _GiftPetForm({required this.pet, required this.onPlaced});

  @override
  ConsumerState<_GiftPetForm> createState() => _GiftPetFormState();
}

class _GiftPetFormState extends ConsumerState<_GiftPetForm> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();
  String? _nameError;
  String? _contactError;
  String? _submitError;
  bool _submitting = false;
  String? _placedFor; // recipient name once the gift is placed

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final recipientName = _nameController.text.trim();
    final contact = _contactController.text.trim();
    final message = _messageController.text.trim();

    final nameError = recipientName.isEmpty ? "Enter the recipient's name." : null;
    final contactError = contact.isEmpty
        ? "Enter the recipient's email or phone number."
        : (isEmailOrPhone(contact) ? null : 'Enter a valid email address or phone number.');
    setState(() {
      _nameError = nameError;
      _contactError = contactError;
      _submitError = null;
    });
    if (nameError != null || contactError != null) return;

    setState(() => _submitting = true);
    try {
      await SupabaseService.client.rpc('place_pet_gift', params: {
        'p_pet_id': widget.pet.id,
        'p_recipient_name': recipientName,
        'p_recipient_contact': contact,
        'p_message': message.isEmpty ? null : message,
      });
      // The pet is reserved now, even if the sheet was dismissed mid-request.
      widget.onPlaced();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _placedFor = recipientName;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = commerceErrorText(error);
      });
    }
  }

  void _closeThen(void Function(GoRouter router) navigate) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    navigate(router);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final name = widget.pet.displayName;

    if (auth.status == AuthStatus.loading) {
      return Text('Checking your account…', style: AppTheme.body(color: AppColors.inkSoft));
    }
    final profile = auth.profile;
    if (auth.status != AuthStatus.signedIn || profile == null) {
      return LoginPromptCard(
        compact: true,
        title: 'Log in to send a gift',
        description: 'Sign in or sign up to send $name as a gift.',
      );
    }
    if (profile.role != 'customer') {
      return const NoticeBox(
        message: 'Only customer accounts can send pets as gifts. Sign in with a customer account to continue.',
      );
    }

    final placedFor = _placedFor;
    if (placedFor != null) return _buildSuccess(name, placedFor);
    return _buildForm(name);
  }

  Widget _buildSuccess(String name, String recipient) {
    return SuccessPanel(
      title: 'Gift reserved',
      message: '$name is now held for $recipient. The shop will arrange pickup with you — you pay in person. '
          'You can follow it under My account → Orders.',
      actions: [
        ElevatedButton(
          onPressed: () => _closeThen((router) => router.push('/account/orders')),
          child: const Text('View my orders'),
        ),
        OutlinedButton(
          onPressed: () => _closeThen((router) => router.push(shopSupportRoute(shopId: widget.pet.shopId))),
          child: const Text('Message the shop'),
        ),
        OutlinedButton(
          // The gifted pet is no longer for sale, so leave its page.
          onPressed: () => _closeThen((router) => router.go('/pets')),
          child: const Text('Keep browsing'),
        ),
      ],
    );
  }

  Widget _buildForm(String name) {
    final pet = widget.pet;
    return PopScope(
      canPop: !_submitting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        pet.breed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatPrice(pet.price),
                  style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _FieldLabel('Recipient name'),
          TextField(
            controller: _nameController,
            enabled: !_submitting,
            maxLength: 80,
            autocorrect: false,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(errorText: _nameError, counterText: ''),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Recipient email or phone'),
          TextField(
            controller: _contactController,
            enabled: !_submitting,
            maxLength: 120,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(errorText: _contactError, counterText: ''),
            onChanged: (_) {
              if (_contactError != null) setState(() => _contactError = null);
            },
          ),
          const SizedBox(height: 4),
          Text(
            'So the shop can reach your recipient about the gift.',
            style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Gift message', optional: true),
          TextField(
            controller: _messageController,
            enabled: !_submitting,
            minLines: 3,
            maxLines: 4,
            maxLength: _messageLimit,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Write a note to go with the gift'),
          ),
          const SizedBox(height: 4),
          Text(
            'The pet is held for your recipient; the shop will arrange pickup with you and pay in person. '
            'Nothing is charged online, and shop contact details stay private.',
            style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            NoticeBox.error(message: _submitError!),
          ],
          const SizedBox(height: 20),
          LoadingButton(
            label: 'Send as gift · ${formatPrice(pet.price)}',
            icon: Icons.card_giftcard,
            loading: _submitting,
            onPressed: _submit,
            expand: true,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool optional;
  const _FieldLabel(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        optional ? '$text (optional)' : text,
        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
      ),
    );
  }
}
