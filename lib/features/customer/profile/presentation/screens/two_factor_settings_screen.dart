import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_dimensions.dart';
import '../../../../../core/security/totp_service.dart';
import '../../../../../core/theme/theme_controller.dart';
import '../../../../../shared/widgets/gradient_app_bar.dart';
import '../../../../../shared/widgets/gradient_button.dart';
import '../../../../auth/presentation/controllers/auth_controller.dart';

class TwoFactorSettingsScreen extends ConsumerStatefulWidget {
  const TwoFactorSettingsScreen({super.key});

  @override
  ConsumerState<TwoFactorSettingsScreen> createState() =>
      _TwoFactorSettingsScreenState();
}

class _TwoFactorSettingsScreenState extends ConsumerState<TwoFactorSettingsScreen> {
  bool _isLoading = true;
  bool _is2faEnabled = false;
  List<String> _backupCodes = [];
  TwoFactorSetupData? _setupData;
  final _verificationController = TextEditingController();
  bool _isActivating = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _verificationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final service = ref.read(twoFactorAuthServiceProvider);
    final enabled = await service.is2faEnabled(user.id);
    List<String> codes = [];
    if (enabled) {
      codes = await service.getRemainingBackupCodes(user.id);
    }

    if (mounted) {
      setState(() {
        _is2faEnabled = enabled;
        _backupCodes = codes;
        _isLoading = false;
        _setupData = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _startSetup() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = ref.read(twoFactorAuthServiceProvider);
    final data = await service.initiateSetup(
      userId: user.id,
      userEmail: user.email.isNotEmpty ? user.email : user.name,
    );

    if (mounted) {
      setState(() {
        _setupData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmActivation() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || _setupData == null) return;

    final code = _verificationController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    final service = ref.read(twoFactorAuthServiceProvider);
    final success = await service.confirmActivation(
      userId: user.id,
      code: code,
    );

    if (mounted) {
      setState(() => _isActivating = false);
      if (success) {
        setState(() {
          _is2faEnabled = true;
          _backupCodes = _setupData!.temporaryBackupCodes;
          _successMessage = 'Two-Factor Authentication is now active!';
          _setupData = null;
          _verificationController.clear();
        });
      } else {
        setState(() {
          _errorMessage =
              'Incorrect 6-digit code. Please check your Authenticator app and try again.';
        });
      }
    }
  }

  Future<void> _disable2fa() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable Two-Factor Authentication?'),
        content: const Text(
          'Your account will no longer require a 6-digit code to sign in. This reduces security.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disable 2FA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = ref.read(authControllerProvider).user;
      if (user != null) {
        final service = ref.read(twoFactorAuthServiceProvider);
        await service.disable2fa(user.id);
        await _loadStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('2FA has been disabled.')),
          );
        }
      }
    }
  }

  Future<void> _regenerateBackupCodes() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final service = ref.read(twoFactorAuthServiceProvider);
    final codes = await service.regenerateBackupCodes(user.id);
    if (mounted) {
      setState(() => _backupCodes = codes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('8 new recovery backup codes generated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = ref.watch(themeControllerProvider).palette;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Two-Factor Authentication',
        subtitle: 'RFC 6238 TOTP App Security',
        showThemePicker: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.p20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner Card
                  _buildStatusCard(isDark, palette),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: Colors.green, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // If 2FA is Enabled: show Backup Codes & options
                  if (_is2faEnabled) ...[
                    _buildEnabledSection(isDark, palette),
                  ] else if (_setupData != null) ...[
                    // Setup Wizard in progress
                    _buildSetupWizard(isDark, palette),
                  ] else ...[
                    // Disabled: show promo card and button to begin setup
                    _buildDisabledPromo(isDark, palette),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(bool isDark, dynamic palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: _is2faEnabled
              ? Colors.green.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _is2faEnabled
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _is2faEnabled ? Icons.verified_user_rounded : Icons.shield_outlined,
              color: _is2faEnabled ? Colors.green : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _is2faEnabled ? '2FA Protection Active' : '2FA Protection Disabled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _is2faEnabled ? Colors.green : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _is2faEnabled
                      ? 'Your account is secured with standard RFC 6238 Time-based One-Time Passwords.'
                      : 'Add an extra layer of protection using Google Authenticator or Microsoft Authenticator.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledPromo(bool isDark, dynamic palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildStepTile(
          number: '1',
          title: 'Install an Authenticator App',
          subtitle: 'Download Google Authenticator or Microsoft Authenticator from Play Store / App Store.',
          isDark: isDark,
        ),
        _buildStepTile(
          number: '2',
          title: 'Link Your Secret Key',
          subtitle: 'Enter the generated 16-character cryptographic key into your authenticator app.',
          isDark: isDark,
        ),
        _buildStepTile(
          number: '3',
          title: 'Confirm with 6-Digit Code',
          subtitle: 'Enter the rolling 30-second verification code to activate two-factor protection.',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        GradientButton(
          text: 'Set Up Two-Factor Authentication',
          onPressed: _startSetup,
        ),
      ],
    );
  }

  Widget _buildStepTile({
    required String number,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupWizard(bool isDark, dynamic palette) {
    final setup = _setupData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: Copy Your Secret Key',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2433) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  setup.formattedSecret,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy Key',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: setup.secretKey));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Secret key copied to clipboard ✓')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Open Google or Microsoft Authenticator, tap "+" and select "Enter a setup key". Paste the key above.',
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 24),
        Text(
          'Step 2: Enter 6-Digit Code to Verify',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _verificationController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            letterSpacing: 4,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: '123456',
            labelText: 'Authenticator Code',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _setupData = null),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                text: 'Activate 2FA',
                isLoading: _isActivating,
                onPressed: _confirmActivation,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnabledSection(bool isDark, dynamic palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Emergency Recovery Backup Codes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Regenerate Codes',
              onPressed: _regenerateBackupCodes,
            ),
          ],
        ),
        Text(
          'Keep these codes safe. Each code can be used once if you lose access to your authenticator app.',
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2433) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: _backupCodes.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121722) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Copy All Backup Codes'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _backupCodes.join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All backup codes copied to clipboard ✓')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Disable Two-Factor Authentication'),
            onPressed: _disable2fa,
          ),
        ),
      ],
    );
  }
}

