import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// Mirrors src/pages/NotFound.jsx. Shown for any route the app doesn't know,
/// including stale links and mistyped deep links.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Page not found',
      child: Center(
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: Semantics(
            container: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.travel_explore_outlined, size: 64, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: AppTheme.display(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "That page doesn't exist, or it may have moved.",
                  style: AppTheme.body(color: AppColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    LoadingButton(
                      label: 'Back to home',
                      icon: Icons.home_outlined,
                      onPressed: () => context.go('/'),
                    ),
                    if (context.canPop())
                      LoadingButton(
                        label: 'Go back',
                        icon: Icons.arrow_back,
                        outlined: true,
                        onPressed: () => context.pop(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
