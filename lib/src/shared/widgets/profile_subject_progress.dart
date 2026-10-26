import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../styling/app_typography.dart';

class ProfileSubjectProgress extends StatelessWidget {
  const ProfileSubjectProgress({
    super.key,
    required this.total,
    required this.points,
    this.onSubjectSelected,
  });
  final ValueChanged<String>? onSubjectSelected;
  final double total;
  final Map<String, double> points;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final subject in const [
        ('Environment & Sustainability', 'environment', Color(0xFF12B85A)),
        ('Engineering & Design', 'engineering', Color(0xFF009ECB)),
        ('Energy & Systems', 'energy', Color(0xFFE0B900)),
        ('Community & Built Environment', 'community', Color(0xFFE85870)),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onSubjectSelected == null
                  ? null
                  : () => onSubjectSelected!(subject.$1),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8E3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: subject.$3,
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        'assets/project_setup/subject_${subject.$2}.svg',
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject.$1, style: AppTypography.fieldLabel),
                          const SizedBox(height: 6),
                          Text(
                            '${(points[subject.$1] ?? 0).round()} EcoPoints',
                            style: AppTypography.helper,
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: total == 0
                                ? 0
                                : ((points[subject.$1] ?? 0) / total).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            color: subject.$3,
                            backgroundColor: const Color(0xFFF2F5F3),
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ),
                    if (onSubjectSelected != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.chevron_right, color: Color(0xFF5DB075)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      const Text(
        'Bars show each subject’s share of total EcoPoints.',
        style: AppTypography.helper,
        textAlign: TextAlign.center,
      ),
    ],
  );
}
