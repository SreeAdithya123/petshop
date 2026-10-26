import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/content_width.dart';
import '../widgets/health/pharmacy_chat.dart';
import '../widgets/health/vet_consult.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

const _safetyNote =
    'PETSTA Health gives general guidance and connects you to licensed vets. It does not replace a veterinarian — '
    'in an emergency go to your nearest vet clinic immediately.';

enum _HealthTab { vet, pharmacy }

/// Mirrors src/pages/Health.jsx: a safety banner, Vet teleconsultation and the
/// rule-based Pharmacy assistant. The two tools sit behind a tab switch so both
/// are one tap away; each keeps its state while the other is showing.
///
/// Deep links: `/health#vet` (default) and `/health#pharmacy` pick the tab;
/// `/health#consultations` opens the vet tab scrolled to My consultations.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _vetKey = GlobalKey<VetConsultState>();
  _HealthTab _tab = _HealthTab.vet;
  bool _fragmentHandled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fragmentHandled) return;
    _fragmentHandled = true;
    final fragment = _routeFragment();
    if (fragment == 'pharmacy') {
      _tab = _HealthTab.pharmacy;
    } else if (fragment == 'consultations' || fragment == 'my-consultations') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vetKey.currentState?.scrollToConsultations();
      });
    }
  }

  String _routeFragment() {
    try {
      return GoRouterState.of(context).uri.fragment;
    } catch (_) {
      return '';
    }
  }

  void _selectTab(_HealthTab tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Health',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: ContentWidth(
              child: Row(
                children: [
                  Expanded(
                    child: _TabItem(
                      icon: Icons.medical_services_outlined,
                      label: 'Vet consult',
                      selected: _tab == _HealthTab.vet,
                      onTap: () => _selectTab(_HealthTab.vet),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TabItem(
                      icon: Icons.medication_outlined,
                      label: 'Pharmacy assistant',
                      selected: _tab == _HealthTab.pharmacy,
                      onTap: () => _selectTab(_HealthTab.pharmacy),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab.index,
              sizing: StackFit.expand,
              children: [
                _buildVetTab(),
                ContentWidth(
                  child: PharmacyChat(
                    onBookVet: () => _selectTab(_HealthTab.vet),
                    topNotice: const NoticeBox.warning(message: _safetyNote),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVetTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _vetKey.currentState?.refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: kScreenPadding,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.secondary.withValues(alpha: 0.1),
                      AppColors.tertiary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Pet health', style: AppTheme.display(fontSize: 28)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Talk to a vet from home, or get quick pointers on everyday concerns.',
                      style: AppTheme.body(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 16),
                    const NoticeBox.warning(message: _safetyNote),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => _vetKey.currentState?.scrollToConsultations(),
                          icon: const Icon(Icons.event_note_outlined, size: 18),
                          label: const Text('My consultations'),
                          style: _linkStyle,
                        ),
                        TextButton.icon(
                          onPressed: () => _selectTab(_HealthTab.pharmacy),
                          icon: const Icon(Icons.medication_outlined, size: 18),
                          label: const Text('Ask the pharmacy assistant'),
                          style: _linkStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              VetConsult(key: _vetKey),
            ],
          ),
        ),
      ),
    );
  }
}

final ButtonStyle _linkStyle = TextButton.styleFrom(
  foregroundColor: AppColors.primary,
  minimumSize: const Size(0, 48),
  textStyle: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
);

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.ink;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Center(
                // Shrinks the label rather than overflowing at 320dp / large text.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: AppTheme.body(
                          fontSize: 13.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
