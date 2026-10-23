import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../styling/app_colors.dart';
import '../styling/app_metrics.dart';
import '../styling/app_typography.dart';

Future<T?> showCreateMenu<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Dismiss',
  barrierColor: const Color.fromRGBO(60, 60, 60, .64),
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (context, _, __) => const SizedBox.shrink(),
  transitionBuilder: (context, animation, _, __) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: .88, end: 1).animate(curved),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: builder(context),
          ),
        ),
      ),
    );
  },
);

class CreateMenuDialog extends StatelessWidget {
  const CreateMenuDialog({
    super.key,
    required this.onClose,
    this.onCommunityTap,
    this.communityName,
    required this.onJournalTap,
    required this.onProjectTap,
  });

  static const _primary = Color(0xFF5DB075);
  static const _iconBackground = Color(0xFFD2E2DA);

  final VoidCallback onClose;
  final VoidCallback? onCommunityTap;
  final String? communityName;
  final VoidCallback onJournalTap;
  final VoidCallback onProjectTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF707070),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Center(
                      child: Text(
                        'Create',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.primary,
                          fontSize: AppTypography.buttonSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
              if (communityName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Create for $communityName',
                  textAlign: TextAlign.center,
                  style: AppTypography.helper,
                ),
                const SizedBox(height: 4),
                const Text(
                  'New projects will be linked to this community.',
                  textAlign: TextAlign.center,
                  style: AppTypography.helper,
                ),
              ],
              const SizedBox(height: AppMetrics.fieldGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onCommunityTap != null)
                    Expanded(
                      child: _CreateMenuOption(
                        assetPath: 'assets/create_menu/community.svg',
                        label: 'Community',
                        onTap: onCommunityTap!,
                      ),
                    ),
                  Expanded(
                    child: _CreateMenuOption(
                      assetPath: 'assets/create_menu/journal.svg',
                      label: 'Journal',
                      onTap: onJournalTap,
                    ),
                  ),
                  Expanded(
                    child: _CreateMenuOption(
                      assetPath: 'assets/create_menu/new_project.svg',
                      label: 'New Project',
                      onTap: onProjectTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateMenuOption extends StatefulWidget {
  const _CreateMenuOption({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final VoidCallback onTap;

  @override
  State<_CreateMenuOption> createState() => _CreateMenuOptionState();
}

class _CreateMenuOptionState extends State<_CreateMenuOption> {
  bool _hovered = false;
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    final color = active ? AppColors.primaryDark : CreateMenuDialog._primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        onTap: widget.onTap,
        label: widget.label,
        excludeSemantics: true,
        child: InkWell(
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Material(
                    color: CreateMenuDialog._iconBackground,
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: SvgPicture.asset(
                        widget.assetPath,
                        width: 48,
                        height: 48,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.labelGap),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label.toUpperCase(),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
