import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';

class RoleSelectionSwitchScreen extends ConsumerStatefulWidget {
  final UserRole targetRole;

  const RoleSelectionSwitchScreen({
    super.key,
    required this.targetRole,
  });

  @override
  ConsumerState<RoleSelectionSwitchScreen> createState() => _RoleSelectionSwitchScreenState();
}

class _RoleSelectionSwitchScreenState extends ConsumerState<RoleSelectionSwitchScreen> {
  bool _isChecking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processRoleSwitch();
    });
  }

  Future<void> _processRoleSwitch() async {
    final authController = ref.read(authControllerProvider.notifier);
    
    final result = await authController.requestRoleSwitch(widget.targetRole);
    
    if (!mounted) return;

    if (result.isSuccess) {
      // Route to correct dashboard based on target role
      switch (widget.targetRole) {
        case UserRole.customer:
          context.go(RouteNames.customerHome);
          break;
        case UserRole.seller:
          context.go(RouteNames.sellerDashboard);
          break;
        case UserRole.rider:
          context.go(RouteNames.riderDashboard);
          break;
        case UserRole.admin:
          context.go(RouteNames.adminDashboard);
          break;
      }
    } else {
      setState(() {
        _isChecking = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Switching Portal',
        showThemePicker: false,
      ),
      body: Center(
        child: _isChecking
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Verifying access for ${widget.targetRole.displayName} portal...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      'Access Denied',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error ?? 'You do not have permission to access this portal.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
