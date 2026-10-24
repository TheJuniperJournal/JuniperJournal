import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/features/learning_module/learning_module.dart';

class ModuleDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> module;

  const ModuleDashboardScreen({super.key, required this.module});

  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);

  @override
  Widget build(BuildContext context) {
    final canvasWidth = JournalPageLayout.widthFor(context, mobileWidth: 402);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: canvasWidth),
            child: PageScrollWithFooter(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: canvasWidth,
                  height: 861,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 21,
                        top: 24,
                        width: 47,
                        height: 22,
                        child: AppTapTarget(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          child: const Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Done',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                color: AppColors.primary,
                                fontSize: AppTypography.buttonSize,
                                height: 1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (canvasWidth - 215) / 2,
                        top: 24,
                        width: 215,
                        height: 40,
                        child: _DashboardTag(),
                      ),
                      Positioned(
                        right: 29,
                        top: 24,
                        width: 35,
                        height: 35,
                        child: AppTapTarget(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: SvgPicture.asset(
                            'assets/learning_module/dashboard_settings.svg',
                            width: 35,
                            height: 35,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 26,
                        top: 126,
                        width: canvasWidth - 53,
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFEDEDED),
                        ),
                      ),
                      Positioned(
                        left: 37,
                        top: 162,
                        child: _DashboardCard(
                          title: 'Concept\nExploration',
                          icon: const _DashboardConceptIcon(),
                          onTap: () {
                            pushAppRoute(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ConceptExplorationScreen(module: module),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        left: canvasWidth / 2 + 17,
                        top: 162,
                        child: _DashboardCard(
                          title: 'Learning\nObjectives',
                          iconAsset:
                              'assets/learning_module/dashboard_learning_objectives.svg',
                          iconWidth: 23,
                          iconHeight: 26,
                          onTap: () {
                            pushAppRoute(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    LearningObjectiveScreen(module: module),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        left: 37,
                        top: 363,
                        child: _DashboardCard(
                          title: 'Learning\nSummary',
                          iconAsset:
                              'assets/learning_module/dashboard_learning_summary.svg',
                          iconWidth: 22,
                          iconHeight: 25,
                          onTap: () {
                            pushAppRoute(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Summary(module: module),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTag extends StatelessWidget {
  const _DashboardTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ModuleDashboardScreen._green,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Text(
        'PROJECT DASHBOARD',
        style: TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: Colors.white,
          fontSize: AppTypography.bodySize,
          height: 1,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String? iconAsset;
  final double? iconWidth;
  final double? iconHeight;
  final Widget? icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    this.iconAsset,
    this.iconWidth,
    this.iconHeight,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: MediaQuery.sizeOf(context).width >= 1000
            ? (JournalPageLayout.widthFor(context, mobileWidth: 402) - 124) / 2
            : 139,
        height: 163,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD8D0D0)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, 14),
              blurRadius: 30,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: AppMetrics.fieldGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: ModuleDashboardScreen._text,
                fontSize: AppTypography.bodySize,
                height: 1.08,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppMetrics.labelGap),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ModuleDashboardScreen._green),
              ),
              alignment: Alignment.center,
              child:
                  icon ??
                  SvgPicture.asset(
                    iconAsset!,
                    width: iconWidth,
                    height: iconHeight,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardConceptIcon extends StatelessWidget {
  const _DashboardConceptIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 39.484375,
      height: 25.71484375,
      child: Stack(
        children: [
          Positioned(
            left: 13.0390625,
            top: 9.572265625,
            width: 2.392857074737549,
            height: 2.392857074737549,
            child: SvgPicture.asset(
              'assets/create_menu/learning_module_cube_dot.svg',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: 10.64453125,
            top: 7.1787109375,
            width: 16.75,
            height: 19.14285659790039,
            child: SvgPicture.asset(
              'assets/create_menu/learning_module_cube.svg',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: 22.609375,
            top: 0,
            width: 16.75,
            height: 19.14285659790039,
            child: SvgPicture.asset(
              'assets/create_menu/learning_module_cube.svg',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: -0.125,
            top: 0,
            width: 16.75,
            height: 19.14285659790039,
            child: SvgPicture.asset(
              'assets/create_menu/learning_module_cube.svg',
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}
