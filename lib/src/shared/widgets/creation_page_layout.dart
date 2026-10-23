import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';
import 'journal_section_header.dart';

class CreationPageFrame extends StatelessWidget {
  const CreationPageFrame({
    super.key,
    required this.child,
    this.desktopMaxWidth = JournalPageLayout.desktopContentWidth,
  });
  final double desktopMaxWidth;
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= 1000
              ? desktopMaxWidth
              : JournalPageLayout.contentWidth,
        ),
        child: child,
      ),
    ),
  );
}

class CreationPageHeader extends StatelessWidget {
  const CreationPageHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.closeLabel = 'Close',
  });
  final String title;
  final VoidCallback onClose;
  final String closeLabel;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: JournalPageLayout.horizontalInset,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.pageTitle,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: closeLabel,
              onPressed: onClose,
              padding: EdgeInsets.zero,
              alignment: Alignment.center,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: const Icon(Icons.close, size: 26, color: AppColors.primary),
            ),
          ),
        ],
      ),
    ),
  );
}

class CreationImagePicker extends StatelessWidget {
  const CreationImagePicker({
    super.key,
    required this.imageUrl,
    required this.onTap,
    required this.label,
    this.isUploading = false,
    this.iconOnlyTap = false,
    this.imageBytes,
  });
  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback onTap;
  final String label;
  final bool isUploading, iconOnlyTap;

  Widget _tapTarget(Widget child) => Semantics(
    button: true,
    label: label,
    enabled: !isUploading,
    onTap: isUploading ? null : onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: isUploading ? null : onTap,
      customBorder: iconOnlyTap ? const CircleBorder() : null,
      child: child,
    ),
  );

  Widget _image() => Material(
    color: AppColors.primary,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: SizedBox.square(
      dimension: 48,
      child: imageBytes != null
          ? Image.memory(imageBytes!, fit: BoxFit.cover, gaplessPlayback: true)
          : imageUrl?.isNotEmpty == true
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.camera_alt, color: Colors.white, size: 24),
            )
          : const Icon(Icons.camera_alt, color: Colors.white, size: 24),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final contents = Column(
      children: [
        iconOnlyTap ? _tapTarget(_image()) : _image(),
        const SizedBox(height: 10),
        if (isUploading)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Text('Tap Image to Update', style: AppTypography.helper),
      ],
    );
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: iconOnlyTap ? contents : _tapTarget(contents),
      ),
    );
  }
}

class CreationOptionCard extends StatelessWidget {
  const CreationOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.asset,
    this.icon,
    this.showError = false,
  });
  final String title, description;
  final String? asset;
  final Widget? icon;
  final bool selected;
  final bool showError;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.primary.withValues(alpha: .06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: showError ? AppColors.error : AppColors.primary,
          width: showError || selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: icon ?? SvgPicture.asset(asset!, fit: BoxFit.contain),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.fieldLabel),
                      const SizedBox(height: 6),
                      Text(description, style: AppTypography.helper),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  child: selected
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
