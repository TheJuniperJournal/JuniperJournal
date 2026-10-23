import 'package:flutter/material.dart';
import '../styling/app_colors.dart';

/// Validation belongs to the current editor route, never to the saved draft.
class JournalValidationIssue {
  JournalValidationIssue(this.message, this.isMissing, {Listenable? changes})
    : changes = changes == null ? null : _LiveIssueChanges(changes);
  final String message;
  final bool Function() isMissing;
  final Listenable? changes;
}

// A removable field can dispose its controller before the footer rebuilds.
// Its final frame must not try to subscribe to that disposed controller.
class _LiveIssueChanges implements Listenable {
  _LiveIssueChanges(this.source);
  final Listenable source;
  @override
  void addListener(VoidCallback listener) {
    try {
      source.addListener(listener);
    } on FlutterError catch (error) {
      if (!error.toString().contains('disposed')) rethrow;
    }
  }

  @override
  void removeListener(VoidCallback listener) => source.removeListener(listener);
}

final _journalIssues = Expando<ValueNotifier<List<JournalValidationIssue>>>();
ValueNotifier<List<JournalValidationIssue>> journalValidationIssues(
  BuildContext context,
) {
  final owner = ModalRoute.of(context) ?? context;
  return _journalIssues[owner] ??= ValueNotifier([]);
}

/// A page-bottom action region, separate from scrolling journal fields.
class JournalActionFooter extends StatelessWidget {
  const JournalActionFooter({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ValueListenableBuilder<List<JournalValidationIssue>>(
          valueListenable: journalValidationIssues(context),
          builder: (context, issues, _) => AnimatedBuilder(
            animation: Listenable.merge([
              for (final issue in issues)
                if (issue.changes != null) issue.changes!,
            ]),
            builder: (context, _) {
              final messages = {
                for (final issue in issues)
                  if (issue.isMissing()) issue.message,
              };
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (messages.isNotEmpty)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 48),
                          child: SingleChildScrollView(
                            child: Text(
                              'To continue:\n${messages.join('\n')}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  child,
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
