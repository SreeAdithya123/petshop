import 'package:flutter/material.dart';

import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/account/account_widgets.dart';
import '../../widgets/account_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

const _addressLabels = ['Home', 'Work', 'Other'];
const _addressColumns = 'id, customer_id, label, line1, line2, city, state, zip, is_default, created_at';
final _zipPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\s-]{2,9}$');

/// Makes one address the default, clearing the others first so there is
/// never more than one.
Future<void> _makeOnlyDefault(String userId, String addressId) async {
  final client = SupabaseService.client;
  await client
      .from('addresses')
      .update({'is_default': false})
      .eq('customer_id', userId)
      .eq('is_default', true)
      .neq('id', addressId);
  await client.from('addresses').update({'is_default': true}).eq('id', addressId).eq('customer_id', userId);
}

/// Mirrors src/pages/account/AccountAddresses.jsx: saved delivery addresses
/// with add / edit (bottom sheet) / make default / delete.
class AccountAddressesScreen extends StatelessWidget {
  const AccountAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account/addresses',
      title: 'Addresses',
      subtitle: 'Your delivery addresses for orders and gifts. Shops only get what they need to fulfil a delivery.',
      builder: (context, profile) => _AddressesBody(key: ValueKey(profile.id), userId: profile.id),
    );
  }
}

class _AddressesBody extends StatefulWidget {
  final String userId;
  const _AddressesBody({super.key, required this.userId});

  @override
  State<_AddressesBody> createState() => _AddressesBodyState();
}

class _AddressesBodyState extends State<_AddressesBody> {
  List<SavedAddress>? _addresses;
  String? _loadError;
  String? _busyId;
  String _actionError = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _retryLoad() {
    setState(() {
      _addresses = null;
      _loadError = null;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService.client
          .from('addresses')
          .select(_addressColumns)
          .eq('customer_id', widget.userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);
      final addresses = [for (final row in rows) SavedAddress.fromJson(row)];
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (_addresses != null) {
        // A background refresh failed: keep the list on screen.
        showSnack(context, errorText(error), error: true);
        return;
      }
      setState(() => _loadError = errorText(error));
    }
  }

  Future<void> _openForm([SavedAddress? address]) async {
    await showFormSheet<bool>(
      context,
      title: address == null ? 'Add an address' : 'Edit address',
      description: 'Used for delivery of your orders and gifts.',
      builder: (sheetContext) => _AddressForm(
        userId: widget.userId,
        address: address,
        startsAsDefault: (_addresses ?? const []).isEmpty,
        // Reload whenever the server changed, even if the sheet stays open.
        onChanged: _load,
      ),
    );
  }

  Future<void> _setDefault(SavedAddress address) async {
    setState(() {
      _busyId = address.id;
      _actionError = '';
    });
    String? failure;
    try {
      await _makeOnlyDefault(widget.userId, address.id);
    } catch (error) {
      failure = errorText(error);
    }
    if (!mounted) return;
    setState(() {
      _busyId = null;
      if (failure != null) _actionError = failure;
    });
    await _load();
  }

  Future<void> _delete(SavedAddress address) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete address?',
      message: "Delete your ${address.label} address (${address.line1})? This can't be undone.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busyId = address.id;
      _actionError = '';
    });
    try {
      await SupabaseService.client
          .from('addresses')
          .delete()
          .eq('id', address.id)
          .eq('customer_id', widget.userId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _actionError = errorText(error);
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busyId = null;
      _addresses = _addresses?.where((candidate) => candidate.id != address.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) return AccountErrorNote(message: _loadError!, onRetry: _retryLoad);
    final addresses = _addresses;
    if (addresses == null) return const AccountLoadingNote();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (addresses.isNotEmpty)
          RefreshHeading(
            title: 'Saved addresses',
            onRefresh: _load,
            trailing: ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        if (_actionError.isNotEmpty) ...[
          const SizedBox(height: 12),
          NoticeBox.error(message: _actionError),
        ],
        if (addresses.isEmpty)
          EmptyState(
            title: 'No saved addresses',
            description: 'Add an address to speed up checkout and gifting.',
            action: ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add an address'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          for (final address in addresses) ...[
            _AddressCard(
              key: ValueKey(address.id),
              address: address,
              busy: _busyId == address.id,
              onEdit: () => _openForm(address),
              onMakeDefault: () => _setDefault(address),
              onDelete: () => _delete(address),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  final SavedAddress address;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onMakeDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    super.key,
    required this.address,
    required this.busy,
    required this.onEdit,
    required this.onMakeDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final place = [address.city, if ((address.state ?? '').isNotEmpty) address.state!].join(', ');
    final lines = [
      address.line1,
      if ((address.line2 ?? '').isNotEmpty) address.line2!,
      [place, address.zip].where((part) => part.isNotEmpty).join(' '),
    ];

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(address.label, style: AppTheme.display(fontSize: 15.5, fontWeight: FontWeight.w600)),
              if (address.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Default',
                    style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Text(line, style: AppTheme.body(fontSize: 14.5, color: AppColors.inkSoft)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              if (!address.isDefault)
                TextButton(
                  onPressed: busy ? null : onMakeDefault,
                  child: const Text('Make default'),
                ),
              TextButton.icon(
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add / edit form shown in the bottom sheet. Performs the writes itself and
/// pops with `true` once everything has been saved.
class _AddressForm extends StatefulWidget {
  final String userId;
  final SavedAddress? address;
  final bool startsAsDefault;
  final VoidCallback onChanged;

  const _AddressForm({
    required this.userId,
    required this.address,
    required this.startsAsDefault,
    required this.onChanged,
  });

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  late final TextEditingController _line1 = TextEditingController(text: widget.address?.line1 ?? '');
  late final TextEditingController _line2 = TextEditingController(text: widget.address?.line2 ?? '');
  late final TextEditingController _city = TextEditingController(text: widget.address?.city ?? '');
  late final TextEditingController _state = TextEditingController(text: widget.address?.state ?? '');
  late final TextEditingController _zip = TextEditingController(text: widget.address?.zip ?? '');
  late String _label = widget.address?.label ?? 'Home';
  late bool _isDefault = widget.address?.isDefault ?? widget.startsAsDefault;

  // Progress of the save, so a retry after a partial failure edits the
  // address that was already created instead of adding a duplicate.
  late String? _addressId = widget.address?.id;
  late bool _wasDefault = widget.address?.isDefault ?? false;

  Map<String, String> _errors = {};
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_line1.text.trim().isEmpty) errors['line1'] = 'Enter the street address.';
    if (_city.text.trim().isEmpty) errors['city'] = 'Enter the city.';
    final zip = _zip.text.trim();
    if (zip.isEmpty) {
      errors['zip'] = 'Enter the PIN / ZIP code.';
    } else if (!_zipPattern.hasMatch(zip)) {
      errors['zip'] = 'Enter a valid PIN / ZIP code.';
    }
    return errors;
  }

  Future<void> _save() async {
    final errors = _validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    final line2 = _line2.text.trim();
    final state = _state.text.trim();
    final fields = <String, dynamic>{
      'label': _label,
      'line1': _line1.text.trim(),
      'line2': line2.isEmpty ? null : line2,
      'city': _city.text.trim(),
      'state': state.isEmpty ? null : state,
      'zip': _zip.text.trim(),
    };

    setState(() {
      _saving = true;
      _error = '';
    });
    final client = SupabaseService.client;
    try {
      if (_addressId == null) {
        // Insert as a plain address first; the default flag is applied
        // afterwards so a failed insert can never cost the customer their
        // current default.
        final row = await client
            .from('addresses')
            .insert({...fields, 'customer_id': widget.userId, 'is_default': false})
            .select('id')
            .single();
        _addressId = row['id'] as String;
        _wasDefault = false;
      } else {
        await client
            .from('addresses')
            .update(fields)
            .eq('id', _addressId!)
            .eq('customer_id', widget.userId);
      }
      final id = _addressId!;
      if (_isDefault && !_wasDefault) {
        await _makeOnlyDefault(widget.userId, id);
        _wasDefault = true;
      } else if (!_isDefault && _wasDefault) {
        await client
            .from('addresses')
            .update({'is_default': false})
            .eq('id', id)
            .eq('customer_id', widget.userId);
        _wasDefault = false;
      }
      widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      // Reload either way so the list reflects whatever the server saved.
      widget.onChanged();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep a custom label from older data selectable.
    final labelOptions = _addressLabels.contains(_label) ? _addressLabels : [_label, ..._addressLabels];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FormLabel('Label'),
        Wrap(
          spacing: 8,
          children: [
            for (final label in labelOptions)
              ChoiceChip(
                label: Text(label),
                selected: _label == label,
                onSelected: _saving ? null : (_) => setState(() => _label = label),
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: AppTheme.body(
                  fontSize: 13,
                  fontWeight: _label == label ? FontWeight.w600 : FontWeight.w400,
                  color: _label == label ? AppColors.primary : AppColors.ink,
                ),
                side: BorderSide(color: _label == label ? AppColors.primary : AppColors.border),
                backgroundColor: AppColors.surface,
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 16),
        const FormLabel('Address line 1'),
        TextField(
          controller: _line1,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.streetAddressLine1],
          decoration: InputDecoration(errorText: _errors['line1']),
        ),
        const SizedBox(height: 16),
        const FormLabel('Address line 2', optional: true),
        TextField(
          controller: _line2,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.streetAddressLine2],
        ),
        const SizedBox(height: 16),
        const FormLabel('City'),
        TextField(
          controller: _city,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.addressCity],
          decoration: InputDecoration(errorText: _errors['city']),
        ),
        const SizedBox(height: 16),
        const FormLabel('State', optional: true),
        TextField(
          controller: _state,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.addressState],
        ),
        const SizedBox(height: 16),
        const FormLabel('PIN / ZIP code'),
        TextField(
          controller: _zip,
          enabled: !_saving,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.postalCode],
          decoration: InputDecoration(errorText: _errors['zip']),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _isDefault,
          onChanged: _saving ? null : (value) => setState(() => _isDefault = value ?? false),
          title: Text('Use as my default address', style: AppTheme.body(fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          NoticeBox.error(message: _error),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LoadingButton(
                label: 'Save address',
                loading: _saving,
                onPressed: _save,
                expand: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
