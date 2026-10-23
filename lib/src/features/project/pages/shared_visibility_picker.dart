import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../backend/db/models/community.dart';
import '../../../backend/db/repositories/communities_repo.dart';

class SharedProjectAudience {
  const SharedProjectAudience({
    this.friends = false,
    this.communityIds = const {},
  });
  final bool friends;
  final Set<String> communityIds;
}

class SharedVisibilityPicker extends StatefulWidget {
  const SharedVisibilityPicker({
    super.key,
    required this.projectType,
    required this.linkedCommunities,
    required this.initial,
    this.communities,
  });
  final String projectType;
  final List<Map<String, dynamic>> linkedCommunities;
  final SharedProjectAudience initial;
  final List<Community>? communities;
  @override
  State<SharedVisibilityPicker> createState() => _SharedVisibilityPickerState();
}

class _SharedVisibilityPickerState extends State<SharedVisibilityPicker> {
  late bool _friends = widget.initial.friends;
  late final Set<String> _selected = {...widget.initial.communityIds};
  List<Community>? _communities;
  bool _failed = false;
  Set<String> get _linkedIds =>
      widget.linkedCommunities.map((c) => c['id'].toString()).toSet();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final communities =
          widget.communities ?? await CommunitiesRepo().getUserCommunities();
      if (mounted) setState(() => _communities = communities);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _apply() => Navigator.pop(
    context,
    SharedProjectAudience(
      friends: _friends,
      communityIds: _selected.difference(_linkedIds),
    ),
  );
  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppTypography.headingFamily,
        color: AppColors.textPrimary,
        fontSize: AppTypography.sectionTitleSize,
      ),
    ),
  );
  Widget _community({
    required String id,
    required String name,
    String? image,
    String? description,
    bool locked = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage: image?.isNotEmpty == true
              ? NetworkImage(image!)
              : null,
          child: image?.isNotEmpty == true
              ? null
              : const Icon(Icons.groups_outlined),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Color(0xFF5DB075),
                  fontSize: AppTypography.bodySize,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    description!,
                    style: const TextStyle(
                      color: Color(0xFF498B5C),
                      fontSize: AppTypography.helperSize,
                      height: 1.7,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!locked || widget.projectType != 'collaborative')
          SizedBox(
            width: 40,
            height: 24,
            child: Checkbox(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: locked || _selected.contains(id),
              activeColor: const Color(0xFF5DB075),
              side: WidgetStateBorderSide.resolveWith(
                (_) => const BorderSide(color: Color(0xFF5DB075), width: 1.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              fillColor: WidgetStateProperty.all(Colors.white),
              checkColor: const Color(0xFF5DB075),
              onChanged: locked
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    }),
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final collaborative = widget.projectType == 'collaborative';
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Apply audience',
                    onPressed: _apply,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF5DB075),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Shared Visibility',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTypography.pageTitleSize,
                        color: Color(0xFF5DB075),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const Divider(color: Color(0xFF5DB075)),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (collaborative &&
                          widget.linkedCommunities.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 20, bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Collaborating Communities',
                                  style: TextStyle(
                                    color: Color(0xFF5DB075),
                                    fontSize: AppTypography.pageTitleSize,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.lock_outline,
                                color: Color(0xFF5DB075),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'These communities already have visibility to the project.',
                          style: TextStyle(
                            color: Color(0xFF5DB075),
                            fontSize: AppTypography.helperSize,
                          ),
                        ),
                        for (final c in widget.linkedCommunities)
                          _community(
                            id: c['id'].toString(),
                            name: c['name']?.toString() ?? '',
                            image: c['imageUrl']?.toString(),
                            description: c['description']?.toString(),
                            locked: true,
                          ),
                      ],
                      _title('Additional Viewing Audience'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SvgPicture.asset(
                            'assets/project_setup/visibility_shared.svg',
                            width: 44,
                            height: 40,
                          ),
                          const SizedBox(width: 18),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Friends',
                                  style: TextStyle(
                                    fontSize: AppTypography.pageTitleSize,
                                    height: 1.5,
                                    color: Color(0xFF5DB075),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Only people you’re connected with can view this project, allowing you to share your progress, ideas, and impact with a trusted network.',
                                  style: TextStyle(
                                    fontSize: AppTypography.helperSize,
                                    height: 1.7,
                                    color: Color(0xFF498B5C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            height: 24,
                            child: Checkbox(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              value: _friends,
                              activeColor: const Color(0xFF5DB075),
                              side: WidgetStateBorderSide.resolveWith(
                                (_) => const BorderSide(
                                  color: Color(0xFF5DB075),
                                  width: 1.5,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              fillColor: WidgetStateProperty.all(Colors.white),
                              checkColor: const Color(0xFF5DB075),
                              onChanged: (v) =>
                                  setState(() => _friends = v ?? false),
                            ),
                          ),
                        ],
                      ),
                      _title(
                        collaborative
                            ? 'Additional Viewing Communities'
                            : 'Communities',
                      ),
                      if (_communities == null)
                        _failed
                            ? const Text('Unable to load communities.')
                            : const Center(child: CircularProgressIndicator())
                      else ...[
                        if (_communities!
                            .where(
                              (c) =>
                                  !collaborative || !_linkedIds.contains(c.id),
                            )
                            .isEmpty)
                          const Text(
                            'No additional communities available.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        for (final c in _communities!)
                          if (!collaborative || !_linkedIds.contains(c.id))
                            _community(
                              id: c.id,
                              name: c.name,
                              image: c.imageUrl,
                              description: c.subjectFocus,
                              locked: _linkedIds.contains(c.id),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 180,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5DB075),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _apply,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
