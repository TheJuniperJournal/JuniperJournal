import 'package:flutter/material.dart';
import '../styling/app_colors.dart';

/// Corner resizing preserves the image's aspect ratio and saved relative width.
class ImageResizeFrame extends StatefulWidget {
  const ImageResizeFrame({
    super.key,
    required this.width,
    required this.maxWidth,
    required this.selected,
    required this.onResize,
    required this.child,
  });
  final double width, maxWidth;
  final bool selected;
  final ValueChanged<double>? onResize;
  final Widget child;

  @override
  State<ImageResizeFrame> createState() => _ImageResizeFrameState();
}

class _ImageResizeFrameState extends State<ImageResizeFrame> {
  final _frame = GlobalKey();
  Offset _origin = Offset.zero;
  double _startWidth = 0, _ratio = 1;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: _frame,
    width: widget.width,
    child: Stack(
      children: [
        widget.child,
        if (widget.selected && widget.onResize != null) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          for (final corner in [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Positioned(
              left: corner.x < 0 ? 0 : null,
              right: corner.x > 0 ? 0 : null,
              top: corner.y < 0 ? 0 : null,
              bottom: corner.y > 0 ? 0 : null,
              child: Semantics(
                label: 'Resize image',
                child: MouseRegion(
                  cursor: corner.x == corner.y
                      ? SystemMouseCursors.resizeUpLeftDownRight
                      : SystemMouseCursors.resizeUpRightDownLeft,
                  child: GestureDetector(
                    key: ValueKey('image-resize-${corner.x}-${corner.y}'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) {
                      _origin = d.globalPosition;
                      _startWidth = widget.width;
                      final size =
                          (_frame.currentContext!.findRenderObject()
                                  as RenderBox)
                              .size;
                      _ratio = size.height > 0 ? size.width / size.height : 1;
                    },
                    onPanUpdate: (d) {
                      final delta = d.globalPosition - _origin;
                      final change =
                          (delta.dx * corner.x + delta.dy * corner.y / _ratio) /
                          (1 + 1 / (_ratio * _ratio));
                      widget.onResize!(
                        (_startWidth + change).clamp(
                              widget.maxWidth * .25,
                              widget.maxWidth,
                            ) /
                            widget.maxWidth,
                      );
                    },
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Align(
                        alignment: corner,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
