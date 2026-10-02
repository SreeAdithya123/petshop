import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/NotFound.jsx.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Page not found',
      child: Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: 'Page not found',
          description: "That page doesn't exist, or it may have moved.",
          action: ElevatedButton(
            onPressed: () => context.push('/'),
            child: const Text('Back to home'),
          ),
        ),
      ),
    );
  }
}
