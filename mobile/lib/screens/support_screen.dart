import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Matches src/pages/Support.jsx.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _subjectController = TextEditingController();
  String? _shopId;

  bool _initialized = false;
  bool _shopsLoading = true;
  List<Shop> _shops = [];

  bool _ticketsLoading = true;
  List<SupportTicket> _tickets = [];

  String? _subjectError;
  String _formError = '';
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    final shops = await ShopsRepository().listApproved();
    if (!mounted) return;
    setState(() {
      _shops = shops;
      _shopsLoading = false;
    });
  }

  Future<void> _loadTickets() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;
    setState(() => _ticketsLoading = true);
    final tickets = await SupportTicketsRepository().listForCustomer(profile.id);
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _ticketsLoading = false;
    });
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _formError = '';
      _subjectError = _subjectController.text.trim().isEmpty ? 'Enter a subject.' : null;
    });
    if (_subjectError != null) return;

    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;

    setState(() => _submitting = true);
    try {
      await SupportTicketsRepository().insert({
        'customer_id': profile.id,
        'shop_id': _shopId,
        'subject': _subjectController.text.trim(),
      });
      _subjectController.clear();
      setState(() => _shopId = null);
      await _loadTickets();
    } catch (e) {
      final message = e is PostgrestException ? e.message : "Couldn't raise that ticket. Try again.";
      if (!mounted) return;
      setState(() => _formError = message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (auth.status == AuthStatus.loading) {
      return const RoleShell(title: 'Support', child: LoadingView());
    }

    if (auth.status != AuthStatus.signedIn || auth.profile == null) {
      return RoleShell(
        title: 'Support',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: 'Log in to get support',
            action: ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text('Log in'),
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      _initialized = true;
      _loadShops();
      _loadTickets();
    }

    return RoleShell(
      title: 'Support',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              "Raise a ticket and we'll get back to you.",
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            _buildForm(),
            const SizedBox(height: 40),
            Text('Your tickets', style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildTickets(),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 6),
        TextField(
          controller: _subjectController,
          decoration: InputDecoration(
            errorText: _subjectError,
          ),
        ),
        const SizedBox(height: 16),
        Text('Shop', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 6),
        _shopsLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Loading…'),
              )
            : DropdownButtonFormField<String?>(
                initialValue: _shopId,
                decoration: const InputDecoration(),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('General (not shop-specific)'),
                  ),
                  for (final shop in _shops)
                    DropdownMenuItem<String?>(
                      value: shop.id,
                      child: Text(shop.name),
                    ),
                ],
                onChanged: (value) => setState(() => _shopId = value),
              ),
        if (_formError.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_formError, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitting ? null : _handleSubmit,
          child: Text(_submitting ? 'Submitting…' : 'Raise ticket'),
        ),
      ],
    );
  }

  Widget _buildTickets() {
    if (_ticketsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Loading…'),
      );
    }
    if (_tickets.isEmpty) {
      return const EmptyState(
        title: 'No tickets yet',
        description: 'Raise a ticket above if you need help.',
      );
    }
    return Column(
      children: [
        for (final ticket in _tickets) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ticket.subject,
                        style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(status: ticket.status, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ticket.shop?.name ?? 'General',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
