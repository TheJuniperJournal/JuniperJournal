import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/features/community/pages/challenge_setup_form.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

class ChallengeTypePicker extends StatefulWidget {
  final String communityId;

  const ChallengeTypePicker({super.key, required this.communityId});

  @override
  State<ChallengeTypePicker> createState() => _ChallengeTypePickerState();
}

class _ChallengeTypePickerState extends State<ChallengeTypePicker> {
  String? _selected;

  static const _types = [
    _ChallengeType(
      value: 'pattern_change',
      label: 'Pattern Change',
      description:
          'Focus on a specific sustainability pattern such as reduction, substitution, regeneration, or behavior change.',
      icon: Icons.fingerprint_outlined,
    ),
    _ChallengeType(
      value: 'community_impact',
      label: 'Community Impact',
      description:
          'Engage with others to create a community impact project or a workshop focused on sustainability.',
      icon: Icons.people_outline,
    ),
    _ChallengeType(
      value: 'build_and_create',
      label: 'Build & Create',
      description:
          'Design and build a physical or digital solution that addresses a sustainability problem.',
      icon: Icons.precision_manufacturing_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            size: 28,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Design Challenge Types',
          style: AppTypography.pageTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 22,
              color: AppColors.textSecondary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a Design Challenge Type.',
              style: TextStyle(
                fontFamily: AppTypography.headingFamily,
                fontSize: AppTypography.sectionTitleSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),
            Expanded(
              child: PageScrollWithFooter(
                child: ListView.separated(
                  itemCount: _types.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppMetrics.labelGap),
                  itemBuilder: (_, i) {
                    final t = _types[i];
                    final isSelected = _selected == t.value;
                    return AppTapTarget(
                      onTap: () => setState(() => _selected = t.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6B4EFF)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                t.icon,
                                size: 22,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.label,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.bodyFamily,
                                      fontSize: AppTypography.bodySize,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.description,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.bodyFamily,
                                      fontSize: AppTypography.bodySize,
                                      color: AppColors.primaryDark,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => pushAppRoute(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChallengeSetupForm(
                            communityId: widget.communityId,
                            type: _selected!,
                          ),
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primaryTint,
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
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeType {
  final String value;
  final String label;
  final String description;
  final IconData icon;

  const _ChallengeType({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
}
