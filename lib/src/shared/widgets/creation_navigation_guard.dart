import 'package:flutter/material.dart';

/// Coordinates global Create with an unfinished project/community form.
/// These forms have no draft storage: leaving requires explicit discard.
class CreationNavigationGuard extends StatefulWidget {
  const CreationNavigationGuard({
    super.key,
    required this.fingerprint,
    required this.child,
  });
  final String Function() fingerprint;
  final Widget child;
  static final _active = <ModalRoute<dynamic>, _CreationNavigationGuardState>{};

  static Future<bool> leaveCurrent(NavigatorState navigator) async {
    for (final entry in _active.entries.toList()) {
      final state = entry.value;
      if (!entry.key.isCurrent ||
          !state.mounted ||
          Navigator.of(state.context) != navigator)
        continue;
      if (state._asking) return false;
      state._asking = true;
      var discard = true;
      if (state.widget.fingerprint() != state._initial) {
        discard =
            await showDialog<bool>(
              context: state.context,
              builder: (context) => AlertDialog(
                title: const Text('Discard changes?'),
                content: const Text(
                  'This form cannot be saved as a draft. Discard it to create something else.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep Editing'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard & Continue'),
                  ),
                ],
              ),
            ) ??
            false;
      }
      state._asking = false;
      if (!discard || !state.mounted || !navigator.canPop()) return false;
      navigator.pop();
      await WidgetsBinding.instance.endOfFrame;
      return true;
    }
    return true;
  }

  @override
  State<CreationNavigationGuard> createState() =>
      _CreationNavigationGuardState();
}

class _CreationNavigationGuardState extends State<CreationNavigationGuard> {
  late final String _initial;
  ModalRoute<dynamic>? _route;
  bool _asking = false;
  @override
  void initState() {
    super.initState();
    _initial = widget.fingerprint();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_route != null) CreationNavigationGuard._active[_route!] = this;
  }

  @override
  void dispose() {
    CreationNavigationGuard._active.remove(_route);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
