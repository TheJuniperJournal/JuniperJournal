import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../backend/db/supabase_database.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';

class ProjectTimeSummary {
  const ProjectTimeSummary({
    required this.participant,
    required this.personalSeconds,
    required this.totalSeconds,
  });
  final bool participant;
  final int personalSeconds, totalSeconds;
  factory ProjectTimeSummary.fromJson(Map data) => ProjectTimeSummary(
    participant: data['participant'] == true,
    personalSeconds: (data['personal_seconds'] as num? ?? 0).toInt(),
    totalSeconds: (data['total_seconds'] as num? ?? 0).toInt(),
  );
}

class ProjectActivityRepo {
  ProjectActivityRepo(this.projects);
  final ProjectsRepo projects;
  String? get userId {
    try {
      return projects.currentUserId;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isParticipant(String projectId) async {
    try {
      return await projects.canViewInternalProjectLogs(projectId);
    } catch (_) {
      return false;
    }
  }

  Future<ProjectTimeSummary?> read(String projectId) async {
    try {
      final value = await SupabaseDatabase.instance.client.rpc(
        'get_project_activity_time',
        params: {'p_project_id': projectId},
      );
      return ProjectTimeSummary.fromJson(value as Map);
    } catch (_) {
      return null;
    }
  }

  Future<ProjectTimeSummary?> record(
    String projectId,
    String sessionId,
    int seconds,
  ) async {
    try {
      final value = await SupabaseDatabase.instance.client.rpc(
        'record_project_activity_time',
        params: {
          'p_project_id': projectId,
          'p_session_id': sessionId,
          'p_seconds': seconds,
        },
      );
      return ProjectTimeSummary.fromJson(value as Map);
    } catch (_) {
      return null;
    }
  }
}

String _sessionId() {
  final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// One meter per user/project, shared by dashboard and nested editors.
class ProjectTimeMeter extends ChangeNotifier {
  ProjectTimeMeter(this.projectId, this.repo) : _userId = repo.userId {
    ready = _load();
  }
  final String projectId;
  final ProjectActivityRepo repo;
  final String? _userId;
  late final Future<void> ready;
  final String sessionId = _sessionId();
  final Map<String, Map<String, int>> _pending = {};
  ProjectTimeSummary? summary;
  bool participant = false, loaded = false, _syncing = false;
  String get _key => 'project-active-time-v1-$_userId-$projectId';
  int get unsyncedSeconds => _pending.values.fold(
    0,
    (n, row) => n + max(0, row['seconds']! - row['ack']!),
  );
  int get displaySeconds => participant
      ? (summary?.personalSeconds ?? 0) + unsyncedSeconds
      : summary?.totalSeconds ?? 0;
  bool get available => summary != null || participant;
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = jsonDecode(prefs.getString(_key) ?? '{}') as Map;
      for (final entry in rows.entries) {
        final row = entry.value as Map;
        _pending[entry.key.toString()] = {
          'seconds': (row['seconds'] as num).toInt(),
          'ack': (row['ack'] as num? ?? 0).toInt(),
        };
      }
    } catch (_) {}
    summary = await repo.read(projectId);
    participant =
        repo.userId != null &&
        (summary?.participant ?? await repo.isParticipant(projectId));
    loaded = true;
    notifyListeners();
    if (participant && _pending.isNotEmpty) unawaited(sync());
  }

  void addSeconds(int seconds) {
    if (!loaded || !participant || repo.userId != _userId || seconds <= 0)
      return;
    final row = _pending.putIfAbsent(sessionId, () => {'seconds': 0, 'ack': 0});
    row['seconds'] = row['seconds']! + seconds;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_pending));
    } catch (_) {}
  }

  Future<void> sync() async {
    await ready;
    if (_syncing || repo.userId != _userId) return;
    _syncing = true;
    try {
      final latestSummary = await repo.read(projectId);
      if (latestSummary != null) {
        summary = latestSummary;
        participant = repo.userId != null && latestSummary.participant;
        notifyListeners();
      }
      if (!participant) return;
      for (final id in _pending.keys.toList()) {
        final row = _pending[id]!;
        if (row['seconds'] == row['ack']) continue;
        final sent = row['seconds']!;
        final latest = await repo.record(projectId, id, sent);
        if (latest == null) continue;
        summary = latest;
        row['ack'] = sent;
        if (id != sessionId) _pending.remove(id);
        notifyListeners();
      }
      await _persist();
    } finally {
      _syncing = false;
    }
  }
}

class ProjectActivity {
  static final _meters = <String, ProjectTimeMeter>{};
  static final _routes = <Route<dynamic>, ProjectTimeMeter>{};
  static ProjectTimeMeter meter(String id, ProjectsRepo repo) {
    final activity = ProjectActivityRepo(repo);
    return _meters.putIfAbsent(
      '${activity.userId}:$id',
      () => ProjectTimeMeter(id, activity),
    );
  }

  static void inheritRoute(Route<dynamic> route, BuildContext source) {
    final parent = ModalRoute.of(source);
    final meter = _routes[parent];
    if (meter != null && parent?.isCurrent == true) _routes[route] = meter;
  }

  static void forgetRoute(Route<dynamic> route) {
    _routes.remove(route);
  }

  static ProjectTimeMeter? get current => _routes[desktopRouteObserver.current];
}

class ProjectActivityScope extends StatefulWidget {
  const ProjectActivityScope({
    super.key,
    required this.projectId,
    required this.repo,
    required this.child,
  });
  final String projectId;
  final ProjectsRepo repo;
  final Widget child;
  @override
  State<ProjectActivityScope> createState() => _ProjectActivityScopeState();
}

class _ProjectActivityScopeState extends State<ProjectActivityScope> {
  Route<dynamic>? _route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_route != null)
      ProjectActivity._routes[_route!] = ProjectActivity.meter(
        widget.projectId,
        widget.repo,
      );
  }

  @override
  void dispose() {
    if (_route != null) ProjectActivity.forgetRoute(_route!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A foreground activity estimate, not a measure of work quality.
class ProjectActivityWindow {
  int lastInput = 0, lastTick = 0;
  bool foreground = true;
  void input(int milliseconds) => lastInput = milliseconds;
  int tick(int milliseconds) {
    final seconds = min(2, max(0, (milliseconds - lastTick) ~/ 1000));
    lastTick = milliseconds;
    return foreground && milliseconds - lastInput < 90000 ? seconds : 0;
  }
}

/// Counts foreground use, pausing after 90 seconds without input.
class ProjectActivityHost extends StatefulWidget {
  const ProjectActivityHost({super.key, required this.child});
  final Widget child;
  @override
  State<ProjectActivityHost> createState() => _ProjectActivityHostState();
}

class _ProjectActivityHostState extends State<ProjectActivityHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _ticks = 0;
  final _window = ProjectActivityWindow();
  ProjectTimeMeter? _previous;
  void _input([Object? _]) {
    _window.input(_clock.elapsedMilliseconds);
  }

  bool _key(KeyEvent _) {
    _input();
    return false;
  }

  void _routeChanged() {
    final current = ProjectActivity.current;
    if (current != _previous) {
      if (_previous != null) unawaited(_previous!.sync());
      _previous = current;
      _input();
    }
  }

  @override
  void initState() {
    super.initState();
    _clock.start();
    _window.foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_key);
    desktopRouteObserver.changes.addListener(_routeChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = _clock.elapsedMilliseconds;
      final elapsed = _window.tick(now);
      final meter = ProjectActivity.current;
      _routeChanged();
      meter?.addSeconds(elapsed);
      if (++_ticks % 15 == 0 && meter != null) unawaited(meter.sync());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _window.foreground = state == AppLifecycleState.resumed;
    if (_window.foreground) {
      _window.lastTick = _clock.elapsedMilliseconds;
      _input();
    } else if (ProjectActivity.current != null)
      unawaited(ProjectActivity.current!.sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_key);
    desktopRouteObserver.changes.removeListener(_routeChanged);
    if (ProjectActivity.current != null)
      unawaited(ProjectActivity.current!.sync());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _input,
    onPointerSignal: _input,
    onPointerHover: _input,
    onPointerMove: _input,
    behavior: HitTestBehavior.translucent,
    child: widget.child,
  );
}

String formatProjectTime(int seconds) {
  if (seconds == 0) return '0 min';
  if (seconds < 60) return '<1 min';
  if (seconds < 3600) return '${seconds ~/ 60} min';
  final minutes = seconds % 3600 ~/ 60;
  return '${seconds ~/ 3600} hr${seconds >= 7200 ? 's' : ''}${minutes == 0 ? '' : ' $minutes min'}';
}
