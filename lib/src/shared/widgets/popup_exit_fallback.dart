import 'package:flutter/material.dart';

/// Every modal has an escape control, including content supplied by a caller.
/// Existing visible Close/Cancel controls take precedence over this fallback.
class PopupExitFallback extends StatefulWidget {
  const PopupExitFallback({super.key, required this.child});
  final Widget child;
  @override
  State<PopupExitFallback> createState() => _PopupExitFallbackState();
}

class _PopupExitFallbackState extends State<PopupExitFallback> {
  final _contentKey = GlobalKey();
  bool _needsExit = false;
  void _checkExit() {
    if (!mounted) return;
    var found = false;
    final viewport = Offset.zero & MediaQuery.sizeOf(context);
    bool visible(Element element) {
      final box = element.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return false;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      return rect.width > 0 &&
          rect.height > 0 &&
          viewport.contains(rect.topLeft) &&
          viewport.contains(rect.bottomRight);
    }

    void visit(Element element) {
      if (found ||
          element.widget is Offstage && (element.widget as Offstage).offstage)
        return;
      final button = element.widget;
      if (button is ButtonStyleButton && button.onPressed != null ||
          button is IconButton && button.onPressed != null ||
          button is CloseButton ||
          button is BackButton) {
        var exit = button is CloseButton || button is BackButton;
        void inspect(Element child) {
          final item = child.widget;
          if (item is Icon &&
              [
                Icons.close,
                Icons.clear,
                Icons.cancel,
                Icons.cancel_outlined,
              ].contains(item.icon))
            exit = true;
          if (item is Text &&
              [
                'close',
                'cancel',
                'keep editing',
              ].contains(item.data?.trim().toLowerCase()))
            exit = true;
          child.visitChildren(inspect);
        }

        element.visitChildren(inspect);
        if (exit && visible(element)) found = true;
      }
      element.visitChildren(visit);
    }

    final root = _contentKey.currentContext as Element?;
    root?.visitChildren(visit);
    if (_needsExit == found) setState(() => _needsExit = !found);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExit());
    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(key: _contentKey, child: widget.child),
        if (_needsExit)
          Positioned(
            top: 12 + MediaQuery.paddingOf(context).top,
            right: 12 + MediaQuery.paddingOf(context).right,
            child: Material(
              color: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Close popup',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
      ],
    );
  }
}
