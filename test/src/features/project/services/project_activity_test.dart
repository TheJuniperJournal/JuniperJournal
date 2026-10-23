import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/services/project_activity.dart';

class FakeActivity extends ProjectActivityRepo {
  FakeActivity({this.member = true}) : super(ProjectsRepo());
  final bool member;
  bool offline = false;
  final sessions = <String, int>{};
  @override
  String get userId => 'person';
  ProjectTimeSummary get value => ProjectTimeSummary(
    participant: member,
    personalSeconds: sessions.values.fold(0, (a, b) => a + b),
    totalSeconds: 500 + sessions.values.fold(0, (a, b) => a + b),
  );
  @override
  Future<bool> isParticipant(String id) async => member;
  @override
  Future<ProjectTimeSummary?> read(String id) async => offline ? null : value;
  @override
  Future<ProjectTimeSummary?> record(
    String id,
    String session,
    int seconds,
  ) async {
    if (offline) return null;
    sessions[session] = seconds > (sessions[session] ?? 0)
        ? seconds
        : sessions[session]!;
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'participant sees personal time, cumulative sync does not double count',
    () async {
      final repo = FakeActivity();
      final meter = ProjectTimeMeter('project', repo);
      await meter.ready;
      meter.addSeconds(70);
      expect(meter.displaySeconds, 70);
      await meter.sync();
      await meter.sync();
      expect(meter.displaySeconds, 70);
      meter.addSeconds(20);
      await meter.sync();
      expect(meter.displaySeconds, 90);
      expect(repo.value.totalSeconds, 590);
      expect(repo.sessions.length, 1);
    },
  );
  test(
    'visitor sees combined time and cannot accumulate contribution',
    () async {
      final repo = FakeActivity(member: false);
      final meter = ProjectTimeMeter('project', repo);
      await meter.ready;
      meter.addSeconds(90);
      await meter.sync();
      expect(meter.displaySeconds, 500);
      expect(repo.sessions, isEmpty);
    },
  );
  test('offline pending time survives refresh and syncs once', () async {
    final repo = FakeActivity()..offline = true;
    final first = ProjectTimeMeter('project', repo);
    await first.ready;
    first.addSeconds(61);
    await first.sync();
    final refreshed = ProjectTimeMeter('project', repo);
    await refreshed.ready;
    expect(refreshed.displaySeconds, 61);
    repo.offline = false;
    await refreshed.sync();
    expect(refreshed.displaySeconds, 61);
    await refreshed.sync();
    expect(repo.value.personalSeconds, 61);
  });
  test('idle and hidden windows pause; returning does not add hidden time', () {
    final window = ProjectActivityWindow();
    expect(window.tick(1000), 1);
    expect(window.tick(90000), 0);
    window.input(90000);
    expect(window.tick(91000), 1);
    window.foreground = false;
    window.input(92000);
    expect(window.tick(92000), 0);
    expect(window.tick(200000), 0);
    window.foreground = true;
    window.input(200000);
    expect(window.tick(201000), 1);
    // Throttled timers cannot credit a long suspended interval.
    expect(window.tick(220000), 2);
  });
  test('time labels retain meaningful precision', () {
    expect(formatProjectTime(0), '0 min');
    expect(formatProjectTime(35), '<1 min');
    expect(formatProjectTime(125), '2 min');
    expect(formatProjectTime(3660), '1 hr 1 min');
    expect(formatProjectTime(7200), '2 hrs');
  });
}
