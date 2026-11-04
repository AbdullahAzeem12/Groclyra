import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_colors.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/services/storage_service.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/seller/presentation/controllers/seller_controller.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/features/seller/products/presentation/screens/pos_connection_center_dialog.dart';

class AddProductWizardScreen extends ConsumerStatefulWidget {
  const AddProductWizardScreen({super.key});

  @override
  ConsumerState<AddProductWizardScreen> createState() =>
      _AddProductWizardScreenState();
}

class _AddProductWizardScreenState extends ConsumerState<AddProductWizardScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _progressController;
  late final AnimationController _slideController;
  late Animation<double> _progressAnimation;

  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1 — Category & Basics
  MainCategoryType _selectedPillar = MainCategoryType.crockery;
  String _selectedCategoryName = 'Dinner Sets';
  final _titleController = TextEditingController();
  final _brandController = TextEditingController();
  final _descController = TextEditingController();

  // Step 2 — Technical Specs
  String _crockeryMaterial = 'Bone China';
  bool _isMicrowaveSafe = false;
  bool _isDishwasherSafe = true;
  int _piecesCount = 24;

  final _groceryWeightController = TextEditingController(text: '1 kg');
  bool _isHalalCertified = true;
  bool _isOrganic = false;

  final _restaurantNameController = TextEditingController();
  String _restaurantType = 'restaurant';
  String _cuisineType = 'Pakistani';
  int _preparationTimeMinutes = 20;
  bool _isVegetarian = false;

  // Step 2 — Dairy & Bakery Specs
  String _dairyUnit = 'kg';                       // ml / L / g / kg / pcs
  final _dairyPackageSizeController = TextEditingController(text: '500');
  int _expiryDays = 7;
  String _storageTemp = '2–8 °C (Refrigerated)'; // storage requirement
  final _fatPercentController = TextEditingController(text: '3.5');
  bool _isDairyHalal = true;
  bool _isDairyOrganic = false;
  bool _isLactoseFree = false;
  bool _isGlutenFree = false;
  bool _isVegan = false;
  String _dairySubCategory = 'Dairy Products';   // Dairy Products / Bakery Items
  // Bakery-specific
  String _bakeryType = 'Bread & Loaves';          // sub-category chip
  final _ingredientsController = TextEditingController();
  final _allergensController = TextEditingController();

  // Step 3 — Images
  final List<File> _selectedImages = [];
  double _uploadProgress = 0.0;
  bool _isUploadingImages = false;

  // Step 4 — Pricing & Stock
  final _basePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _stockController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage; // ignore: unused_field

  // Step form keys
  final _step1Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  String? _externalPosId;
  String? _posProvider;
  List<String> _importedImages = [];

  void _importFromPos(ProductEntity product) {
    setState(() {
      _titleController.text = product.title;
      _brandController.text = product.brand;
      _descController.text = product.description;
      _basePriceController.text = product.basePrice.toStringAsFixed(0);
      _salePriceController.text = product.salePrice.toStringAsFixed(0);
      _stockController.text = product.totalStock.toString();
      _selectedPillar = product.categoryType;
      _selectedCategoryName = product.categoryName;

      // Map Restaurant / Fast Food fields
      if (product.restaurantName != null) {
        _restaurantNameController.text = product.restaurantName!;
      }
      if (product.restaurantType != null) {
        _restaurantType = product.restaurantType!;
      }
      if (product.cuisineType != null) {
        _cuisineType = product.cuisineType!;
      }
      if (product.preparationTimeMinutes != null) {
        _preparationTimeMinutes = product.preparationTimeMinutes!;
      }
      if (product.isVegetarian != null) {
        _isVegetarian = product.isVegetarian!;
      }

      // Map Dairy & Bakery fields
      if (product.categoryType == MainCategoryType.dairyBakery) {
        if (product.subcategoryName != null && product.subcategoryName!.isNotEmpty) {
          _dairySubCategory = product.subcategoryName!;
        }
        if (product.unit != null && product.unit!.isNotEmpty) {
          _dairyUnit = product.unit!;
        }
        if (product.packageSize != null) {
          _dairyPackageSizeController.text = product.packageSize!;
        }
        if (product.expiryDays != null) {
          _expiryDays = product.expiryDays!;
        }
        if (product.storageTemp != null && product.storageTemp!.isNotEmpty) {
          _storageTemp = product.storageTemp!;
        }
        if (product.nutritionFacts != null && product.nutritionFacts!['Fat'] != null) {
          _fatPercentController.text = product.nutritionFacts!['Fat']!.replaceAll('%', '').trim();
        }
        if (product.ingredients != null && product.ingredients!.isNotEmpty) {
          _ingredientsController.text = product.ingredients!.join(', ');
        }
        if (product.allergens != null && product.allergens!.isNotEmpty) {
          _allergensController.text = product.allergens!.join(', ');
        }
        if (product.isHalal != null) {
          _isDairyHalal = product.isHalal!;
        }
        if (product.isOrganic != null) {
          _isDairyOrganic = product.isOrganic!;
        }
      }

      _externalPosId = product.externalPosId;
      _posProvider = product.categoryType == MainCategoryType.dairyBakery
          ? 'Dairy & Bakery Catalog'
          : (product.posProvider ?? 'Foodics POS');
      _importedImages = List.from(product.images);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Imported "${product.title}" into listing form!',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _updateProgress(animate: false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _slideController.dispose();
    _titleController.dispose();
    _brandController.dispose();
    _descController.dispose();
    _groceryWeightController.dispose();
    _restaurantNameController.dispose();
    _basePriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    // Dairy & Bakery controllers
    _dairyPackageSizeController.dispose();
    _fatPercentController.dispose();
    _ingredientsController.dispose();
    _allergensController.dispose();
    super.dispose();
  }

  void _updateProgress({bool animate = true}) {
    final target = (_currentStep + 1) / _totalSteps;
    if (animate) {
      _progressAnimation = Tween<double>(
        begin: _currentStep / _totalSteps,
        end: target,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ));
      _progressController.forward(from: 0);
    } else {
      _progressAnimation = AlwaysStoppedAnimation(target);
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_titleController.text.trim().isEmpty) {
        _showError('Product title is required.');
        return false;
      }
      if (_descController.text.trim().isEmpty) {
        _showError('Please add a short description.');
        return false;
      }
    }
    if (_currentStep == 3) {
      final base = double.tryParse(_basePriceController.text);
      if (base == null || base <= 0) {
        _showError('Please enter a valid base price.');
        return false;
      }
      final sale = double.tryParse(_salePriceController.text);
      if (sale != null && sale > base) {
        _showError('Sale price cannot be higher than base price.');
        return false;
      }
      final stock = int.tryParse(_stockController.text);
      if (stock == null || stock < 0) {
        _showError('Please enter a valid stock quantity (0 or more).');
        return false;
      }
    }
    return true;
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _goToStep(int step) {
    if (step > _currentStep && !_validateCurrentStep()) return;
    setState(() {
      _errorMessage = null;
      _currentStep = step;
    });
    _updateProgress();
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _next() => _goToStep(_currentStep + 1);
  void _prev() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RouteNames.sellerProducts);
      }
    }
  }

  Future<void> _pickImage() async {
    final file = await StorageService.pickImageFromGallery();
    if (file != null && mounted) {
      setState(() => _selectedImages.add(file));
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _pickImageFromCamera() async {
    final file = await StorageService.pickImageFromCamera();
    if (file != null && mounted) {
      setState(() => _selectedImages.add(file));
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _submitProduct() async {
    if (!_validateCurrentStep()) return;

    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      _showError('You must be logged in as a seller.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isUploadingImages = true;
      _errorMessage = null;
    });

    try {
      final productId = 'prod_${DateTime.now().millisecondsSinceEpoch}';

      // ── Upload images ─────────────────────────────────────────────────────
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await StorageService.uploadProductImages(
          images: _selectedImages,
          sellerId: user.id,
          productId: productId,
          onProgress: (curr, total) {
            if (mounted) {
              setState(() => _uploadProgress = curr / total);
            }
          },
        );
      }

      // Fallback images if none selected
      if (imageUrls.isEmpty) {
        if (_importedImages.isNotEmpty) {
          imageUrls = _importedImages;
        } else {
          imageUrls = [
            if (_selectedPillar == MainCategoryType.crockery)
              'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=800'
            else if (_selectedPillar == MainCategoryType.grocery)
              'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800'
            else if (_selectedPillar == MainCategoryType.dairyBakery)
              'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=800'
            else
              'https://images.unsplash.com/photo-1562967914-608f82629710?w=800',
          ];
        }
      }

      setState(() => _isUploadingImages = false);

      // ── Build product entity ──────────────────────────────────────────────
      final basePrice =
          double.tryParse(_basePriceController.text.trim()) ?? 0.0;
      final salePrice =
          double.tryParse(_salePriceController.text.trim()) ?? basePrice;
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;
      final discount = basePrice > salePrice
          ? (((basePrice - salePrice) / basePrice) * 100).toInt()
          : 0;

      final newProduct = ProductEntity(
        id: productId,
        title: _titleController.text.trim(),
        shortDescription: _descController.text.trim(),
        description: _descController.text.trim(),
        categoryType: _selectedPillar,
        categoryName: _selectedCategoryName,
        brand: _brandController.text.trim().isNotEmpty
            ? _brandController.text.trim()
            : 'Generic',
        sellerId: user.id,
        sellerName: user.name,
        basePrice: basePrice,
        salePrice: salePrice,
        discountPercentage: discount,
        rating: 0.0,
        reviewCount: 0,
        soldCount: 0,
        totalStock: stock,
        images: imageUrls,
        variants: [
          ProductVariant(
            id: 'var_base_$productId',
            sku: 'SKU-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Standard',
            price: salePrice,
            compareAtPrice: basePrice,
            stock: stock,
          ),
        ],
        // Crockery
        material: _selectedPillar == MainCategoryType.crockery
            ? _crockeryMaterial
            : null,
        piecesCount: _selectedPillar == MainCategoryType.crockery
            ? _piecesCount
            : null,
        isMicrowaveSafe: _selectedPillar == MainCategoryType.crockery
            ? _isMicrowaveSafe
            : null,
        isDishwasherSafe: _selectedPillar == MainCategoryType.crockery
            ? _isDishwasherSafe
            : null,
        // Grocery
        weightVolume: _selectedPillar == MainCategoryType.grocery
            ? _groceryWeightController.text.trim()
            : null,
        // Fast Food
        restaurantName: _selectedPillar == MainCategoryType.fastFood &&
                _restaurantNameController.text.trim().isNotEmpty
            ? _restaurantNameController.text.trim()
            : null,
        restaurantType: _selectedPillar == MainCategoryType.fastFood
            ? _restaurantType
            : null,
        cuisineType: _selectedPillar == MainCategoryType.fastFood
            ? _cuisineType
            : null,
        preparationTimeMinutes: _selectedPillar == MainCategoryType.fastFood
            ? _preparationTimeMinutes
            : null,
        isVegetarian: _selectedPillar == MainCategoryType.fastFood
            ? _isVegetarian
            : null,
        // Dairy & Bakery
        unit: _selectedPillar == MainCategoryType.dairyBakery
            ? _dairyUnit
            : null,
        packageSize: _selectedPillar == MainCategoryType.dairyBakery
            ? _dairyPackageSizeController.text.trim()
            : null,
        expiryDays: _selectedPillar == MainCategoryType.dairyBakery
            ? _expiryDays
            : null,
        storageTemp: _selectedPillar == MainCategoryType.dairyBakery
            ? _storageTemp
            : null,
        nutritionFacts: _selectedPillar == MainCategoryType.dairyBakery &&
                _dairySubCategory == 'Dairy Products' &&
                _fatPercentController.text.trim().isNotEmpty
            ? {'Fat %': _fatPercentController.text.trim()}
            : null,
        ingredients: _selectedPillar == MainCategoryType.dairyBakery &&
                _ingredientsController.text.trim().isNotEmpty
            ? _ingredientsController.text
                .trim()
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : null,
        allergens: _selectedPillar == MainCategoryType.dairyBakery &&
                _allergensController.text.trim().isNotEmpty
            ? _allergensController.text
                .trim()
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : null,
        isHalal: _selectedPillar == MainCategoryType.dairyBakery
            ? _isDairyHalal
            : null,
        isOrganic: _selectedPillar == MainCategoryType.dairyBakery
            ? _isDairyOrganic
            : null,
        subcategoryName: _selectedPillar == MainCategoryType.dairyBakery
            ? _dairySubCategory
            : null,
        dietaryFlags: _selectedPillar == MainCategoryType.dairyBakery
            ? [
                if (_isDairyHalal) 'Halal Certified',
                if (_isDairyOrganic) 'Organic',
                if (_isLactoseFree) 'Lactose Free',
                if (_isGlutenFree) 'Gluten Free',
                if (_isVegan) 'Vegan',
              ]
            : _selectedPillar == MainCategoryType.grocery
                ? [
                    if (_isHalalCertified) 'Halal Certified',
                    if (_isOrganic) 'Organic',
                  ]
                : null,
        externalPosId: _externalPosId,
        posProvider: _posProvider,
        isApproved: true, // Auto-approved for KYC-verified sellers
      );


      // ── Save to Firestore ─────────────────────────────────────────────────
      final success = await ref
          .read(sellerControllerProvider.notifier)
          .createProduct(newProduct);

      if (!mounted) return;

      if (!success) {
        final errMsg = ref.read(sellerControllerProvider).errorMessage;
        _showError(errMsg ?? 'Failed to save product. Please try again.');
        setState(() => _isSubmitting = false);
        return;
      }

      // ── Success dialog ────────────────────────────────────────────────────
      HapticFeedback.mediumImpact();
      await _showSuccessDialog(newProduct);
    } catch (e) {
      if (mounted) {
        _showError('Unexpected error: $e');
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showSuccessDialog(ProductEntity product) async {
    final themeState = ref.read(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF1A2035) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated success icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    themeState.palette.primaryColor,
                    themeState.palette.secondaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeState.palette.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Listing Published! 🎉',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '"${product.title}" is now live in the ${product.categoryType.title} catalog.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: themeState.palette.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Stock: ${product.totalStock} units  •  Rs. ${product.salePrice.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: themeState.palette.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Reset form for another product
                      setState(() {
                        _currentStep = 0;
                        _titleController.clear();
                        _brandController.clear();
                        _descController.clear();
                        _basePriceController.clear();
                        _salePriceController.clear();
                        _stockController.clear();
                        _selectedImages.clear();
                        _isSubmitting = false;
                        _uploadProgress = 0;
                      });
                      _updateProgress(animate: false);
                      _pageController.jumpToPage(0);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMedium),
                      ),
                    ),
                    child: const Text('Add Another'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go(RouteNames.sellerProducts);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: themeState.palette.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMedium),
                      ),
                    ),
                    child: const Text('View Listings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = themeState.palette.primaryColor;
    final secondary = themeState.palette.secondaryColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _prev();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // ── Custom AppBar ────────────────────────────────────────────────
            _buildAppBar(isDark, primary, secondary),

            // ── Steps indicator ──────────────────────────────────────────────
            _buildStepIndicator(isDark, primary),

            // ── Page content ─────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(isDark, primary),
                  _buildStep2(isDark, primary),
                  _buildStep3(isDark, primary, secondary),
                  _buildStep4(isDark, primary),
                ],
              ),
            ),

            // ── Bottom navigation bar ────────────────────────────────────────
            _buildBottomNav(isDark, primary, secondary),
          ],
        ),
      ),
    );
  }

  // ── APPBAR ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(bool isDark, Color primary, Color secondary) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: _prev,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Product Listing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Step ${_currentStep + 1} of $_totalSteps',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Step badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ['Category', 'Specs', 'Images', 'Pricing'][_currentStep],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP INDICATOR ───────────────────────────────────────────────────────

  Widget _buildStepIndicator(bool isDark, Color primary) {
    return Container(
      color: isDark ? const Color(0xFF121722) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (i) {
              final isCompleted = i < _currentStep;
              final isCurrent = i == _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: i < _currentStep ? () => _goToStep(i) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isCurrent ? 32 : 24,
                        height: isCurrent ? 32 : 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted || isCurrent
                              ? primary
                              : (isDark
                                  ? const Color(0xFF2D3748)
                                  : const Color(0xFFE2E8F0)),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white54
                                            : Colors.grey),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (i < _totalSteps - 1)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i < _currentStep
                                ? primary
                                : (isDark
                                    ? const Color(0xFF2D3748)
                                    : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: isDark
                    ? const Color(0xFF2D3748)
                    : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation(primary),
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── STEP 1: CATEGORY & BASICS ─────────────────────────────────────────────

  Widget _buildStep1(bool isDark, Color primary) {
    return _StepScaffold(
      isDark: isDark,
      title: '🏷️ Category & Basic Info',
      subtitle: 'Choose your marketplace pillar and describe your product.',
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_externalPosId == null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Import from POS / Connection Center'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary.withValues(alpha: 0.1),
                    foregroundColor: primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      side: BorderSide(color: primary.withValues(alpha: 0.5)),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => PosConnectionCenterDialog(
                        onProductSelected: _importFromPos,
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Imported from $_posProvider',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _externalPosId = null;
                        _posProvider = null;
                      }),
                      child: const Text('Unlink', style: TextStyle(color: Colors.red)),
                    )
                  ],
                ),
              ),
            _sectionLabel('Marketplace Pillar *'),
            const SizedBox(height: 10),
            // ── Pillar Row 1 ──
            Row(
              children: [
                _pillarChip(
                  icon: '🍽️',
                  label: 'Crockery',
                  type: MainCategoryType.crockery,
                  defaultCat: 'Dinner Sets',
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(width: 10),
                _pillarChip(
                  icon: '🛒',
                  label: 'Grocery',
                  type: MainCategoryType.grocery,
                  defaultCat: 'Food Staples',
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(width: 10),
                _pillarChip(
                  icon: '🍔',
                  label: 'Fast Food',
                  type: MainCategoryType.fastFood,
                  defaultCat: 'Burgers & Wraps',
                  isDark: isDark,
                  primary: primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Pillar Row 2 ── (Dairy & Bakery)
            Row(
              children: [
                _pillarChip(
                  icon: '🥛',
                  label: 'Dairy & Bakery',
                  type: MainCategoryType.dairyBakery,
                  defaultCat: 'Fresh Dairy',
                  isDark: isDark,
                  primary: primary,
                ),
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 20),
            _PremiumTextField(
              label: 'Product Title *',
              hint: _selectedPillar == MainCategoryType.crockery
                  ? 'e.g. Royal Bone China 24-Pc Dinner Set'
                  : _selectedPillar == MainCategoryType.grocery
                      ? 'e.g. Super Kernel Basmati Rice 5kg'
                      : _selectedPillar == MainCategoryType.dairyBakery
                          ? 'e.g. Farm Fresh Full Cream Milk 1L / Sourdough Loaf'
                          : 'e.g. Al-Baik Crispy Fried Chicken (4 Pcs)',
              controller: _titleController,
              isDark: isDark,
              primary: primary,
              icon: Icons.title_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            _PremiumTextField(
              label: 'Brand Name',
              hint: 'e.g. Imperial Living, Mughal Organics',
              controller: _brandController,
              isDark: isDark,
              primary: primary,
              icon: Icons.branding_watermark_rounded,
            ),
            const SizedBox(height: 14),
            _PremiumTextField(
              label: 'Product Description *',
              hint: 'Describe what makes your product special...',
              controller: _descController,
              isDark: isDark,
              primary: primary,
              icon: Icons.description_rounded,
              maxLines: 4,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Description is required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillarChip({
    required String icon,
    required String label,
    required MainCategoryType type,
    required String defaultCat,
    required bool isDark,
    required Color primary,
  }) {
    final isSelected = _selectedPillar == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedPillar = type;
            _selectedCategoryName = defaultCat;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1E2636) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isSelected ? primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? primary
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 2: TECHNICAL SPECS ──────────────────────────────────────────────

  Widget _buildStep2(bool isDark, Color primary) {
    return _StepScaffold(
      isDark: isDark,
      title: '⚙️ Technical Specifications',
      subtitle: 'Add category-specific details that help customers find you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedPillar == MainCategoryType.crockery) ...[
            _sectionLabel('Material'),
            const SizedBox(height: 8),
            _PremiumDropdown<String>(
              value: _crockeryMaterial,
              isDark: isDark,
              primary: primary,
              items: const [
                'Bone China',
                'Porcelain',
                'Ceramic Stoneware',
                'Lead-Free Glass',
                'Melamine',
                'Stainless Steel'
              ],
              onChanged: (v) => setState(() => _crockeryMaterial = v!),
              icon: Icons.local_dining_rounded,
            ),
            const SizedBox(height: 16),
            _sectionLabel('Pieces Count'),
            const SizedBox(height: 8),
            Row(
              children: [
                _CounterButton(
                  value: _piecesCount,
                  min: 1,
                  max: 200,
                  isDark: isDark,
                  primary: primary,
                  label: 'pcs',
                  onChanged: (v) => setState(() => _piecesCount = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PremiumSwitch(
              label: 'Microwave Safe',
              icon: Icons.microwave_rounded,
              value: _isMicrowaveSafe,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isMicrowaveSafe = v),
            ),
            _PremiumSwitch(
              label: 'Dishwasher Safe',
              icon: Icons.clean_hands_rounded,
              value: _isDishwasherSafe,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isDishwasherSafe = v),
            ),
          ] else if (_selectedPillar == MainCategoryType.grocery) ...[
            _PremiumTextField(
              label: 'Package Net Weight / Volume',
              hint: 'e.g. 5 kg, 1 Litre, 500g',
              controller: _groceryWeightController,
              isDark: isDark,
              primary: primary,
              icon: Icons.scale_rounded,
            ),
            const SizedBox(height: 16),
            _PremiumSwitch(
              label: '100% Halal Certified',
              icon: Icons.verified_rounded,
              value: _isHalalCertified,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isHalalCertified = v),
            ),
            _PremiumSwitch(
              label: 'Organic / Non-GMO',
              icon: Icons.eco_rounded,
              value: _isOrganic,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isOrganic = v),
            ),
          ] else if (_selectedPillar == MainCategoryType.dairyBakery) ...[
            // ── Sub-category toggle ──────────────────────────────────────
            _sectionLabel('Category'),
            const SizedBox(height: 8),
            Row(
              children: ['Dairy Products', 'Bakery Items'].map((cat) {
                final isSel = _dairySubCategory == cat;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _dairySubCategory = cat;
                        _selectedCategoryName = cat;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                          right: cat == 'Dairy Products' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark
                                ? const Color(0xFF1E2636)
                                : const Color(0xFFF1F5F9)),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: isSel
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            cat == 'Dairy Products' ? '🥛' : '🥖',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSel
                                  ? const Color(0xFF10B981)
                                  : (isDark
                                      ? Colors.white70
                                      : Colors.black54),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // ── Package size & unit ─────────────────────────────────────
            _sectionLabel('Package Size'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _PremiumTextField(
                    label: 'Quantity',
                    hint: '500',
                    controller: _dairyPackageSizeController,
                    isDark: isDark,
                    primary: primary,
                    icon: Icons.scale_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PremiumDropdown<String>(
                    value: _dairyUnit,
                    isDark: isDark,
                    primary: primary,
                    items: const ['g', 'kg', 'ml', 'L', 'pcs', 'dozen'],
                    onChanged: (v) => setState(() => _dairyUnit = v!),
                    icon: Icons.straighten_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Storage temperature ─────────────────────────────────────
            _sectionLabel('Storage Requirement'),
            const SizedBox(height: 8),
            _PremiumDropdown<String>(
              value: _storageTemp,
              isDark: isDark,
              primary: primary,
              items: const [
                '2–8 °C (Refrigerated)',
                '-18 °C (Frozen)',
                'Room Temperature',
                '10–15 °C (Cool & Dry)',
              ],
              onChanged: (v) => setState(() => _storageTemp = v!),
              icon: Icons.thermostat_rounded,
            ),

            const SizedBox(height: 14),

            // ── Expiry / shelf life ─────────────────────────────────────
            _sectionLabel('Shelf Life: $_expiryDays days'),
            Slider(
              min: 1,
              max: 365,
              divisions: 36,
              value: _expiryDays.toDouble(),
              activeColor: const Color(0xFF10B981),
              label: '$_expiryDays days',
              onChanged: (v) => setState(() => _expiryDays = v.toInt()),
            ),

            const SizedBox(height: 6),

            // ── Dairy-specific fields ───────────────────────────────────
            if (_dairySubCategory == 'Dairy Products') ...[
              _PremiumTextField(
                label: 'Fat % (optional)',
                hint: 'e.g. 3.5',
                controller: _fatPercentController,
                isDark: isDark,
                primary: primary,
                icon: Icons.water_drop_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
            ],

            // ── Bakery sub-type ─────────────────────────────────────────
            if (_dairySubCategory == 'Bakery Items') ...[
              _sectionLabel('Bakery Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Bread & Loaves',
                  'Cakes & Pastries',
                  'Biscuits & Cookies',
                  'Muffins & Croissants',
                  'Rusks & Crackers',
                  'Pakistani Mithai',
                ].map((t) {
                  final isSel = _bakeryType == t;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _bakeryType = t);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark
                                ? const Color(0xFF1E2636)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _PremiumTextField(
                label: 'Key Ingredients',
                hint: 'e.g. Wheat flour, butter, eggs, sugar',
                controller: _ingredientsController,
                isDark: isDark,
                primary: primary,
                icon: Icons.blender_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _PremiumTextField(
                label: 'Allergen Info',
                hint: 'e.g. Contains gluten, dairy, nuts',
                controller: _allergensController,
                isDark: isDark,
                primary: primary,
                icon: Icons.warning_amber_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 14),
            ],

            // ── Dietary flags ────────────────────────────────────────────
            _sectionLabel('Dietary & Quality Tags'),
            const SizedBox(height: 4),
            _PremiumSwitch(
              label: 'Halal Certified',
              icon: Icons.verified_rounded,
              value: _isDairyHalal,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isDairyHalal = v),
            ),
            _PremiumSwitch(
              label: 'Organic / Natural',
              icon: Icons.eco_rounded,
              value: _isDairyOrganic,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isDairyOrganic = v),
            ),
            _PremiumSwitch(
              label: 'Lactose Free',
              icon: Icons.no_drinks_rounded,
              value: _isLactoseFree,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isLactoseFree = v),
            ),
            _PremiumSwitch(
              label: 'Gluten Free',
              icon: Icons.grain_rounded,
              value: _isGlutenFree,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isGlutenFree = v),
            ),
            _PremiumSwitch(
              label: 'Vegan',
              icon: Icons.spa_rounded,
              value: _isVegan,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isVegan = v),
            ),

          ] else ...[
            _PremiumTextField(
              label: 'Restaurant / Bakery Name',
              hint: 'e.g. Al-Baik, The Bread Factory',
              controller: _restaurantNameController,
              isDark: isDark,
              primary: primary,
              icon: Icons.restaurant_rounded,
            ),
            const SizedBox(height: 16),
            _sectionLabel('Outlet Type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['restaurant', 'bakery', 'cafe', 'dhaba'].map((t) {
                final isSelected = _restaurantType == t;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _restaurantType = t);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withValues(alpha: 0.15)
                          : (isDark
                              ? const Color(0xFF1E2636)
                              : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? primary : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      t[0].toUpperCase() + t.substring(1),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? primary
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Cuisine Type'),
            const SizedBox(height: 8),
            _PremiumDropdown<String>(
              value: _cuisineType,
              isDark: isDark,
              primary: primary,
              items: const [
                'Pakistani',
                'Fast Food',
                'Continental',
                'Chinese',
                'Italian',
                'French Patisserie',
                'Artisan Bakery',
                'Pakistani Sweets',
                'Pakistani BBQ',
              ],
              onChanged: (v) => setState(() => _cuisineType = v!),
              icon: Icons.restaurant_menu_rounded,
            ),
            const SizedBox(height: 16),
            _sectionLabel(
                'Prep Time: $_preparationTimeMinutes min'),
            Slider(
              min: 0,
              max: 90,
              divisions: 18,
              value: _preparationTimeMinutes.toDouble(),
              activeColor: primary,
              label: '${_preparationTimeMinutes}m',
              onChanged: (v) =>
                  setState(() => _preparationTimeMinutes = v.toInt()),
            ),
            _PremiumSwitch(
              label: 'Vegetarian / Veg',
              icon: Icons.grass_rounded,
              value: _isVegetarian,
              isDark: isDark,
              primary: primary,
              onChanged: (v) => setState(() => _isVegetarian = v),
            ),
          ],
        ],
      ),
    );
  }

  // ── STEP 3: IMAGES ───────────────────────────────────────────────────────

  Widget _buildStep3(bool isDark, Color primary, Color secondary) {
    return _StepScaffold(
      isDark: isDark,
      title: '📸 Product Images',
      subtitle:
          'Upload up to 5 clear photos. First image is the cover.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload buttons
          Row(
            children: [
              Expanded(
                child: _ImageSourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  isDark: isDark,
                  primary: primary,
                  onTap: _selectedImages.length < 5 ? _pickImage : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImageSourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  isDark: isDark,
                  primary: secondary,
                  onTap: _selectedImages.length < 5
                      ? _pickImageFromCamera
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_selectedImages.isEmpty && _importedImages.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A2035)
                    : const Color(0xFFF1F5F9),
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D3748)
                      : const Color(0xFFCBD5E0),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No images selected',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'A placeholder will be used if no image is uploaded',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_selectedImages.isEmpty && _importedImages.isNotEmpty) ...[
            Text(
              '${_importedImages.length}/5 images imported from POS',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _importedImages.length,
              itemBuilder: (context, index) {
                final url = _importedImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall),
                      child: Image.network(
                        url,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'COVER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ] else ...[
            Text(
              '${_selectedImages.length}/5 images selected',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                final file = _selectedImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall),
                      child: Image.file(
                        file,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'COVER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedImages.removeAt(index)),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 16),
          // Upload progress (shown while submitting)
          if (_isUploadingImages) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Encoding images... ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _uploadProgress,
              borderRadius: BorderRadius.circular(4),
            ),
          ],

          const SizedBox(height: 16),
          // Tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSmall),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Products with clear, well-lit photos on a white background get 3× more sales.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 4: PRICING & STOCK ──────────────────────────────────────────────

  Widget _buildStep4(bool isDark, Color primary) {
    // Live discount calculation
    final base = double.tryParse(_basePriceController.text) ?? 0;
    final sale = double.tryParse(_salePriceController.text) ?? 0;
    final discountPct =
        (base > 0 && sale > 0 && base > sale) ? ((base - sale) / base * 100).toInt() : 0;
    final savings = base > sale ? base - sale : 0.0;

    return _StepScaffold(
      isDark: isDark,
      title: '💰 Pricing & Inventory',
      subtitle: 'Set your price and initial stock. You can update anytime.',
      child: Form(
        key: _step4Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PremiumTextField(
              label: 'Original / MRP Price (Rs.)',
              hint: 'e.g. 18500',
              controller: _basePriceController,
              isDark: isDark,
              primary: primary,
              icon: Icons.price_change_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Price is required';
                if (double.tryParse(v) == null) return 'Invalid price';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _PremiumTextField(
              label: 'Discounted Selling Price (Rs.)',
              hint: 'e.g. 14999 (leave blank = same as MRP)',
              controller: _salePriceController,
              isDark: isDark,
              primary: primary,
              icon: Icons.sell_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              onChanged: (_) => setState(() {}),
            ),

            // Live discount preview
            if (discountPct > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade500.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                  border: Border.all(
                      color: Colors.green.shade500.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_rounded,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$discountPct% discount  •  Customer saves Rs. ${savings.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            _PremiumTextField(
              label: 'Initial Stock Quantity',
              hint: 'e.g. 40',
              controller: _stockController,
              isDark: isDark,
              primary: primary,
              icon: Icons.inventory_2_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Stock is required';
                if (int.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),

            const SizedBox(height: 20),
            // Summary card
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) => _buildSummaryCard(isDark, primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, Color primary) {
    final base = double.tryParse(_basePriceController.text) ?? 0;
    final sale = double.tryParse(_salePriceController.text) ?? base;
    final stock = int.tryParse(_stockController.text) ?? 0;
    final grossInventoryValue = sale * stock;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2035) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2D3748)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Listing Preview',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow(isDark, '📦 Product',
              _titleController.text.trim().isNotEmpty
                  ? _titleController.text.trim()
                  : '—'),
          _summaryRow(isDark, '🏷️ Category',
              '${_selectedPillar.title}  ›  $_selectedCategoryName'),
          _summaryRow(isDark, '💰 MRP Price',
              base > 0 ? 'Rs. ${base.toStringAsFixed(0)}' : '—'),
          _summaryRow(isDark, '🏷️ Sale Price',
              sale > 0 ? 'Rs. ${sale.toStringAsFixed(0)}' : '—'),
          _summaryRow(isDark, '📷 Images', '${_selectedImages.length} uploaded'),
          _summaryRow(isDark, '📦 Stock', '$stock units'),
          if (grossInventoryValue > 0)
            _summaryRow(isDark, '💼 Gross Value',
                'Rs. ${grossInventoryValue.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _summaryRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM NAV ───────────────────────────────────────────────────────────

  Widget _buildBottomNav(bool isDark, Color primary, Color secondary) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _prev,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50,
              decoration: BoxDecoration(
                gradient: _isSubmitting
                    ? null
                    : LinearGradient(
                        colors: [primary, secondary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
                color: _isSubmitting ? Colors.grey.shade400 : null,
                boxShadow: _isSubmitting
                    ? null
                    : [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  onTap: _isSubmitting
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          if (isLastStep) {
                            _submitProduct();
                          } else {
                            _next();
                          }
                        },
                  child: Center(
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastStep ? 'Publish Listing' : 'Next Step',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLastStep
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
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

  // ── HELPERS ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
}

// ── REUSABLE SUBWIDGETS ────────────────────────────────────────────────────

class _StepScaffold extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepScaffold({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 20),
          child,
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isDark;
  final Color primary;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _PremiumTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.isDark,
    required this.primary,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, size: 18, color: primary),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1A2035)
                : const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2D3748)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumDropdown<T> extends StatelessWidget {
  final T value;
  final bool isDark;
  final Color primary;
  final List<T> items;
  final void Function(T?) onChanged;
  final IconData icon;

  const _PremiumDropdown({
    required this.value,
    required this.isDark,
    required this.primary,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: primary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor:
            isDark ? const Color(0xFF1A2035) : const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF2D3748)
                : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      dropdownColor:
          isDark ? const Color(0xFF1A2035) : Colors.white,
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _PremiumSwitch extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final bool isDark;
  final Color primary;
  final void Function(bool) onChanged;

  const _PremiumSwitch({
    required this.label,
    required this.icon,
    required this.value,
    required this.isDark,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? primary.withValues(alpha: 0.08)
              : (isDark
                  ? const Color(0xFF1A2035)
                  : const Color(0xFFF8FAFC)),
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusSmall),
          border: Border.all(
            color: value
                ? primary.withValues(alpha: 0.3)
                : (isDark
                    ? const Color(0xFF2D3748)
                    : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color:
                    value ? primary : (isDark ? Colors.white38 : Colors.black26)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      value ? FontWeight.w600 : FontWeight.normal,
                  color: value
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white60 : Colors.black45),
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              activeThumbColor: primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final bool isDark;
  final Color primary;
  final String label;
  final void Function(int) onChanged;

  const _CounterButton({
    required this.value,
    required this.min,
    required this.max,
    required this.isDark,
    required this.primary,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2035) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2D3748)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded),
            onPressed:
                value > min ? () => onChanged(value - 1) : null,
            color: primary,
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$value $label',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed:
                value < max ? () => onChanged(value + 1) : null,
            color: primary,
          ),
        ],
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color primary;
  final VoidCallback? onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDisabled
              ? (isDark
                  ? const Color(0xFF1A2035)
                  : const Color(0xFFF1F5F9))
              : primary.withValues(alpha: 0.1),
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isDisabled
                ? (isDark
                    ? const Color(0xFF2D3748)
                    : const Color(0xFFE2E8F0))
                : primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isDisabled
                  ? (isDark ? Colors.white24 : Colors.black12)
                  : primary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDisabled
                    ? (isDark ? Colors.white24 : Colors.black26)
                    : primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
