import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:flutter/material.dart';

/// The visible chevron starts at the content edge; the tap area remains 44px.
class ContentAlignedBackButton extends StatelessWidget {
  const ContentAlignedBackButton({
    super.key,
    required this.onPressed,
    this.size = 34,
    this.color = const Color(0xFF5DB075),
  });
  final VoidCallback? onPressed;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    enabled: onPressed != null,
    child: Tooltip(
      message: 'Back',
      child: MouseRegion(
        cursor: onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: AppTapTarget(
          highlightInsets: const EdgeInsets.fromLTRB(0, 7, 22, 7),
          highlightBorderRadius: BorderRadius.circular(20),
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: CustomPaint(
                key: const ValueKey('content-back-chevron'),
                size: Size(size * .36, size * .66),
                painter: _EdgeChevron(color),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EdgeChevron extends CustomPainter {
  const _EdgeChevron(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * .13;
    canvas.drawPath(
      Path()
        ..moveTo(size.width - stroke / 2, stroke / 2)
        ..lineTo(stroke / 2, size.height / 2)
        ..lineTo(size.width - stroke / 2, size.height - stroke / 2),
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(covariant _EdgeChevron oldDelegate) =>
      oldDelegate.color != color;
}
