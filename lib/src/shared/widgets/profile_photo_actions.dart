import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../backend/db/repositories/users_repo.dart';
import '../../services/media_service.dart';
import '../styling/app_typography.dart';
import 'top_snack_bar.dart';

Future<String?> changeProfilePhoto(
  BuildContext context, {
  required UsersRepo usersRepo,
  Future<String?> Function(ImageSource)? uploadPhoto,
  VoidCallback? onUploadStarted,
}) async {
  final source = MediaService.usesDesktopImageUpload
      ? ImageSource.gallery
      : await showModalBottomSheet<ImageSource>(
          context: context,
          useRootNavigator: true,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change profile photo',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Choose from gallery'),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: const Text('Take photo'),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ],
              ),
            ),
          ),
        );
  if (source == null || !context.mounted) return null;
  final url =
      await (uploadPhoto?.call(source) ??
          MediaService().pickAndUploadImage(source, folder: 'profile-images'));
  if (url == null || !context.mounted) return null;
  final ok = await usersRepo.updateCurrentUserProfile(avatarUrl: url);
  if (!context.mounted) return null;
  showTopSnackBar(
    context,
    ok ? 'Profile photo updated' : 'Could not update profile photo',
    isError: !ok,
  );
  return ok ? url : null;
}
