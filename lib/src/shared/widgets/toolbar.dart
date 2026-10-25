import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import '../styling/app_colors.dart';

/// A toolbar for the Concept Exploration page that allows users to build their own modules.
/// Features include inserting textboxes, resizing elements, camera/photo upload, math equations, and tables.
class ConceptExplorationToolbar extends StatelessWidget {
  final VoidCallback? onCamera;
  final VoidCallback? onInsertMath;
  final VoidCallback? onInsertTable;
  final Function(ParchmentAttribute)? onFormat;

  const ConceptExplorationToolbar({
    super.key,
    this.onCamera,
    this.onInsertMath,
    this.onInsertTable,
    this.onFormat,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 62,
          decoration: ShapeDecoration(
            color: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(64),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 4,
                offset: Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _FormatButton(onFormat: onFormat),
              _ToolbarButton(icon: Icons.camera_alt, onPressed: onCamera),
              _ToolbarButton(icon: Icons.functions, onPressed: onInsertMath),
              _ToolbarButton(icon: Icons.table_chart, onPressed: onInsertTable),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatting button with popup menu for text styling
class _FormatButton extends StatelessWidget {
  final Function(ParchmentAttribute)? onFormat;

  const _FormatButton({this.onFormat});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      clipBehavior: Clip.antiAlias,
      icon: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: const Icon(Icons.format_size, color: AppColors.white, size: 26),
      ),
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, -180),
      onSelected: (value) {
        if (onFormat == null) return;

        switch (value) {
          case 'bold':
            onFormat!(ParchmentAttribute.bold);
            break;
          case 'italic':
            onFormat!(ParchmentAttribute.italic);
            break;
          case 'h1':
            onFormat!(ParchmentAttribute.h1);
            break;
          case 'h2':
            onFormat!(ParchmentAttribute.h2);
            break;
          case 'h3':
            onFormat!(ParchmentAttribute.h3);
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'bold',
          child: Row(
            children: [
              Icon(Icons.format_bold, color: AppColors.darkText, size: 20),
              const SizedBox(width: 12),
              Text('Bold', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'italic',
          child: Row(
            children: [
              Icon(Icons.format_italic, color: AppColors.darkText, size: 20),
              const SizedBox(width: 12),
              Text('Italic', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'h1',
          child: Row(
            children: [
              Icon(Icons.title, color: AppColors.darkText, size: 20),
              const SizedBox(width: 12),
              Text(
                'Heading 1',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'h2',
          child: Row(
            children: [
              Icon(Icons.title, color: AppColors.darkText, size: 18),
              const SizedBox(width: 12),
              Text(
                'Heading 2',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'h3',
          child: Row(
            children: [
              Icon(Icons.title, color: AppColors.darkText, size: 16),
              const SizedBox(width: 12),
              Text(
                'Heading 3',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Individual toolbar button with icon
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _ToolbarButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.white, size: 26),
      ),
    );
  }
}
