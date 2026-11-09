import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress_lite/flutter_image_compress_lite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

/// Handles image picking, compression, and Base64 encoding for SQLite database storage.
class StorageService {
  static final ImagePicker _picker = ImagePicker();

  // ── IMAGE PICKING ─────────────────────────────────────────────────────────

  /// Opens the gallery and returns the selected file, or null if cancelled.
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      debugPrint('StorageService.pickImageFromGallery error: $e');
      return null;
    }
  }

  /// Opens the camera and returns the captured file, or null if cancelled.
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      debugPrint('StorageService.pickImageFromCamera error: $e');
      return null;
    }
  }

  // ── IMAGE COMPRESSION ─────────────────────────────────────────────────────

  /// Compresses an image file to under ~300 KB (quality 75, max 800px).
  static Future<File> compressImage(File file) async {
    try {
      final dir = file.parent;
      final name =
          '${path.basenameWithoutExtension(file.path)}_compressed.jpg';
      final targetPath = '${dir.path}/$name';

      final File result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 60, // Lowered quality to save space for Base64
        minWidth: 500, // Reduced max size for Base64
        minHeight: 500,
        format: CompressFormat.jpeg,
      );

      return result;
    } catch (e) {
      debugPrint('StorageService.compressImage error: $e');
      return file;
    }
  }

  // ── BASE64 ENCODING (Replaces Firebase Storage) ─────────────────────────

  /// Compresses and encodes an image to a Base64 string for direct SQLite database storage.
  ///
  /// [storagePath] is kept for compatibility but not used.
  static Future<String?> uploadImage({
    required File imageFile,
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (onProgress != null) onProgress(0.1);
      final compressed = await compressImage(imageFile);
      
      if (onProgress != null) onProgress(0.5);
      
      final bytes = await compressed.readAsBytes();
      final base64String = base64Encode(bytes);
      
      if (onProgress != null) onProgress(1.0);
      
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      debugPrint('StorageService.uploadImage error: $e');
      return null;
    }
  }

  /// Encodes multiple images to Base64 data URIs.
  ///
  /// Sequential encoding.
  static Future<List<String>> uploadProductImages({
    required List<File> images,
    required String sellerId,
    required String productId,
    void Function(int current, int total)? onProgress,
  }) async {
    final urls = <String>[];
    for (int i = 0; i < images.length; i++) {
      onProgress?.call(i + 1, images.length);
      final url = await uploadImage(
        imageFile: images[i],
        storagePath: 'products/$sellerId/$productId/img_$i.jpg', // Unused now
      );
      if (url != null) urls.add(url);
    }
    return urls;
  }

  /// No-op: Since we use Base64 strings in Firestore, there are no files to delete.
  static Future<void> deleteFile(String storagePath) async {
    // No-op
  }

  /// No-op: Since we use Base64 strings in Firestore, there are no files to delete.
  static Future<void> deleteProductImages(
      String sellerId, String productId) async {
    // No-op
  }
}
