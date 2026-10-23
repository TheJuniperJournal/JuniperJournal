import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/supabase_database.dart';

/// Service for handling file uploads to Supabase Storage
class StorageService {
  final _client = SupabaseDatabase.instance.client;

  /// The name of the storage bucket for learning module images
  // static const String bucketName = 'learning-module-images';

  /// Uploads an image file to Supabase Storage and returns the public URL
  ///
  /// [imageFile] - The image file picked by the user
  /// [folder] - Optional folder path within the bucket (e.g., 'concept-exploration')
  ///
  /// Returns the public URL of the uploaded image, or null if upload fails
  Future<String?> uploadImage(
    XFile imageFile, {
    String bucketName = "",
    String folder = '',
  }) async {
    try {
      final uploaded = await uploadImageFile(
        imageFile,
        bucketName: bucketName,
        folder: folder,
      );
      return uploaded.publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<UploadedStorageFile> uploadImageFile(
    XFile imageFile, {
    required String bucketName,
    String folder = '',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = imageFile.name.contains('.')
        ? imageFile.name.split('.').last.toLowerCase()
        : 'jpg';
    final safeName = imageFile.name
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-.]'), '');
    final fallbackName = safeName.isEmpty ? 'image.$extension' : safeName;
    final bytes = await imageFile.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    final fileName = '${timestamp}_${digest}_$fallbackName';
    final filePath = folder.isEmpty ? fileName : '$folder/$fileName';

    await _client.storage
        .from(bucketName)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: false,
          ),
        );

    final publicUrl = _client.storage.from(bucketName).getPublicUrl(filePath);
    return UploadedStorageFile(
      path: filePath,
      signedUrl: '',
      publicUrl: publicUrl,
      fileName: imageFile.name,
    );
  }

  Future<UploadedStorageFile> uploadVideo(
    XFile videoFile, {
    required String bucketName,
    required String folder,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = videoFile.name.contains('.')
        ? videoFile.name.split('.').last.toLowerCase()
        : 'mp4';
    final safeName = videoFile.name
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-.]'), '');
    final bytes = await videoFile.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    final fileName = '${timestamp}_${digest}_$safeName';
    final filePath = folder.isEmpty ? fileName : '$folder/$fileName';

    await _client.storage
        .from(bucketName)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _getVideoContentType(extension),
            upsert: false,
          ),
        );

    final signedUrl = await _client.storage
        .from(bucketName)
        .createSignedUrl(filePath, 3600);
    return UploadedStorageFile(path: filePath, signedUrl: signedUrl);
  }

  Future<UploadedStorageFile> uploadFile(
    XFile file, {
    required String bucketName,
    required String folder,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'bin';
    final safeName = file.name
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-.]'), '');
    final fallbackName = safeName.isEmpty ? 'attachment.$extension' : safeName;
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    final fileName = '${timestamp}_${digest}_$fallbackName';
    final filePath = folder.isEmpty ? fileName : '$folder/$fileName';

    await _client.storage
        .from(bucketName)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _getFileContentType(extension),
            upsert: false,
          ),
        );

    final publicUrl = _client.storage.from(bucketName).getPublicUrl(filePath);
    return UploadedStorageFile(
      path: filePath,
      signedUrl: '',
      publicUrl: publicUrl,
      fileName: file.name,
    );
  }

  Future<String> createSignedUrl(
    String path, {
    required String bucketName,
    int expiresIn = 3600,
  }) {
    return _client.storage.from(bucketName).createSignedUrl(path, expiresIn);
  }

  /// Deletes an image from Supabase Storage
  ///
  /// [imageUrl] - The public URL of the image to delete
  ///
  /// Returns true if deletion was successful, false otherwise
  Future<bool> deleteImage(String imageUrl, {String bucketName = ""}) async {
    try {
      // Extract the file path from the public URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the bucket name and file path in the URL
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1) {
        debugPrint('Invalid image URL - bucket not found');
        return false;
      }

      // Get the file path after the bucket name
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      // Delete from Supabase Storage
      await _client.storage.from(bucketName).remove([filePath]);

      debugPrint('Image deleted successfully: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Gets the MIME type for a file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  String _getVideoContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }

  String _getFileContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
        return _getContentType(extension);
      default:
        return 'application/octet-stream';
    }
  }
}

class UploadedStorageFile {
  final String path;
  final String signedUrl;
  final String publicUrl;
  final String fileName;

  const UploadedStorageFile({
    required this.path,
    required this.signedUrl,
    this.publicUrl = '',
    this.fileName = '',
  });
}
