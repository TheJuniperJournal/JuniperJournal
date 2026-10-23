import 'modal_actions.dart';
import '../styling/app_typography.dart';
import '../styling/app_colors.dart';
import 'package:flutter/material.dart';

/// Only server-claimed, previously unannounced rewards enter this channel.
final ecoRewardNotice = ValueNotifier<String?>(null);
final ecoRewardNavigatorKey = GlobalKey<NavigatorState>();
final journalCompletionNotice = ValueNotifier<JournalCompletionNotice?>(null);

class JournalCompletionNotice {
  const JournalCompletionNotice({required this.entryId, required this.points});
  final String entryId;
  final int points;
}

class EcoRewardNoticeHost extends StatefulWidget {
  const EcoRewardNoticeHost({super.key, required this.child});
  final Widget child;
  @override
  State<EcoRewardNoticeHost> createState() => _EcoRewardNoticeHostState();
}

class _EcoRewardNoticeHostState extends State<EcoRewardNoticeHost> {
  @override
  void initState() {
    super.initState();
    ecoRewardNotice.addListener(_show);
    journalCompletionNotice.addListener(_queueCompletion);
  }

  final _completions = <JournalCompletionNotice>[];
  bool _showingCompletion = false;

  void _queueCompletion() {
    final notice = journalCompletionNotice.value;
    if (notice == null) return;
    _completions.add(notice);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNextCompletion());
  }

  Future<void> _showNextCompletion() async {
    if (!mounted || _showingCompletion || _completions.isEmpty) return;
    final context = ecoRewardNavigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    _showingCompletion = true;
    final notice = _completions.removeAt(0);
    try {
      await showAppDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Journal entry completed',
                    textAlign: TextAlign.center,
                    style: AppTypography.pageTitle,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '+${notice.points} EcoPoints',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.pageTitleSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 160,
                    height: 44,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      _showingCompletion = false;
      if (mounted && _completions.isNotEmpty) _showNextCompletion();
    }
  }

  void _show() {
    final text = ecoRewardNotice.value;
    if (text == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(text)));
    });
  }

  @override
  void dispose() {
    ecoRewardNotice.removeListener(_show);
    journalCompletionNotice.removeListener(_queueCompletion);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
