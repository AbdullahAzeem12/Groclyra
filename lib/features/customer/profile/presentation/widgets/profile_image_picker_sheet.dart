import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress_lite/flutter_image_compress_lite.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';

class ProfileImagePickerSheet extends StatelessWidget {
  final Function(String base64Image) onImageCropped;
  final VoidCallback onRemoveImage;

  const ProfileImagePickerSheet({
    super.key,
    required this.onImageCropped,
    required this.onRemoveImage,
  });

  static void show(
    BuildContext context, {
    required Function(String base64Image) onImageCropped,
    required VoidCallback onRemoveImage,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProfileImagePickerSheet(
        onImageCropped: (base64) {
          onImageCropped(base64);
          Navigator.pop(context);
        },
        onRemoveImage: () {
          onRemoveImage();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) return;

      // Ensure widget is still mounted
      if (!context.mounted) return;

      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      // Compress and convert to Base64
      final bytes = await FlutterImageCompress.compressWithFile(
        croppedFile.path,
        minWidth: 400,
        minHeight: 400,
        quality: 70, // Aggressive compression for firestore
        format: CompressFormat.jpeg,
      );

      final base64String = base64Encode(bytes);
      onImageCropped(base64String);
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (context.mounted) {
        AppToggleMessage.error(
          context,
          'Failed to pick or process image. Please try again.',
          title: 'Image Error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 16),
              child: Text(
                'Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_outlined, color: Theme.of(context).primaryColor),
              ),
              title: const Text('Take a photo', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () => _pickImage(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library_outlined, color: Theme.of(context).primaryColor),
              ),
              title: const Text('Choose from gallery', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () => _pickImage(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text('Remove current photo', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
              onTap: onRemoveImage,
            ),
          ],
        ),
      ),
    );
  }
}
