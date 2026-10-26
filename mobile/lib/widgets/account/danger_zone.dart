import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../ui_kit.dart';

/// The word the customer has to type before an account can be deleted.
const deleteConfirmationWord = 'DELETE';

/// "Danger zone" card on the profile screen. Customers can delete their
/// account; shop owners and admins are pointed to support instead.
class DangerZoneCard extends StatelessWidget {
  final String role;
  final bool busy;
  final String error;
  final VoidCallback onDelete;
  final VoidCallback onContactSupport;

  const DangerZoneCard({
    super.key,
    required this.role,
    required this.busy,
    required this.error,
    required this.onDelete,
    required this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomer = role == 'customer';
    final accountKind = role == 'admin' ? 'an admin' : 'a shop';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Danger zone',
                  style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCustomer
                ? 'Delete your account and the personal data tied to it. This can\'t be undone.'
                : 'Contact support to close $accountKind account. These accounts can\'t be deleted from the app.',
            style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          if (isCustomer)
            OutlinedButton.icon(
              onPressed: busy ? null : onDelete,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                    )
                  : const Icon(Icons.delete_forever_outlined, size: 20),
              label: Text(busy ? 'Deleting…' : 'Delete my account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onContactSupport,
              icon: const Icon(Icons.support_agent_outlined, size: 20),
              label: const Text('Contact support'),
            ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 12),
            NoticeBox.error(message: error),
          ],
        ],
      ),
    );
  }
}

/// Asks the customer to confirm deleting their account by typing
/// [deleteConfirmationWord]. Resolves to true only when confirmed.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _DeleteAccountDialog(),
  );
  return result ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed => _controller.text.trim() == deleteConfirmationWord;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('Delete your account?', style: AppTheme.display(fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes or anonymises your account and personal data, including your profile, '
            'saved addresses, wishlist and support messages. Records a shop needs to keep, such as past '
            'orders, may be kept without your personal details.',
            style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          Text(
            "You'll be signed out straight away and won't be able to log in again. This can't be undone.",
            style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              text: 'Type ',
              style: AppTheme.body(fontSize: 13.5),
              children: [
                TextSpan(
                  text: deleteConfirmationWord,
                  style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.error),
                ),
                const TextSpan(text: ' to confirm.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_confirmed) Navigator.of(context).pop(true);
            },
            decoration: const InputDecoration(hintText: deleteConfirmationWord),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my account'),
        ),
        TextButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
