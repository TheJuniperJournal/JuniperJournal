import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/media_service.dart';

Future<ImageSource?> showProjectPhotoDialog(
  BuildContext context, {
  VoidCallback? onRemove,
}) => showDialog<ImageSource>(
  context: context,
  builder: (dialogContext) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(24),
    child: SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Project photo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Upload photo'),
              onPressed: () =>
                  Navigator.pop(dialogContext, ImageSource.gallery),
            ),
            if (!MediaService.usesDesktopImageUpload)
              TextButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
                onPressed: () =>
                    Navigator.pop(dialogContext, ImageSource.camera),
              ),
            if (onRemove != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onRemove();
                },
                child: const Text('Remove photo'),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  ),
);
