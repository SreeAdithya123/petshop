import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/app_theme.dart';
import '../ui_kit.dart';

/// "About & legal" card on the profile screen: app version, the privacy
/// policy and terms, and a way to reach support.
class AboutLegalCard extends StatefulWidget {
  const AboutLegalCard({super.key});

  @override
  State<AboutLegalCard> createState() => _AboutLegalCardState();
}

class _AboutLegalCardState extends State<AboutLegalCard> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final build = info.buildNumber.trim();
      setState(() => _version = build.isEmpty ? info.version : '${info.version} ($build)');
    } catch (_) {
      // The version line is a nicety: leave it out when it can't be read.
    }
  }

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          if (_version.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text('PETSTA version', style: AppTheme.body(fontSize: 14.5))),
                  const SizedBox(width: 12),
                  Text(_version, style: AppTheme.body(fontSize: 14.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          _LinkRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy policy',
            onTap: () => context.push('/legal/privacy'),
          ),
          const Divider(height: 1),
          _LinkRow(
            icon: Icons.description_outlined,
            label: 'Terms of service',
            onTap: () => context.push('/legal/terms'),
          ),
          const Divider(height: 1),
          _LinkRow(
            icon: Icons.support_agent_outlined,
            label: 'Contact support',
            onTap: () => context.push('/support'),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // A transparent Material keeps the tap ripple visible on the card's white fill.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 22, color: AppColors.primary),
        title: Text(label, style: AppTheme.body(fontSize: 14.5)),
        trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSoft),
        minVerticalPadding: 4,
      ),
    );
  }
}
