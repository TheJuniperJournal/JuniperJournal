import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/draft_autosave.dart';

class DraftHarness extends StatefulWidget {
  const DraftHarness({super.key});
  @override
  State<DraftHarness> createState() => DraftHarnessState();
}

class DraftHarnessState extends State<DraftHarness>
    with DraftAutosave<DraftHarness> {
  String text = '';
  bool includeTimestamp = false;
  int timestamp = 0;
  final writes = <String>[];
  Completer<bool>? pending;
  bool succeed = true;
  bool throwError = false;
  @override
  String get draftFingerprint => includeTimestamp
      ? jsonEncode({
          'text': text,
          'assessment': {'updated_at': timestamp++},
        })
      : text;
  @override
  Future<bool> writeAutosave() async {
    writes.add(text);
    if (throwError) throw StateError("Storage unavailable");
    return pending != null ? await pending!.future : succeed;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('a thrown write releases the save lock and can retry', (
    tester,
  ) async {
    final key = GlobalKey<DraftHarnessState>();
    await tester.pumpWidget(DraftHarness(key: key));
    final state = key.currentState!;
    state.text = 'Unsaved work';
    state.throwError = true;
    expect(await state.flushDraft(), false);
    expect(state.draftSaveStatus.value, contains('Could not save'));
    state.throwError = false;
    expect(await state.flushDraft(), true);
    expect(state.draftSaveStatus.value, 'Saved');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('serialization timestamps do not trigger repeated saves', (
    tester,
  ) async {
    final key = GlobalKey<DraftHarnessState>();
    await tester.pumpWidget(DraftHarness(key: key));
    final state = key.currentState!;
    state.includeTimestamp = true;
    state.text = 'assessment';
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 2100));
    expect(state.writes, ['assessment']);
    expect(state.draftSaveStatus.value, 'Saved');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('saves edits and does not rewrite unchanged drafts', (
    tester,
  ) async {
    final key = GlobalKey<DraftHarnessState>();
    await tester.pumpWidget(DraftHarness(key: key));
    key.currentState!.text = 'new text';
    await tester.pump(const Duration(milliseconds: 700));
    expect(key.currentState!.writes, ['new text']);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(key.currentState!.writes.length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('flush waits for in-flight write and persists later edits', (
    tester,
  ) async {
    final key = GlobalKey<DraftHarnessState>();
    await tester.pumpWidget(DraftHarness(key: key));
    final state = key.currentState!;
    final first = Completer<bool>();
    state.pending = first;
    state.text = 'first';
    await tester.pump(const Duration(milliseconds: 700));
    state.text = 'latest';
    final flush = state.flushDraft();
    expect(state.writes, ['first']);
    state.pending = null;
    first.complete(true);
    await tester.pump();
    expect(await flush, true);
    expect(state.writes, ['first', 'latest']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed saves retry rather than marking changes as saved', (
    tester,
  ) async {
    final key = GlobalKey<DraftHarnessState>();
    await tester.pumpWidget(DraftHarness(key: key));
    final state = key.currentState!;
    state.succeed = false;
    state.text = 'retry';
    await tester.pump(const Duration(milliseconds: 700));
    state.succeed = true;
    await tester.pump(const Duration(milliseconds: 700));
    expect(state.writes, ['retry', 'retry']);
    await tester.pump(const Duration(milliseconds: 700));
    expect(state.writes.length, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
