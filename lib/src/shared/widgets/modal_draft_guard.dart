import 'popup_exit_fallback.dart';
import 'package:flutter/material.dart';

class ModalDraft {
  final Map<TextEditingController, String> initial = {};
  bool changed = false;
  VoidCallback? onDiscard;
  void discard() {
    for (final entry in initial.entries) {
      try {
        entry.key.text = entry.value;
      } catch (_) {}
    }
    onDiscard?.call();
  }

  bool get dirty {
    if (changed) return true;
    for (final entry in initial.entries) {
      try {
        if (entry.key.text != entry.value) return true;
      } catch (_) {}
    }
    return false;
  }
}

class ModalDraftScope extends InheritedWidget {
  const ModalDraftScope({super.key, required this.draft, required super.child});
  final ModalDraft draft;
  static void saved(BuildContext context) {
    final draft = context
        .getInheritedWidgetOfExactType<ModalDraftScope>()
        ?.draft;
    if (draft == null) return;
    draft.changed = false;
    for (final controller in draft.initial.keys.toList()) {
      try {
        draft.initial[controller] = controller.text;
      } catch (_) {}
    }
  }

  static void onDiscard(BuildContext context, VoidCallback callback) {
    context.getInheritedWidgetOfExactType<ModalDraftScope>()?.draft.onDiscard =
        callback;
  }

  static void changed(BuildContext context) {
    context.getInheritedWidgetOfExactType<ModalDraftScope>()?.draft.changed =
        true;
  }

  @override
  bool updateShouldNotify(ModalDraftScope oldWidget) => false;
}

class CaptureModalDraft extends StatefulWidget {
  const CaptureModalDraft({
    super.key,
    required this.draft,
    required this.child,
  });
  final ModalDraft draft;
  final Widget child;
  @override
  State<CaptureModalDraft> createState() => _CaptureModalDraftState();
}

class _CaptureModalDraftState extends State<CaptureModalDraft> {
  void _capture() {
    if (!mounted) return;
    void visit(Element element) {
      final w = element.widget;
      final controller = w is TextField
          ? w.controller
          : w is TextFormField
          ? w.controller
          : null;
      if (controller != null)
        widget.draft.initial.putIfAbsent(controller, () => controller.text);
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
    return ModalDraftScope(draft: widget.draft, child: widget.child);
  }
}

mixin ProtectModalDraft<T> on TransitionRoute<T> {
  ModalDraft get draft;
  bool _allowClose = false;
  bool _confirming = false;
  @override
  bool didPop(T? result) {
    // Non-null results represent Save/Submit/selection confirmation. false is
    // used by our creation flows to mean Cancel/back.
    if (!_allowClose && (result == null || result == false) && draft.dirty) {
      if (!_confirming) {
        _confirming = true;
        Future<void>(() async {
          final nav = navigator;
          if (nav == null) {
            _confirming = false;
            return;
          }
          final discard = await showDialog<bool>(
            context: nav.context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Discard changes?'),
              content: const Text('Your unsaved changes will be lost.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          _confirming = false;
          if (discard == true && isActive) {
            draft.discard();
            _allowClose = true;
            nav.pop(result);
          }
        });
      }
      return false;
    }
    return super.didPop(result);
  }
}

class DraftDialogRoute<T> extends DialogRoute<T> with ProtectModalDraft<T> {
  DraftDialogRoute({
    required this.draft,
    required super.context,
    required super.builder,
    super.themes,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    super.useSafeArea,
    super.settings,
    super.requestFocus,
    super.anchorPoint,
    super.traversalEdgeBehavior,
    super.fullscreenDialog,
    super.animationStyle,
  });
  @override
  final ModalDraft draft;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => PopupExitFallback(
    child: super.buildPage(context, animation, secondaryAnimation),
  );
}

class DraftBottomSheetRoute<T> extends ModalBottomSheetRoute<T>
    with ProtectModalDraft<T> {
  DraftBottomSheetRoute({
    required this.draft,
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.scrollControlDisabledMaxHeightRatio,
    super.isDismissible,
    super.enableDrag,
    super.showDragHandle,
    super.useSafeArea,
    super.settings,
    super.transitionAnimationController,
    super.anchorPoint,
    super.sheetAnimationStyle,
    super.requestFocus,
  });
  @override
  final ModalDraft draft;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => PopupExitFallback(
    child: super.buildPage(context, animation, secondaryAnimation),
  );
}
