import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/rate_limit_service.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/validator_utils.dart';
import '../../../../routing/route_names.dart';
import '../../../../shared/animations/spring_touch_scale.dart';
import '../../data/auth_error_mapper.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/user_entity.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_gradient_button.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/floating_background.dart';
import '../widgets/role_selector_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _rememberMe = true;
  UserRole _selectedRole = UserRole.customer;
  Map<String, String>? _savedCredentials;

  @override
  void initState() {
    super.initState();
    // Initialize selected role from controller state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSelected = ref.read(authControllerProvider).selectedRole;
      setState(() {
        _selectedRole = currentSelected;
      });
      _loadSavedCredentials();
    });
    _emailController.addListener(_onEmailChanged);
  }

  Future<void> _loadSavedCredentials() async {
    final secureStorage = ref.read(secureStorageServiceProvider);
    final creds = await secureStorage.getSavedCredentialsMap();
    if (mounted) {
      setState(() {
        _savedCredentials = creds;
        if (creds.isNotEmpty && _emailController.text.isEmpty) {
          // Pre-fill the last saved one? No, we will just let user type or pre-fill the first one
          _emailController.text = creds.keys.first;
          _passwordController.text = creds.values.first;
          _rememberMe = true;
        }
      });
    }
  }

  void _onEmailChanged() {
    if (_savedCredentials != null && mounted) {
      final email = _emailController.text.trim().toLowerCase();
      // Search in credentials ignoring case
      final matchingKey = _savedCredentials!.keys.cast<String?>().firstWhere(
            (k) => k?.toLowerCase() == email,
            orElse: () => null,
          );

      if (matchingKey != null) {
        if (_passwordController.text != _savedCredentials![matchingKey]) {
          _passwordController.text = _savedCredentials![matchingKey]!;
        }
      } else {
        // If the current password matches ONE of the saved passwords, it means we auto-filled it,
        // but now the email is different, so we should clear the password field.
        if (_passwordController.text.isNotEmpty &&
            _savedCredentials!.values.contains(_passwordController.text)) {
          _passwordController.clear();
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final rateLimit = ref.read(rateLimitServiceProvider);
    if (rateLimit.isLoginLockedOut(email)) {
      final remSec = rateLimit.getRemainingLoginLockoutSeconds(email);
      final remMin = (remSec / 60).ceil();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Account temporarily locked due to multiple failed attempts. Please try again in $remMin minute${remMin > 1 ? 's' : ''}.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await ref.read(authControllerProvider.notifier).login(
          emailOrPhone: email,
          password: _passwordController.text,
          role: _selectedRole,
        );

    if (!mounted) return;

    if (result.isSuccess && result.user != null) {
      // Handle Remember Me logic on successful login
      if (_rememberMe) {
        await ref.read(secureStorageServiceProvider).saveCredentials(
          _emailController.text.trim(),
          _passwordController.text,
        );
        await ref.read(biometricAuthProvider.notifier).saveBiometricSession(
          email: _emailController.text.trim(),
          role: _selectedRole.name,
        );
      } else {
        await ref.read(secureStorageServiceProvider).clearCredentials(_emailController.text.trim());
      }
      
      _navigateByRole(result.user!.role);
    } else if (result.isPendingApproval) {
      context.go(RouteNames.accountPending);
    } else if (result.requiresEmailVerification) {
      context.go(RouteNames.emailVerification);
    }
  }

  Future<void> _handleBiometricLogin() async {
    final bioNotifier = ref.read(biometricAuthProvider.notifier);
    final bioState = ref.read(biometricAuthProvider);

    final success = await bioNotifier.authenticateWithBiometrics(
      reason: 'Scan your fingerprint or face to sign in as ${_selectedRole.displayName}',
    );

    if (success && mounted) {
      final email = bioState.enrolledEmail ?? _emailController.text.trim();
      final result = await ref.read(authControllerProvider.notifier).signInWithBiometricVault(
        email: email,
        role: _selectedRole,
      );
      if (result.isSuccess && mounted) {
        _navigateByRole(_selectedRole);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).clearError();

    final result = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle(role: _selectedRole);

    if (!mounted) return;

    if (result.isSuccess && result.user != null) {
      _navigateByRole(result.user!.role);
    } else if (result.isPendingApproval) {
      context.go(RouteNames.accountPending);
    } else if (result.requiresEmailVerification) {
      context.go(RouteNames.emailVerification);
    }
  }

  void _showPhoneAuthModal() {
    ref.read(authControllerProvider.notifier).clearError();
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    String? verificationId;
    int? resendToken;
    bool isOtpSent = false;
    bool isVerifying = false;
    int resendCooldown = 0;
    Timer? resendCooldownTimer;

    void startModalCooldown(int seconds, void Function(void Function()) setModalState) {
      resendCooldownTimer?.cancel();
      setModalState(() => resendCooldown = seconds);
      resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (resendCooldown <= 1) {
          timer.cancel();
          setModalState(() => resendCooldown = 0);
        } else {
          setModalState(() => resendCooldown--);
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final isDark = Theme.of(modalContext).brightness == Brightness.dark;
        final palette = ref.watch(themeControllerProvider).palette;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.p24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A29) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusLarge),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.p20),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: palette.startColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.phone_iphone_rounded,
                            color: palette.startColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.p12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOtpSent ? 'Enter SMS Code' : 'Phone Authentication',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isOtpSent
                                  ? 'Enter 6-digit verification code'
                                  : 'Sign in to ${_selectedRole.displayName} with mobile OTP',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.p20),

                    if (!isOtpSent) ...[
                      AuthTextField(
                        label: 'Mobile Phone Number',
                        hint: '+92 300 1234567',
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        palette: palette,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppDimensions.p12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: palette.startColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                          border: Border.all(
                            color: palette.startColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: palette.startColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Supports local (03xx) or international (+92) numbers. Auto-formats to E.164 standard.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.p20),
                      AuthGradientButton(
                        text: 'Send Verification Code',
                        isLoading: isVerifying,
                        loadingText: 'Sending OTP...',
                        onPressed: () async {
                          final rawPhone = phoneController.text.trim();
                          if (rawPhone.isEmpty) return;
                          setModalState(() => isVerifying = true);

                          final e164Phone = ValidatorUtils.formatToE164(rawPhone);

                          await ref.read(authControllerProvider.notifier).sendPhoneOtp(
                                phoneNumber: e164Phone,
                                onCodeSent: (id, token) {
                                  setModalState(() {
                                    verificationId = id;
                                    resendToken = token;
                                    isOtpSent = true;
                                    isVerifying = false;
                                  });
                                  startModalCooldown(60, setModalState);
                                },
                                onVerificationFailed: (FirebaseAuthException e) {
                                  setModalState(() => isVerifying = false);
                                  final friendlyMsg = AuthErrorMapper.mapFirebaseAuthException(e);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(friendlyMsg),
                                      backgroundColor: const Color(0xFFEF4444),
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                },
                                onVerificationCompleted: (PhoneAuthCredential credential) async {
                                  // Instant automatic verification on Android
                                  setModalState(() => isVerifying = true);
                                  final result = await ref
                                      .read(authControllerProvider.notifier)
                                      .signInWithPhoneCredential(
                                        credential: credential,
                                        role: _selectedRole,
                                      );
                                  setModalState(() => isVerifying = false);
                                  if (!mounted) return;
                                  if (modalContext.mounted) Navigator.pop(modalContext);

                                  if (result.isSuccess && result.user != null) {
                                    _navigateByRole(result.user!.role);
                                  } else if (result.isPendingApproval) {
                                    context.go(RouteNames.accountPending);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result.message ?? 'Verification failed'),
                                        backgroundColor: const Color(0xFFEF4444),
                                      ),
                                    );
                                  }
                                },
                              );
                        },
                        palette: palette,
                        icon: Icons.send_rounded,
                      ),
                    ] else ...[
                      AuthTextField(
                        label: '6-Digit OTP Code',
                        hint: '123456',
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.lock_clock_outlined, size: 20),
                        palette: palette,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppDimensions.p20),
                      AuthGradientButton(
                        text: 'Verify & Sign In',
                        isLoading: isVerifying,
                        loadingText: 'Verifying OTP...',
                        onPressed: () async {
                          if (verificationId == null || otpController.text.trim().length < 6) return;
                          setModalState(() => isVerifying = true);

                          final result = await ref
                              .read(authControllerProvider.notifier)
                              .signInWithPhoneOtp(
                                verificationId: verificationId!,
                                smsCode: otpController.text.trim(),
                                role: _selectedRole,
                              );

                          setModalState(() => isVerifying = false);

                          if (!mounted) return;
                          if (modalContext.mounted) Navigator.pop(modalContext);

                          if (result.isSuccess && result.user != null) {
                            _navigateByRole(result.user!.role);
                          } else if (result.isPendingApproval) {
                            context.go(RouteNames.accountPending);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message ?? 'OTP verification failed'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
                        palette: palette,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(height: AppDimensions.p12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() => isOtpSent = false);
                            },
                            child: Text(
                              'Change Number',
                              style: TextStyle(
                                color: palette.startColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: (isVerifying || resendCooldown > 0)
                                ? null
                                : () async {
                                    final e164 = ValidatorUtils.formatToE164(phoneController.text);
                                    final rateLimit = ref.read(rateLimitServiceProvider);
                                    if (!rateLimit.canSendOtp(e164)) {
                                      final rem = rateLimit.getRemainingOtpCooldownSeconds(e164);
                                      if (rem > 0) {
                                        startModalCooldown(rem, setModalState);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Please wait $rem seconds before requesting another SMS code.'),
                                            backgroundColor: const Color(0xFFF59E0B),
                                          ),
                                        );
                                        return;
                                      }
                                    }
                                    setModalState(() => isVerifying = true);
                                    await ref.read(authControllerProvider.notifier).sendPhoneOtp(
                                          phoneNumber: e164,
                                          forceResendingToken: resendToken,
                                          onCodeSent: (id, token) {
                                            setModalState(() {
                                              verificationId = id;
                                              resendToken = token;
                                              isVerifying = false;
                                            });
                                            startModalCooldown(60, setModalState);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('New OTP sent via SMS!'),
                                                backgroundColor: Color(0xFF10B981),
                                              ),
                                            );
                                          },
                                          onVerificationFailed: (FirebaseAuthException e) {
                                            setModalState(() => isVerifying = false);
                                            final friendlyMsg = AuthErrorMapper.mapFirebaseAuthException(e);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(friendlyMsg),
                                                backgroundColor: const Color(0xFFEF4444),
                                              ),
                                            );
                                          },
                                          onVerificationCompleted: (PhoneAuthCredential credential) async {
                                            setModalState(() => isVerifying = true);
                                            final result = await ref
                                                .read(authControllerProvider.notifier)
                                                .signInWithPhoneCredential(
                                                  credential: credential,
                                                  role: _selectedRole,
                                                );
                                            setModalState(() => isVerifying = false);
                                            if (!mounted) return;
                                            if (modalContext.mounted) Navigator.pop(modalContext);
                                            if (result.isSuccess && result.user != null) {
                                              _navigateByRole(result.user!.role);
                                            }
                                          },
                                        );
                                  },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              resendCooldown > 0
                                  ? 'Resend OTP (${resendCooldown}s)'
                                  : 'Resend OTP',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: resendCooldown > 0
                                    ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                    : palette.startColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    ).whenComplete(() {
      resendCooldownTimer?.cancel();
      phoneController.dispose();
      otpController.dispose();
    });
  }

  void _navigateByRole(UserRole role) {
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
    final bioState = ref.watch(biometricAuthProvider);
    final palette = themeState.palette;
    final effectiveIsDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = effectiveIsDark;

    return Scaffold(
      backgroundColor: effectiveIsDark ? const Color(0xFF0A0D14) : const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          // Dynamic ambient background
          FloatingBackground(palette: palette, isDark: effectiveIsDark),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.p24,
                  vertical: AppDimensions.p16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Brand Emblem, Back Navigation, and Dynamic Title
                        AuthHeader(
                          title: 'Welcome Back',
                          subtitle:
                              'Enter your credentials to securely access your ${_selectedRole.displayName} workspace.',
                          role: _selectedRole,
                          palette: palette,
                          isDark: effectiveIsDark,
                          onBackPressed: context.canPop()
                              ? () => context.pop()
                              : null,
                        ),
                        const SizedBox(height: AppDimensions.p24),

                        // Role Selector Card Section (2x2 Grid with tactile feedback)
                        RoleSelectorCard(
                          selectedRole: _selectedRole,
                          palette: palette,
                          isDark: effectiveIsDark,
                          onRoleSelected: (role) {
                            setState(() {
                              _selectedRole = role;
                            });
                            ref
                                .read(authControllerProvider.notifier)
                                .selectRole(role);
                          },
                        ),
                        const SizedBox(height: AppDimensions.p24),

                        // Error / Role Mismatch Alert Banner
                        if (authState.errorMessage != null) ...[
                          _buildErrorBanner(authState, palette, effectiveIsDark),
                          const SizedBox(height: AppDimensions.p16),
                        ],

                        // Email Field
                        AuthTextField(
                          key: const ValueKey('login_email'),
                          label: 'Email Address',
                          hint: 'Enter your registered email',
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          validator: ValidatorUtils.validateEmail,
                          autofillHints: const [AutofillHints.email],
                          palette: palette,
                          isDark: effectiveIsDark,
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: AppDimensions.p16),

                        // Password Field
                        AuthTextField(
                          key: const ValueKey('login_password'),
                          label: 'Password',
                          hint: 'Enter your account password',
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          validator: ValidatorUtils.validatePassword,
                          autofillHints: const [AutofillHints.password],
                          palette: palette,
                          isDark: effectiveIsDark,
                          onFieldSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: AppDimensions.p12),

                        // Suboptions: Remember Me + Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.radiusSmall),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppDimensions.p4,
                                  horizontal: AppDimensions.p4,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: palette.startColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            _rememberMe = val ?? true;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: AppDimensions.p8),
                                    Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  context.push(RouteNames.forgotPassword),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.startColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.p24),

                        // Gradient Submit Button with dynamic text
                        AuthGradientButton(
                          text: 'Sign In as ${_selectedRole.displayName}',
                          isLoading: authState.isLoading,
                          loadingText: 'Authenticating...',
                          onPressed: _handleLogin,
                          palette: palette,
                          icon: Icons.login_rounded,
                        ),
                        const SizedBox(height: AppDimensions.p20),

                        // OR Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? const Color(0xFF263248)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? const Color(0xFF263248)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.p16),

                        // Social Auth: Google & Phone
                        Row(
                          children: [
                            Expanded(
                              child: _SocialAuthCard(
                                icon: Icons.g_mobiledata_rounded,
                                iconColor: const Color(0xFFEA4335),
                                label: 'Google',
                                isDark: isDark,
                                onTap: _handleGoogleSignIn,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.p12),
                            Expanded(
                              child: _SocialAuthCard(
                                icon: Icons.phone_iphone_rounded,
                                iconColor: palette.startColor,
                                label: 'Phone OTP',
                                isDark: isDark,
                                onTap: _showPhoneAuthModal,
                              ),
                            ),
                          ],
                        ),

                        // Biometric Quick Login Button
                        if (bioState.isSupported) ...[
                          const SizedBox(height: AppDimensions.p12),
                          SpringTouchScale(
                            onTap: _handleBiometricLogin,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF161E2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                                border: Border.all(
                                  color: palette.primaryColor.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.primaryColor.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    bioState.hasFaceId
                                        ? Icons.face_unlock_rounded
                                        : Icons.fingerprint_rounded,
                                    color: palette.primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Biometric Quick Sign In (${_selectedRole.displayName})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDimensions.p24),

                        // Switch to Register (if not admin) or General Switch
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .clearError();
                                  context.push(RouteNames.register);
                                },
                                child: Text(
                                  'Create account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: palette.startColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
    AuthState authState,
    dynamic palette,
    bool isDark,
  ) {
    final isRoleMismatch = authState.status == AuthResultStatus.roleMismatch;
    final actualRole = authState.actualRole;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.p16),
      decoration: BoxDecoration(
        color: isRoleMismatch
            ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
            : const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(
          color: isRoleMismatch
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isRoleMismatch
                    ? Icons.warning_amber_rounded
                    : Icons.error_outline_rounded,
                color: isRoleMismatch
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: AppDimensions.p12),
              Expanded(
                child: Text(
                  authState.errorMessage ?? 'Authentication error',
                  style: TextStyle(
                    color: isRoleMismatch
                        ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (isRoleMismatch && actualRole != null) ...[
            const SizedBox(height: AppDimensions.p12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedRole = actualRole;
                  });
                  ref.read(authControllerProvider.notifier).selectRole(actualRole);
                  ref.read(authControllerProvider.notifier).clearError();
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text('Switch to ${actualRole.displayName} Portal'),
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF92400E),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SocialAuthCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SocialAuthCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTouchScale(
      onTap: onTap,
      scaleFactor: 0.95,
      pressDepth: 2.0,
      enableRipple: true,
      splashColor: iconColor.withValues(alpha: 0.15),
      highlightColor: iconColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A29) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: AppDimensions.p8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
