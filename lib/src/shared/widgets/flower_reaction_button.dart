import 'package:flutter/material.dart';
import '../../backend/db/repositories/flower_reactions_repo.dart';
import '../styling/app_colors.dart';
export '../../backend/db/repositories/flower_reactions_repo.dart'
    show FlowerTarget;

class FlowerReactionButton extends StatefulWidget {
  const FlowerReactionButton({
    super.key,
    required this.target,
    required this.targetId,
    this.repo,
    this.builder,
  });
  final FlowerTarget target;
  final String targetId;
  final FlowerReactionsRepo? repo;
  final Widget Function(BuildContext, FlowerState?, bool, VoidCallback)?
  builder;
  @override
  State<FlowerReactionButton> createState() => _FlowerReactionButtonState();
}

class _FlowerReactionButtonState extends State<FlowerReactionButton> {
  FlowerState? _value;
  bool _busy = false;
  late FlowerReactionsRepo _repo;
  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? FlowerReactionsRepo();
    _load();
  }

  @override
  void didUpdateWidget(covariant FlowerReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId ||
        oldWidget.target != widget.target) {
      _value = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.targetId;
    try {
      final value = await _repo.load(widget.target, id);
      if (mounted && widget.targetId == id) setState(() => _value = value);
    } catch (_) {
      /* Keep the control available for an explicit retry. */
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final previous = _value;
    try {
      final current =
          previous ?? await _repo.load(widget.target, widget.targetId);
      final selected = !current.selected;
      if (mounted)
        setState(
          () => _value = FlowerState(
            current.count + (selected ? 1 : -1),
            selected,
          ),
        );
      await _repo.setSelected(widget.target, widget.targetId, selected);
      final confirmed = await _repo.load(widget.target, widget.targetId);
      if (mounted) setState(() => _value = confirmed);
    } catch (_) {
      if (mounted) {
        setState(() => _value = previous);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Could not update your flower. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null)
      return widget.builder!(context, _value, _busy, _toggle);
    final selected = _value?.selected ?? false;
    final count = _value?.count ?? 0;
    return Semantics(
      toggled: selected,
      label: '$count flowers',
      child: TextButton(
        onPressed: _busy ? null : _toggle,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(44, 44),
          foregroundColor: selected
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.local_florist : Icons.local_florist_outlined,
              size: 20,
            ),
            if (count > 0) ...[const SizedBox(width: 8), Text('$count')],
          ],
        ),
      ),
    );
  }
}
