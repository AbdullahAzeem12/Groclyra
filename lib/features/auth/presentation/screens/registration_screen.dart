import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/rate_limit_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/validator_utils.dart';
import '../../../../routing/route_names.dart';
import '../../domain/entities/password_strength.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/rider_location.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_gradient_button.dart';
import '../widgets/location_selector_bottom_sheet.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/floating_background.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/role_selector_card.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Shared Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Role Specific Controllers
  final _storeNameController = TextEditingController();
  final _businessCategoryController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _zoneController = TextEditingController();
  final _cnicController = TextEditingController();
  final _drivingLicenseController = TextEditingController();
  final _adminIdController = TextEditingController();
  final _adminDepartmentController = TextEditingController();

  // Focus Nodes
  final _nameFocusNode = FocusNode();
  final _storeNameFocusNode = FocusNode();
  final _businessCategoryFocusNode = FocusNode();
  final _vehicleFocusNode = FocusNode();
  final _zoneFocusNode = FocusNode();
  final _cnicFocusNode = FocusNode();
  final _drivingLicenseFocusNode = FocusNode();
  final _adminIdFocusNode = FocusNode();
  final _adminDepartmentFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  // Admin Unlock State (5-Tap secret unlock mechanism)
  bool _isAdminUnlocked = false;
  int _adminTapCount = 0;
  DateTime? _lastAdminTapTime;

  RiderLocation? _riderLocation;


  UserRole _selectedRole = UserRole.customer;
  bool _agreeToTerms = false;
  PasswordStrength _passwordStrength =
      const PasswordStrength(
        password: '',
        hasMinLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasNumber: false,
        hasSpecialChar: false,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentRole = ref.read(authControllerProvider).selectedRole;
      if (currentRole != UserRole.admin) {
        setState(() {
          _selectedRole = currentRole;
        });
      }
    });

    _passwordController.addListener(() {
      setState(() {
        _passwordStrength =
            PasswordStrength.evaluate(_passwordController.text);
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();
    _businessCategoryController.dispose();
    _vehicleController.dispose();
    _zoneController.dispose();
    _cnicController.dispose();
    _drivingLicenseController.dispose();
    _adminIdController.dispose();
    _adminDepartmentController.dispose();
    _nameFocusNode.dispose();
    _storeNameFocusNode.dispose();
    _businessCategoryFocusNode.dispose();
    _vehicleFocusNode.dispose();
    _zoneFocusNode.dispose();
    _cnicFocusNode.dispose();
    _drivingLicenseFocusNode.dispose();
    _adminIdFocusNode.dispose();
    _adminDepartmentFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  String _generateUniqueAdminId() {
    final randomPart = (100000 + math.Random().nextInt(900000)).toString();
    return 'ADM-HQ-$randomPart';
  }

  void _handleLockedAdminTap() {
    if (_isAdminUnlocked) return;

    // Upgraded (security): the secret tap-unlock is a developer/demo
    // convenience and is now active only in debug builds. In release builds
    // the taps silently do nothing beyond the generic hint below.
    if (!kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin access is provisioned by the platform office.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (_lastAdminTapTime == null ||
        now.difference(_lastAdminTapTime!).inSeconds > 3) {
      _adminTapCount = 1;
    } else {
      _adminTapCount++;
    }
    _lastAdminTapTime = now;

    if (_adminTapCount < 5) {
      HapticFeedback.lightImpact();
      final remaining = 5 - _adminTapCount;
      if (_adminTapCount >= 2) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tap $remaining more time${remaining > 1 ? 's' : ''} to unlock Admin Portal registration...',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            duration: const Duration(milliseconds: 900),
            backgroundColor: const Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isAdminUnlocked = true;
        _selectedRole = UserRole.admin;
        if (_adminIdController.text.trim().isEmpty) {
          _adminIdController.text = _generateUniqueAdminId();
        }
        if (_adminDepartmentController.text.trim().isEmpty) {
          _adminDepartmentController.text = 'Executive Operations & Audit';
        }
      });
      ref.read(authControllerProvider.notifier).selectRole(UserRole.admin);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚡ Platform Administrator Registration Unlocked! Unique Admin ID assigned.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _adminTapCount = 0;
    }
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    if (_selectedRole == UserRole.admin && !_isAdminUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin registration is restricted. Tap the locked Admin card 5 times to unlock access.',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Terms of Service and Privacy Policy to continue.',
          ),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final rateLimit = ref.read(rateLimitServiceProvider);
    if (!rateLimit.canRegister()) {
      final rem = rateLimit.getRemainingRegistrationCooldownSeconds();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rem > 0
                ? 'Please wait $rem seconds before attempting another registration.'
                : 'Registration limit reached for this session. Please try again later.',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final result = await ref.read(authControllerProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          storeName: _selectedRole == UserRole.seller
              ? _storeNameController.text.trim()
              : null,
          businessCategory: _selectedRole == UserRole.seller
              ? _businessCategoryController.text.trim()
              : null,
          vehicleNumber: _selectedRole == UserRole.rider
              ? _vehicleController.text.trim()
              : null,
          deliveryZone: _selectedRole == UserRole.rider
              ? _zoneController.text.trim()
              : null,
          deliveryLocation: _selectedRole == UserRole.rider ? _riderLocation : null,
          adminId: _selectedRole == UserRole.admin
              ? _adminIdController.text.trim()
              : null,
          adminDepartment: _selectedRole == UserRole.admin
              ? _adminDepartmentController.text.trim()
              : null,
          cnicNumber: _selectedRole == UserRole.rider
              ? _cnicController.text.trim()
              : null,
          drivingLicenseNumber: _selectedRole == UserRole.rider
              ? _drivingLicenseController.text.trim()
              : null,
        );

    if (!mounted) return;

    if (result.isSuccess && result.user != null) {
      if (_selectedRole == UserRole.customer) {
        context.go(RouteNames.emailVerification);
      } else if (_selectedRole == UserRole.admin) {
        context.go(RouteNames.adminDashboard);
      } else {
        context.go(RouteNames.accountPending);
      }
    } else if (result.isPendingApproval) {
      context.go(RouteNames.accountPending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final palette = themeState.palette;
    final effectiveIsDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: effectiveIsDark ? const Color(0xFF0A0D14) : const Color(0xFFF8F9FD),
      body: Stack(
        children: [
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
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Unified Header (Back button, GL Logo, and Portal Name in one systematic line)
                        AuthHeader(
                          title: 'Join Groclyra',
                          subtitle: _selectedRole == UserRole.customer
                              ? 'Create your customer account to start shopping premium groceries and crockery.'
                              : _selectedRole == UserRole.seller
                                  ? 'Register your store to reach thousands of neighborhood shoppers.'
                                  : _selectedRole == UserRole.rider
                                      ? 'Become a delivery partner and earn with every verified delivery.'
                                      : 'Administrative access governance portal.',
                          role: _selectedRole,
                          palette: palette,
                          isDark: effectiveIsDark,
                          onBackPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(RouteNames.login),
                        ),
                        const SizedBox(height: AppDimensions.p24),

                        // Role Selector
                        RoleSelectorCard(
                          selectedRole: _selectedRole,
                          palette: palette,
                          isDark: effectiveIsDark,
                          disableAdmin: !_isAdminUnlocked,
                          onLockedAdminTap: _handleLockedAdminTap,
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

                        // Admin disclaimer or Role-Specific Form
                        if (_selectedRole == UserRole.admin && !_isAdminUnlocked) ...[
                          _buildAdminRestrictionCard(palette, effectiveIsDark),
                        ] else ...[
                          // Error banner
                          if (authState.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(AppDimensions.p16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSmall),
                                border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppDimensions.p12),
                                  Expanded(
                                    child: Text(
                                      authState.errorMessage!,
                                      style: TextStyle(
                                        color: effectiveIsDark
                                            ? const Color(0xFFFCA5A5)
                                            : const Color(0xFF991B1B),
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

                          // Admin Unlocked Security Banner
                          if (_selectedRole == UserRole.admin && _isAdminUnlocked) ...[
                            Container(
                              padding: const EdgeInsets.all(AppDimensions.p16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: Color(0xFF10B981),
                                    size: 22,
                                  ),
                                  const SizedBox(width: AppDimensions.p12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Admin Registration Unlocked',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Enterprise root credential mode active. Unique ID automatically provisioned.',
                                          style: TextStyle(
                                            color: effectiveIsDark
                                                ? const Color(0xFFA7F3D0)
                                                : const Color(0xFF065F46),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                          ],

                          // Full Name
                          AuthTextField(
                            key: const ValueKey('reg_name'),
                            label: _selectedRole == UserRole.seller
                                ? 'Owner / Contact Person Full Name'
                                : _selectedRole == UserRole.admin
                                    ? 'Administrator Full Name'
                                    : 'Full Name',
                            hint: 'e.g. John Doe',
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            validator: (v) => ValidatorUtils.validateRequired(
                                v, 'Full Name'),
                            autofillHints: const [AutofillHints.name],
                            palette: palette,
                            isDark: effectiveIsDark,
                            onFieldSubmitted: (_) {
                              if (_selectedRole == UserRole.seller) {
                                _storeNameFocusNode.requestFocus();
                              } else if (_selectedRole == UserRole.rider) {
                                _vehicleFocusNode.requestFocus();
                              } else if (_selectedRole == UserRole.admin) {
                                _adminIdFocusNode.requestFocus();
                              } else {
                                _emailFocusNode.requestFocus();
                              }
                            },
                          ),
                          const SizedBox(height: AppDimensions.p16),

                          // Role Specific: Seller store & category
                          if (_selectedRole == UserRole.seller) ...[
                            AuthTextField(
                              key: const ValueKey('reg_seller_store'),
                              label: 'Store / Brand Name',
                              hint: 'e.g. Royal Fresh Organics',
                              controller: _storeNameController,
                              focusNode: _storeNameFocusNode,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              prefixIcon:
                                  const Icon(Icons.storefront_rounded, size: 20),
                              validator: (v) => ValidatorUtils.validateRequired(
                                  v, 'Store Name'),
                              palette: palette,
                              isDark: effectiveIsDark,
                              onFieldSubmitted: (_) =>
                                  _businessCategoryFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                            AuthTextField(
                              key: const ValueKey('reg_seller_category'),
                              label: 'Business Category',
                              hint: 'e.g. Groceries, Crockery, Bakery',
                              controller: _businessCategoryController,
                              focusNode: _businessCategoryFocusNode,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(Icons.category_outlined,
                                  size: 20),
                              validator: (v) => ValidatorUtils.validateRequired(
                                  v, 'Business Category'),
                              palette: palette,
                              isDark: effectiveIsDark,
                              onFieldSubmitted: (_) =>
                                  _emailFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                          ],

                          // Role Specific: Rider vehicle & zone
                          if (_selectedRole == UserRole.rider) ...[
                            AuthTextField(
                              key: const ValueKey('reg_rider_vehicle'),
                              label: 'Vehicle Plate Number',
                              hint: 'e.g. KHI-ABC-1234',
                              controller: _vehicleController,
                              focusNode: _vehicleFocusNode,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(
                                  Icons.two_wheeler_rounded,
                                  size: 20),
                              validator: (v) => ValidatorUtils.validateRequired(
                                  v, 'Vehicle Info'),
                              palette: palette,
                              isDark: effectiveIsDark,
                              onFieldSubmitted: (_) =>
                                  _zoneFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                            AuthTextField(
                              key: const ValueKey('reg_rider_zone'),
                              label: 'Preferred Delivery Zone / City',
                              hint: 'Tap to select location',
                              controller: _zoneController,
                              focusNode: _zoneFocusNode,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              readOnly: true,
                              onTap: () async {
                                final RiderLocation? loc = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => const LocationSelectorBottomSheet(),
                                );
                                if (loc != null) {
                                  setState(() {
                                    _riderLocation = loc;
                                    _zoneController.text = loc.formattedAddress ?? '';
                                  });
                                }
                              },
                              prefixIcon:
                                  const Icon(Icons.location_on_outlined, size: 20),
                              validator: (v) => ValidatorUtils.validateRequired(
                                  v, 'Delivery Zone'),
                              palette: palette,
                              isDark: effectiveIsDark,
                              onFieldSubmitted: (_) =>
                                  _cnicFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                            AuthTextField(
                              key: const ValueKey('reg_rider_cnic'),
                              label: 'CNIC Number',
                              hint: 'e.g. 42101-1234567-1',
                              controller: _cnicController,
                              focusNode: _cnicFocusNode,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(
                                  Icons.badge_outlined,
                                  size: 20),
                              validator: ValidatorUtils.validateCnic,
                              palette: palette,
                              isDark: effectiveIsDark,
                              onFieldSubmitted: (_) =>
                                  _drivingLicenseFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                            AuthTextField(
                              key: const ValueKey('reg_rider_license'),
                              label: 'Driving License Number',
                              hint: 'e.g. DL-1234567',
                              controller: _drivingLicenseController,
                              focusNode: _drivingLicenseFocusNode,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(
                                  Icons.card_membership_outlined,
                                  size: 20),
                              validator: ValidatorUtils.validateDrivingLicense,
                              palette: palette,
                              isDark: effectiveIsDark,
                              onFieldSubmitted: (_) =>
                                  _emailFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                          ],

                          // Role Specific: Admin ID & Department
                          if (_selectedRole == UserRole.admin) ...[
                            AuthTextField(
                              key: const ValueKey('reg_admin_id'),
                              label: 'Unique Admin ID',
                              hint: 'e.g. ADM-HQ-948201',
                              controller: _adminIdController,
                              focusNode: _adminIdFocusNode,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                              suffixIcon: IconButton(
                                tooltip: 'Generate New Unique ID',
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                  color: palette.startColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _adminIdController.text = _generateUniqueAdminId();
                                  });
                                },
                              ),
                              validator: (v) => ValidatorUtils.validateRequired(
                                  v, 'Unique Admin ID'),
                              palette: palette,
                              isDark: effectiveIsDark,
                              onFieldSubmitted: (_) =>
                                  _adminDepartmentFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                            AuthTextField(
                              key: const ValueKey('reg_admin_department'),
                              label: 'Admin Department / Authority',
                              hint: 'e.g. Executive Operations & Audit',
                              controller: _adminDepartmentController,
                              focusNode: _adminDepartmentFocusNode,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                              validator: (v) => ValidatorUtils.validateRequired(
                                  v, 'Admin Department'),
                              palette: palette,
                              isDark: effectiveIsDark,
                              onFieldSubmitted: (_) =>
                                  _emailFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppDimensions.p16),
                          ],

                          // Email
                          AuthTextField(
                            key: const ValueKey('reg_email'),
                            label: 'Email Address',
                            hint: 'Enter active email address',
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon:
                                const Icon(Icons.email_outlined, size: 20),
                            validator: ValidatorUtils.validateEmail,
                            autofillHints: const [AutofillHints.email],
                            palette: palette,
                            isDark: effectiveIsDark,
                            onFieldSubmitted: (_) =>
                                _phoneFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: AppDimensions.p16),

                          // Phone
                          AuthTextField(
                            key: const ValueKey('reg_phone'),
                            label: 'Phone Number',
                            hint: 'e.g. 03001234567',
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            prefixIcon:
                                const Icon(Icons.phone_outlined, size: 20),
                            validator: ValidatorUtils.validatePhone,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            palette: palette,
                            isDark: effectiveIsDark,
                            onFieldSubmitted: (_) =>
                                _passwordFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: AppDimensions.p16),

                          // Password
                          AuthTextField(
                            key: const ValueKey('reg_password'),
                            label: 'Create Password',
                            hint: 'Min 8 characters with letters & numbers',
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            prefixIcon:
                                const Icon(Icons.lock_outline_rounded, size: 20),
                            validator: ValidatorUtils.validatePassword,
                            palette: palette,
                            isDark: effectiveIsDark,
                            onFieldSubmitted: (_) =>
                                _confirmPasswordFocusNode.requestFocus(),
                          ),

                          // Real-time password strength meter
                          PasswordStrengthIndicator(
                            strength: _passwordStrength,
                            isDark: effectiveIsDark,
                          ),
                          const SizedBox(height: AppDimensions.p16),

                          // Confirm Password
                          AuthTextField(
                            key: const ValueKey('reg_confirm_password'),
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocusNode,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            prefixIcon: const Icon(
                                Icons.lock_reset_rounded,
                                size: 20),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (val != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            palette: palette,
                            isDark: effectiveIsDark,
                            onFieldSubmitted: (_) => _handleRegister(),
                          ),
                          const SizedBox(height: AppDimensions.p16),

                          // Terms and Conditions checkbox
                          InkWell(
                            onTap: () {
                              setState(() {
                                _agreeToTerms = !_agreeToTerms;
                              });
                            },
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.p4,
                                horizontal: 2.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _agreeToTerms,
                                      activeColor: palette.startColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _agreeToTerms = val ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10.0),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: effectiveIsDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                        ),
                                        children: [
                                          const TextSpan(
                                              text: 'I agree to the Groclyra '),
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: TextStyle(
                                              color: palette.startColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: TextStyle(
                                              color: palette.startColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.p24),

                          // Submit Button with Dynamic Label
                          AuthGradientButton(
                            text: _selectedRole == UserRole.customer
                                ? 'Create Customer Account'
                                : _selectedRole == UserRole.seller
                                    ? 'Submit Seller Application'
                                    : _selectedRole == UserRole.rider
                                        ? 'Submit Rider Application'
                                        : 'Register Platform Administrator',
                            isLoading: authState.isLoading,
                            loadingText: 'Creating Account...',
                            onPressed: _handleRegister,
                            palette: palette,
                            icon: Icons.person_add_alt_1_rounded,
                          ),
                        ],
                        const SizedBox(height: AppDimensions.p24),

                        // Switch to Sign In
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: effectiveIsDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .clearError();
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.push(RouteNames.login);
                                  }
                                },
                                child: Text(
                                  'Sign In',
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
                        const SizedBox(height: AppDimensions.p24),
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

  Widget _buildAdminRestrictionCard(dynamic palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.p20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFFF59E0B),
              size: 32,
            ),
          ),
          const SizedBox(height: AppDimensions.p16),
          Text(
            'Admin Accounts Are Provisioned',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: AppDimensions.p8),
          Text(
            'Platform Administrator roles are restricted by default. Tap the locked Admin card 5 times to unlock platform administrator self-registration, or sign in if you already hold administrative credentials.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: AppDimensions.p20),
          AuthGradientButton(
            text: 'Sign In to Admin Portal',
            onPressed: () {
              ref
                  .read(authControllerProvider.notifier)
                  .selectRole(UserRole.admin);
              if (context.canPop()) {
                context.pop();
              } else {
                context.push(RouteNames.login);
              }
            },
            palette: palette,
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }
}
