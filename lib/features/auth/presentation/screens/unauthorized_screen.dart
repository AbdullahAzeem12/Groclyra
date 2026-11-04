import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../routing/route_names.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../controllers/auth_controller.dart';

class UnauthorizedScreen extends ConsumerWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go(RouteNames.roleSelection),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.p24),
          child: EmptyStateView(
            title: '403 Forbidden Access',
            description: 'You do not have permissions to access this portal. Your current role is not authorized for this section of the system.',
            icon: Icons.shield_outlined,
            actionButtonText: 'Return to Role Selection',
            onAction: () {
              ref.read(authControllerProvider.notifier).logout();
              context.go(RouteNames.roleSelection);
            },
          ),
        ),
      ),
    );
  }
}
