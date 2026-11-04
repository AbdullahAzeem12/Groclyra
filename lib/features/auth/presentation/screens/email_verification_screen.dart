import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/rate_limit_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../routing/route_names.dart';
import '../../domain/entities/user_entity.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_gradient_button.dart';
import '../widgets/floating_background.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isChecking = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(authControllerProvider).user;
      final identifier = user?.id ?? user?.email ?? 'current_user';
      final remaining = ref
          .read(rateLimitServiceProvider)
          .getRemainingEmailVerificationCooldownSeconds(identifier);
      if (remaining > 0) {
        _startCooldown(remaining);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleCheckVerified() async {
    setState(() => _isChecking = true);
    final verified =
        await ref.read(authControllerProvider.notifier).checkEmailVerified();
    setState(() => _isChecking = false);

    if (verified && mounted) {
      final role = ref.read(authControllerProvider).currentRole ?? UserRole.customer;
      _navigateToRolePortal(role);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email not yet verified. Please tap the confirmation link sent to your inbox.',
          ),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
    }
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0) return;

    final user = ref.read(authControllerProvider).user;
    final identifier = user?.id ?? user?.email ?? 'current_user';
    final rateLimit = ref.read(rateLimitServiceProvider);
    final rem = rateLimit.getRemainingEmailVerificationCooldownSeconds(identifier);
    if (rem > 0) {
      _startCooldown(rem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait $rem seconds before requesting another email.'),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final result =
        await ref.read(authControllerProvider.notifier).sendEmailVerification();
    if (result.isSuccess && mounted) {
      _startCooldown(60);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email re-sent successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else if (mounted && result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message!),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _navigateToRolePortal(UserRole role) {
    switch (role) {
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
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final palette = themeState.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = authState.user?.email ?? 'your email';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          FloatingBackground(palette: palette, isDark: isDark),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.p24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Animated envelope icon badge
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: palette.linearGradient,
                          boxShadow: [
                            BoxShadow(
                              color: palette.startColor.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.mark_email_unread_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.p24),

                      Text(
                        'Verify Your Email',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                      ),
                      const SizedBox(height: AppDimensions.p12),

                      Text(
                        'We sent a verification link to:\n$email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: palette.startColor,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.p8),

                      Text(
                        'Please verify your email address to ensure account security and access all Groclyra features.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.p32),

                      // Verification check button
                      AuthGradientButton(
                        text: 'I Have Verified',
                        isLoading: _isChecking,
                        loadingText: 'Verifying status...',
                        onPressed: _handleCheckVerified,
                        palette: palette,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(height: AppDimensions.p12),

                      // Resend button with active persistent cooldown
                      OutlinedButton.icon(
                        onPressed: _cooldownSeconds > 0 ? null : _handleResend,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          _cooldownSeconds > 0
                              ? 'Resend Email (${_cooldownSeconds}s)'
                              : 'Resend Verification Email',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          foregroundColor:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMedium),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.p20),

                      // Sign out button
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          if (context.mounted) {
                            context.go(RouteNames.login);
                          }
                        },
                        child: Text(
                          'Sign In with Another Account',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
