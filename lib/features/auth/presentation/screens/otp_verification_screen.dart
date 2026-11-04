import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../shared/widgets/gradient_button.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;
  Timer? _resendTimer;
  int _cooldownSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startCooldown(60);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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

  void _verifyOtp() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter 4-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification successful!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.p24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: themeState.palette.subtleGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mark_email_read_rounded, size: 40, color: themeState.palette.primaryColor),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Enter Verification Code',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We have sent a 4-digit SMS OTP code to your registered mobile phone number.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  // 4-Digit OTP Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      return SizedBox(
                        width: 56,
                        height: 56,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                              borderSide: BorderSide(color: themeState.palette.primaryColor, width: 2),
                            ),
                          ),
                          onChanged: (val) {
                            if (val.isNotEmpty && index < 3) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (val.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  GradientButton(
                    text: 'Verify & Confirm',
                    isLoading: _isLoading,
                    onPressed: _verifyOtp,
                  ),
                  const SizedBox(height: 16),

                  TextButton.icon(
                    onPressed: _cooldownSeconds > 0
                        ? null
                        : () {
                            _startCooldown(60);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('New OTP sent via SMS'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      _cooldownSeconds > 0
                          ? 'Resend Code in ${_cooldownSeconds}s'
                          : 'Resend Code via SMS',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
