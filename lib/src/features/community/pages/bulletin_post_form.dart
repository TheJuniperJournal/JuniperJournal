import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/optional_field_label.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import '../../../shared/widgets/picked_image_preview.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/models/bulletin_post.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

const _kCategories = [
  'Idea / Brainstorm',
  'Design Feedback',
  'Build & Materials',
  'Impact & Measurement',
  'Question / Help',
  'Collaboration',
  'Project Share',
];

class BulletinPostForm extends StatefulWidget {
  final String communityId;
  final BulletinPost? editPost;

  const BulletinPostForm({super.key, required this.communityId, this.editPost});

  @override
  State<BulletinPostForm> createState() => _BulletinPostFormState();
}

class _BulletinPostFormState extends State<BulletinPostForm> {
  final _repo = CommunitiesRepo();
  final _storage = StorageService();
  final _picker = ImagePicker();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late String _category;
  bool _isPosting = false;
  bool _categoryOpen = false;

  // Images: existing URLs (edit mode) + newly picked files
  List<String> _existingImageUrls = [];
  List<XFile> _newImages = [];

  bool get _isEditing => widget.editPost != null;

  @override
  void initState() {
    super.initState();
    final post = widget.editPost;
    _titleCtrl = TextEditingController(text: post?.title ?? '');
    _bodyCtrl = TextEditingController(text: post?.body ?? '');
    _category = post?.category ?? _kCategories.first;
    _existingImageUrls = List.from(post?.imageUrls ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_existingImageUrls.length + _newImages.length >= 4) {
      showTopSnackBar(context, 'Maximum 4 photos per post');
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _newImages.add(file));
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      showTopSnackBar(context, 'Please fill in all fields');
      return;
    }
    setState(() => _isPosting = true);

    // Upload any new images
    final uploadedUrls = <String>[];
    for (final img in _newImages) {
      final url = await _storage.uploadImage(
        img,
        bucketName: 'images',
        folder: 'bulletin',
      );
      if (url != null) uploadedUrls.add(url);
    }

    final allImageUrls = [..._existingImageUrls, ...uploadedUrls];

    bool ok;
    if (_isEditing) {
      ok = await _repo.updateBulletinPost(
        id: widget.editPost!.id,
        title: title,
        category: _category,
        body: body,
        imageUrls: allImageUrls,
      );
    } else {
      final post = await _repo.createBulletinPost(
        communityId: widget.communityId,
        title: title,
        category: _category,
        body: body,
        imageUrls: allImageUrls,
      );
      ok = post != null;
    }

    if (!mounted) return;
    setState(() => _isPosting = false);
    if (!ok) {
      showTopSnackBar(context, 'Failed to save post. Please try again.');
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.primary, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _isEditing ? 'Edit Post' : 'Forum Post',
          style: AppTypography.pageTitle,
        ),
      ),
      body: PageScrollWithFooter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Post Title ────────────────────────────────────────────────
              const Text(
                'Post Title',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  constraints: const BoxConstraints(minHeight: 64),
                  hintText: '',
                  hintStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.hintText,
                    fontSize: AppTypography.bodySize,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Post Category ─────────────────────────────────────────────
              const Text(
                'Post Category',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _CategoryPill(
                value: _category,
                isOpen: _categoryOpen,
                onTap: () => setState(() => _categoryOpen = !_categoryOpen),
              ),
              if (_categoryOpen) ...[
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: _kCategories
                        .map(
                          (cat) => InkWell(
                            onTap: () => setState(() {
                              _category = cat;
                              _categoryOpen = false;
                            }),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: AppTypography.bodySize,
                                  color: cat == _category
                                      ? AppColors.primary
                                      : AppColors.primary.withValues(
                                          alpha: 0.75,
                                        ),
                                  fontWeight: cat == _category
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Body ──────────────────────────────────────────────────────
              const Text(
                'Your Question or Idea',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyCtrl,
                minLines: 5,
                maxLines: null,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: '',
                  hintStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.hintText,
                    fontSize: AppTypography.bodySize,
                  ),
                  alignLabelWithHint: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Photos ────────────────────────────────────────────────────
              const OptionalFieldLabel(
                'Photos (Optional)',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildPhotoGrid(),
              const SizedBox(height: AppMetrics.sectionGap),

              // ── Post button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.buttonSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    final totalCount = _existingImageUrls.length + _newImages.length;
    final canAdd = totalCount < 4;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // Existing images
        for (final url in _existingImageUrls)
          _PhotoThumbnail(
            imageProvider: NetworkImage(url),
            onRemove: () => setState(() => _existingImageUrls.remove(url)),
          ),
        // New images (picked from device)
        for (final xfile in _newImages)
          _PhotoThumbnail(
            preview: PickedImagePreview(file: xfile),
            onRemove: () => setState(() => _newImages.remove(xfile)),
          ),
        // Add button
        if (canAdd)
          AppTapTarget(
            onTap: _pickImage,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
      ],
    );
  }
}

// ── _PhotoThumbnail ───────────────────────────────────────────────────────────

class _PhotoThumbnail extends StatelessWidget {
  final ImageProvider? imageProvider;
  final Widget? preview;
  final VoidCallback onRemove;

  const _PhotoThumbnail({
    this.imageProvider,
    this.preview,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 80,
            height: 80,
            child: preview ?? Image(image: imageProvider!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: AppTapTarget(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── _CategoryPill ─────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.value,
    required this.isOpen,
    required this.onTap,
  });

  final String value;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
            Icon(
              isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
