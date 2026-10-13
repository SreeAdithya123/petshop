import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// The web app's /reserve/:petId page is only a placeholder; reserving happens
/// through the cart and checkout (place_pet_order) from the pet's own page. So
/// this route simply forwards to /pets/:petId, with a short notice and button
/// in case the redirect doesn't run.
class ReserveScreen extends StatefulWidget {
  final String petId;
  const ReserveScreen({super.key, required this.petId});

  @override
  State<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends State<ReserveScreen> {
  @override
  void initState() {
    super.initState();
    // Navigating while the router is still building this route would throw,
    // so forward once the first frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/pets/${Uri.encodeComponent(widget.petId)}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Reserve',
      child: Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: 'Taking you to the pet…',
          description: 'Add the pet to your cart from its page, then check out to reserve it.',
          action: ElevatedButton(
            onPressed: () => context.go('/pets/${Uri.encodeComponent(widget.petId)}'),
            child: const Text('Open pet page'),
          ),
        ),
      ),
    );
  }
}
