import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/theme_controller.dart';
import 'gradient_button.dart';

class EmptyStateView extends ConsumerWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? actionButtonText;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_rounded,
    this.actionButtonText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.p24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: themeState.palette.subtleGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: themeState.palette.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (actionButtonText != null && onAction != null) ...[
                const SizedBox(height: 24),
                GradientButton(
                  text: actionButtonText!,
                  onPressed: onAction,
                  width: 200,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
