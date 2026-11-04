import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import '../widgets/profile_image_picker_sheet.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  String? _base64Image;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _base64Image = user?.profileImageBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onPickImage() {
    ProfileImagePickerSheet.show(
      context, 
      onImageCropped: (base64) {
        setState(() {
          _base64Image = base64;
        });
      },
      onRemoveImage: () {
        setState(() {
          _base64Image = null;
        });
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final result = await ref.read(authControllerProvider.notifier).updateProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      profileImageBase64: _base64Image,
    );

    if (mounted) {
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'An unknown error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Edit Profile',
        subtitle: 'Update your personal details',
        showThemePicker: false,
      ),
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileImageSelector(isDark),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.length < 10 ? 'Enter a valid phone number' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address (Cannot be changed here)',
                      icon: Icons.email_outlined,
                      enabled: false,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          ),
                          elevation: 2,
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileImageSelector(bool isDark) {
    final user = ref.read(authControllerProvider).user;
    
    ImageProvider? imageProvider;
    if (_base64Image != null && _base64Image!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(_base64Image!));
      } catch (e) {
        // Fallback if base64 is corrupted
      }
    } 
    
    if (imageProvider == null && user?.avatarUrl != null) {
      imageProvider = NetworkImage(user!.avatarUrl!);
    }
    
    imageProvider ??= const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200');

    return Center(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).primaryColor, width: 3),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: isDark ? const Color(0xFF262E3D) : Colors.grey[200],
              backgroundImage: imageProvider,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: SpringTouchScale(
              onTap: _onPickImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? const Color(0xFF121722) : Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: enabled ? null : Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? Theme.of(context).primaryColor : Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF121722) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}
