import 'package:flutter/material.dart';
import 'app_scroll_behavior.dart';

/// Gives modal forms equal content margins and a dedicated desktop scroll lane.
class DialogFormScroll extends StatefulWidget {
  const DialogFormScroll({super.key, required this.child});
  final SingleChildScrollView child;
  @override
  State<DialogFormScroll> createState() => _DialogFormScrollState();
}

class _DialogFormScrollState extends State<DialogFormScroll> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = switch (ScrollConfiguration.of(
      context,
    ).getPlatform(context)) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    final source = widget.child;
    final controller = source.controller ?? _controller;
    final scroll = SingleChildScrollView(
      controller: controller,
      primary: false,
      padding: source.padding,
      physics: source.physics,
      keyboardDismissBehavior: source.keyboardDismissBehavior,
      child: source.child,
    );
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: desktop
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppScrollbar.gutterWidth,
                ),
                child: AppScrollbar(
                  key: const ValueKey('dialog-form-scrollbar'),
                  controller: controller,
                  thumbVisibility: true,
                  child: scroll,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: scroll,
            ),
    );
  }
}
