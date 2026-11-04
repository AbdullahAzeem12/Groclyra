import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/services/storage_service.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/shared/widgets/base64_image.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/features/seller/presentation/controllers/seller_controller.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';

class SellerProfileScreen extends ConsumerStatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  ConsumerState<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _storeNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;

  String? _logoBase64;
  bool _isLoading = false;
  bool _hasUserEditedImage = false;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    final store = ref.read(sellerControllerProvider).store;
    final user = ref.read(authControllerProvider).user;

    _storeNameController = TextEditingController(text: store?.storeName ?? user?.storeName ?? '');
    _ownerNameController = TextEditingController(text: store?.ownerName ?? user?.name ?? '');
    _emailController = TextEditingController(text: store?.email ?? user?.email ?? '');
    _phoneController = TextEditingController(text: store?.phone ?? user?.phone ?? '');
    _categoryController = TextEditingController(text: store?.businessCategory ?? user?.businessCategory ?? '');
    _descriptionController = TextEditingController(text: store?.storeDescription ?? '');
    _addressController = TextEditingController(text: store?.storeAddress ?? '');
    _logoBase64 = store?.logoUrl ?? user?.profileImageBase64;
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _syncDataFromDatabase() {
    final sellerState = ref.read(sellerControllerProvider);
    final user = ref.read(authControllerProvider).user;
    final store = sellerState.store;

    if (store == null && user == null) return;

    if (!_isDataLoaded || _storeNameController.text.isEmpty) {
      if (store?.storeName.isNotEmpty == true) {
        _storeNameController.text = store!.storeName;
      } else if (user?.storeName?.isNotEmpty == true) {
        _storeNameController.text = user!.storeName!;
      }
    }

    if (_ownerNameController.text.isEmpty) {
      if (store?.ownerName?.isNotEmpty == true) {
        _ownerNameController.text = store!.ownerName!;
      } else if (user?.name.isNotEmpty == true) {
        _ownerNameController.text = user!.name;
      }
    }

    if (_emailController.text.isEmpty) {
      if (store?.email?.isNotEmpty == true) {
        _emailController.text = store!.email!;
      } else if (user?.email.isNotEmpty == true) {
        _emailController.text = user!.email;
      }
    }

    if (_phoneController.text.isEmpty) {
      if (store?.phone?.isNotEmpty == true) {
        _phoneController.text = store!.phone!;
      } else if (user?.phone.isNotEmpty == true) {
        _phoneController.text = user!.phone;
      }
    }

    if (_categoryController.text.isEmpty) {
      if (store?.businessCategory?.isNotEmpty == true) {
        _categoryController.text = store!.businessCategory!;
      } else if (user?.businessCategory?.isNotEmpty == true) {
        _categoryController.text = user!.businessCategory!;
      }
    }

    if (_descriptionController.text.isEmpty && store?.storeDescription?.isNotEmpty == true) {
      _descriptionController.text = store!.storeDescription!;
    }

    if (_addressController.text.isEmpty && store?.storeAddress?.isNotEmpty == true) {
      _addressController.text = store!.storeAddress!;
    }

    if (!_hasUserEditedImage && _logoBase64 == null) {
      if (store?.logoUrl?.isNotEmpty == true) {
        _logoBase64 = store!.logoUrl;
      } else if (user?.profileImageBase64?.isNotEmpty == true) {
        _logoBase64 = user!.profileImageBase64;
      }
    }

    _isDataLoaded = true;
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: xFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Store Logo',
            toolbarColor: Colors.deepPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
        ],
      );

      final imageFile = File(cropped != null ? cropped.path : xFile.path);

      // Compress and convert image to Base64
      final base64String = await StorageService.uploadImage(
        imageFile: imageFile,
        storagePath: '',
      );

      if (base64String != null && mounted) {
        setState(() {
          _logoBase64 = base64String;
          _hasUserEditedImage = true;
        });
      }
    } catch (e) {
      debugPrint('Error picking store logo image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{
        'storeName': _storeNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'displayName': _ownerNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'businessCategory': _categoryController.text.trim(),
        'storeDescription': _descriptionController.text.trim(),
        'storeAddress': _addressController.text.trim(),
      };

      if (_logoBase64 != null && _logoBase64!.isNotEmpty) {
        updates['logoUrl'] = _logoBase64!;
      }

      await ref.read(sellerControllerProvider.notifier).updateStoreProfile(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving store profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final sellerState = ref.watch(sellerControllerProvider);
    final store = sellerState.store;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fetch and populate database details into text fields
    _syncDataFromDatabase();

    final isKyc = store?.isKycApproved ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RouteNames.sellerDashboard);
        }
      },
      child: Scaffold(
        appBar: GradientAppBar(
        title: 'Store Profile',
        subtitle: 'Manage your public details',
        leading: SpringTouchScale(
          navigationDelayMs: 165,
          scaleFactor: 0.88,
          pressDepth: 3.5,
          enableRipple: false,
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.sellerDashboard);
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Store Logo Avatar Picker
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121722) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: themeState.palette.primaryColor, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _logoBase64 != null && _logoBase64!.isNotEmpty
                          ? Base64Image(imageUrl: _logoBase64!, fit: BoxFit.cover)
                          : Icon(Icons.storefront_rounded, size: 50, color: themeState.palette.primaryColor),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: themeState.palette.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Tap to change store logo', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),

              // KYC Approval Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isKyc
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isKyc ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isKyc ? Icons.verified_rounded : Icons.pending_actions_rounded,
                      size: 16,
                      color: isKyc ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isKyc ? 'KYC Approved Merchant' : 'KYC Verification Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isKyc ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // SECTION 1: Store & Business Details
              _buildSectionTitle(context, 'Store & Business Information', Icons.store_rounded),
              const SizedBox(height: 14),

              TextFormField(
                controller: _storeNameController,
                decoration: _buildInputDecoration('Store / Brand Name', Icons.storefront_rounded),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Store Name cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _categoryController,
                decoration: _buildInputDecoration('Business Category', Icons.category_outlined, hint: 'e.g. Crockery, Groceries, Bakery'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Business Category cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _buildInputDecoration('Store Description', Icons.description_outlined, hint: 'Write a brief description of your store and products...'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: _buildInputDecoration('Store Address / Location', Icons.location_on_outlined, hint: 'e.g. Main Market, Block 4, Karachi'),
              ),
              const SizedBox(height: 28),

              // SECTION 2: Owner & Contact Information
              _buildSectionTitle(context, 'Owner & Contact Details', Icons.person_rounded),
              const SizedBox(height: 14),

              TextFormField(
                controller: _ownerNameController,
                decoration: _buildInputDecoration('Owner / Merchant Full Name', Icons.person_outline_rounded),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Owner Name cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _buildInputDecoration('Phone Number', Icons.phone_android_rounded),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Phone Number cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration('Email Address', Icons.email_outlined),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email Address cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Save Changes Action Button
              _isLoading
                  ? const CircularProgressIndicator()
                  : GradientButton(
                      text: 'Save Changes',
                      icon: Icons.save_rounded,
                      onPressed: _saveProfile,
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    final themeState = ref.watch(themeControllerProvider);
    return Row(
      children: [
        Icon(icon, size: 20, color: themeState.palette.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        borderSide: BorderSide(
          color: ref.watch(themeControllerProvider).palette.primaryColor,
          width: 2,
        ),
      ),
    );
  }
}
