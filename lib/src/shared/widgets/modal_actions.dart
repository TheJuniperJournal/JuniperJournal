import 'modal_draft_guard.dart';
export 'modal_draft_guard.dart' show ModalDraftScope;
import 'package:flutter/material.dart';

// A modal can only be launched from the visible route. The synchronous lock
// also covers repeated callbacks before Flutter has rebuilt the first popup.
final _openingRoutes = Expando<bool>();

Future<T?> _openModalOnce<T>(
  BuildContext context,
  Future<T?> Function() open,
) async {
  if (!context.mounted) return null;
  final route = ModalRoute.of(context);
  if (route != null && (!route.isCurrent || _openingRoutes[route] == true))
    return null;
  if (route != null) _openingRoutes[route] = true;
  try {
    return await open();
  } finally {
    if (route != null) _openingRoutes[route] = false;
  }
}

final _pendingActions = Expando<Set<String>>();

/// Acquires the lock before any asynchronous loading or saving starts.
Future<void> runActionOnce(
  Object owner,
  String action,
  Future<void> Function() run,
) async {
  final pending = _pendingActions[owner] ??= <String>{};
  if (!pending.add(action)) return;
  try {
    await run();
  } finally {
    pending.remove(action);
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
  AnimationStyle? animationStyle,
}) => _openModalOnce<T>(context, () {
  final draft = ModalDraft();
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    DraftDialogRoute<T>(
      draft: draft,
      themes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: useRootNavigator).context,
      ),
      context: context,
      builder: (context) => CaptureModalDraft(
        draft: draft,
        child: Builder(builder: builder),
      ),
      barrierDismissible: barrierDismissible,
      barrierColor:
          barrierColor ??
          Theme.of(context).dialogTheme.barrierColor ??
          Colors.black54,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior: traversalEdgeBehavior,
      fullscreenDialog: fullscreenDialog,
      requestFocus: requestFocus,
      animationStyle: animationStyle,
    ),
  );
});

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = false,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  AnimationStyle? sheetAnimationStyle,
  bool? requestFocus,
}) => _openModalOnce<T>(context, () {
  final desktop = MediaQuery.sizeOf(context).width >= 1000;
  if (desktop) {
    final draft = ModalDraft();
    return Navigator.of(context, rootNavigator: true).push<T>(
      DraftDialogRoute<T>(
        context: context,
        draft: draft,
        barrierDismissible: isDismissible,
        barrierColor: barrierColor ?? Colors.black54,
        barrierLabel: barrierLabel,
        settings: routeSettings,
        builder: (ctx) => Dialog(
          backgroundColor: backgroundColor ?? Theme.of(ctx).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: MediaQuery.sizeOf(ctx).height * .85,
            ),
            child: CaptureModalDraft(
              draft: draft,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    );
  }
  final draft = ModalDraft();
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    DraftBottomSheetRoute<T>(
      draft: draft,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: useRootNavigator).context,
      ),
      builder: (context) => CaptureModalDraft(
        draft: draft,
        child: Builder(builder: builder),
      ),
      backgroundColor: backgroundColor,
      barrierLabel: barrierLabel,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      modalBarrierColor: barrierColor,
      isScrollControlled: isScrollControlled,
      scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
      sheetAnimationStyle: sheetAnimationStyle,
      requestFocus: requestFocus,
    ),
  );
});
