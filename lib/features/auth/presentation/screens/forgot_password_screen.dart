import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/validator_utils.dart';
import '../../../../core/services/rate_limit_service.dart';
import '../../../../routing/route_names.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_gradient_button.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/floating_background.dart';
import '../../../../shared/animations/spring_touch_scale.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;
  String? _submittedEmail;
  Timer? _resendTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  Future<void> _handleResetPassword() async {
    if (_cooldownSeconds > 0) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final rateLimit = ref.read(rateLimitServiceProvider);
    final remaining = rateLimit.getRemainingPasswordResetCooldownSeconds(email);
    if (remaining > 0) {
      _startCooldown(remaining);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait $remaining seconds before requesting another email.'),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final result = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);

    if (result.isSuccess && mounted) {
      setState(() {
        _emailSent = true;
        _submittedEmail = email;
      });
      _startCooldown(60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final palette = themeState.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          FloatingBackground(palette: palette, isDark: isDark),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.p24,
                  vertical: AppDimensions.p20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unified Header (Back button and GL logo in one line)
                      AuthHeader(
                        title: _emailSent
                            ? 'Check Your Email'
                            : 'Reset Password',
                        subtitle: _emailSent
                            ? 'We have dispatched password recovery instructions to $_submittedEmail.'
                            : 'Enter the registered email associated with your Groclyra account.',
                        palette: palette,
                        isDark: isDark,
                        onBackPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(RouteNames.login),
                      ),
                      const SizedBox(height: AppDimensions.p24),

                      if (_emailSent) ...[
                        // Success confirmation card
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.p20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF131A29)
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMedium),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mark_email_read_outlined,
                                  color: Color(0xFF10B981),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.p16),
                              Text(
                                'Recovery Email Dispatched',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.p8),
                              Text(
                                'Click the link inside the email to set a new password. If you do not see it within a minute, please check your spam folder.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.p24),

                        AuthGradientButton(
                          text: 'Back to Sign In',
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(RouteNames.login);
                            }
                          },
                          palette: palette,
                          icon: Icons.login_rounded,
                        ),
                        const SizedBox(height: AppDimensions.p12),

                        Center(
                          child: TextButton.icon(
                            onPressed: _cooldownSeconds > 0
                                ? null
                                : _handleResetPassword,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              _cooldownSeconds > 0
                                  ? 'Resend email in ${_cooldownSeconds}s'
                                  : 'Did not receive email? Resend',
                              style: TextStyle(
                                color: _cooldownSeconds > 0
                                    ? (isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8))
                                    : palette.startColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Error message if any
                        if (authState.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.p16,
                              vertical: AppDimensions.p12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.radiusSmall),
                              border: Border.all(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 18,
                                ),
                                const SizedBox(width: AppDimensions.p12),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.p16),
                        ],

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              AuthTextField(
                                key: const ValueKey('forgot_email'),
                                label: 'Registered Email Address',
                                hint: 'e.g. name@domain.com',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                prefixIcon:
                                    const Icon(Icons.email_outlined, size: 20),
                                validator: ValidatorUtils.validateEmail,
                                autofillHints: const [AutofillHints.email],
                                palette: palette,
                                isDark: isDark,
                                onFieldSubmitted: (_) => _handleResetPassword(),
                              ),
                              const SizedBox(height: AppDimensions.p24),

                              AuthGradientButton(
                                text: 'Send Reset Link',
                                isLoading: authState.isLoading,
                                loadingText: 'Sending...',
                                onPressed: _handleResetPassword,
                                palette: palette,
                                icon: Icons.send_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.p24),

                        Center(
                          child: SpringTouchScale(
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(RouteNames.login);
                              }
                            },
                            navigationDelayMs: 165,
                            scaleFactor: 0.90,
                            pressDepth: 1.5,
                            enableRipple: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_back_rounded, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Back to Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
