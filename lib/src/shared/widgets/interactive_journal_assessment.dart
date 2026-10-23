import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/learning_module/pages/assessment_block.dart';
import '../../backend/db/repositories/assessments_repo.dart';
import '../styling/app_typography.dart';

class InteractiveJournalAssessment extends StatefulWidget {
  const InteractiveJournalAssessment({
    super.key,
    required this.assessment,
    this.repo,
  });
  final AssessmentBlockData assessment;
  final AssessmentsRepo? repo;
  @override
  State<InteractiveJournalAssessment> createState() =>
      _InteractiveJournalAssessmentState();
}

class _InteractiveJournalAssessmentState
    extends State<InteractiveJournalAssessment> {
  late final _repo = widget.repo ?? AssessmentsRepo();
  final _text = TextEditingController();
  Map<String, dynamic> _answer = {};
  bool _loading = false, _busy = false, _author = false, _submitted = false;
  bool? _correct;
  String? _error;
  String _status = 'Not started';
  int _points = 0;
  Timer? _debounce;
  Future<void> _progressWrites = Future.value();

  void _persistProgress() {
    if (_author || _submitted || widget.assessment.assessmentId == null) return;
    final answer = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(_answer)) as Map,
    );
    _progressWrites = _progressWrites
        .then((_) async {
          await _repo.save(
            widget.assessment.assessmentId!,
            answer,
            submit: false,
          );
        })
        .catchError((Object error) {
          if (mounted)
            setState(
              () => _error =
                  'Could not save progress. Your answer is still here. Retry',
            );
        });
  }

  @override
  void initState() {
    super.initState();
    _author = widget.assessment.assessmentId == null;
    if (!_author) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.session(widget.assessment.assessmentId!);
      if (!mounted) return;
      _author = data['author_preview'] == true;
      final raw = data['response'];
      if (raw is Map) {
        _answer = Map<String, dynamic>.from(raw['answer'] as Map? ?? {});
        _text.text = _answer['value']?.toString() ?? '';
        _applyResponse(raw);
      }
    } catch (_) {
      if (mounted) _error = 'Could not load this assessment. Retry';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyResponse(Map raw) {
    _submitted = ['submitted', 'evaluated'].contains(raw['status']);
    _correct = raw['correct'] as bool?;
    _status = _submitted
        ? (_correct == null
              ? 'Submitted — awaiting review'
              : _correct!
              ? 'Evaluated — correct'
              : 'Evaluated — review your answer')
        : 'In progress';
  }

  void _changed() {
    setState(() {
      _error = null;
      _status = 'In progress';
    });
    _debounce?.cancel();
    if (!_author)
      _debounce = Timer(const Duration(milliseconds: 700), _persistProgress);
  }

  bool get _valid {
    final d = widget.assessment.data;
    switch (widget.assessment.type) {
      case AssessmentType.numeric:
        return double.tryParse(_answer['value']?.toString() ?? '')?.isFinite ==
            true;
      case AssessmentType.paragraph:
        return (_answer['value']?.toString().trim().isNotEmpty ?? false);
      case AssessmentType.multipleChoice:
        return d['allow_multiple'] == true
            ? (_answer['indices'] as List? ?? []).isNotEmpty
            : _answer['index'] is int;
      case AssessmentType.trueFalse:
        return (_answer['values'] as List? ?? []).length ==
                (d['questions'] as List? ?? []).length &&
            (_answer['values'] as List).every((v) => v is bool);
      case AssessmentType.matching:
        return (_answer['mapping'] as Map? ?? {}).length ==
            (d['top_items'] as List? ?? []).length;
      case null:
        return false;
    }
  }

  bool? _gradePreview() {
    final d = widget.assessment.data;
    switch (widget.assessment.type) {
      case AssessmentType.numeric:
        final value = double.tryParse('${_answer['value']}');
        final min = double.tryParse('${d['min_value']}');
        final max = double.tryParse('${d['max_value']}');
        return value != null &&
            min != null &&
            max != null &&
            value >= min &&
            value <= max;
      case AssessmentType.paragraph:
        return null;
      case AssessmentType.multipleChoice:
        if (d['allow_multiple'] == true) {
          final a = {..._answer['indices'] as List};
          final b = {...d['correct_indices'] as List? ?? []};
          return a.length == b.length && a.containsAll(b);
        }
        return _answer['index'] == d['correct_index'];
      case AssessmentType.trueFalse:
        final questions = d['questions'] as List;
        final answers = _answer['values'] as List;
        return List.generate(
          questions.length,
          (i) => answers[i] == questions[i]['correct_answer'],
        ).every((v) => v);
      case AssessmentType.matching:
        final mapping = _answer['mapping'] as Map;
        final correct = d['correct_mapping'] as Map? ?? {};
        return mapping.length == correct.length &&
            mapping.entries.every((v) => correct[v.key] == v.value);
      case null:
        return null;
    }
  }

  Future<void> _save(bool submit) async {
    if (_busy || _submitted) return;
    if (submit && !_valid) {
      setState(() => _error = 'Complete the response before submitting.');
      return;
    }
    _debounce?.cancel();
    setState(() => _busy = true);
    try {
      if (_author) {
        if (submit) {
          _correct = _gradePreview();
          _submitted = true;
          _status = _correct == null
              ? 'Preview submitted — written response is not automatically graded'
              : _correct!
              ? 'Preview evaluated — correct'
              : 'Preview evaluated — incorrect';
        }
      } else {
        await _progressWrites;
        final result = await _repo.save(
          widget.assessment.assessmentId!,
          _answer,
          submit: submit,
        );
        if (!mounted) return;
        _applyResponse(result['response'] as Map);
        _points = (result['points'] as num? ?? 0).toInt();
      }
    } catch (_) {
      if (mounted)
        _error =
            'Could not save the response. Your answer is still here. Retry';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    if (_debounce?.isActive == true) _persistProgress();
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!assessmentFeaturesEnabled) return const SizedBox.shrink();
    final assessment = widget.assessment;
    final type = assessment.type;
    if (type == null) return const SizedBox.shrink();
    final d = assessment.data;
    final options = (d['options'] as List? ?? [])
        .map((v) => v.toString())
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            d['allow_multiple'] == true ? 'Multiple Selection' : type.title,
            style: AppTypography.sectionTitle,
          ),
          if (_author)
            const Text(
              'Author preview — responses and EcoPoints are not saved.',
              style: AppTypography.helper,
            ),
          const SizedBox(height: 12),
          if (d['question'] != null)
            Text(d['question'].toString(), style: AppTypography.fieldLabel),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          IgnorePointer(
            ignoring: _submitted || _busy || _loading,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  if (type == AssessmentType.numeric ||
                      type == AssessmentType.paragraph)
                    TextField(
                      controller: _text,
                      readOnly: _submitted,
                      minLines:
                          type == AssessmentType.paragraph &&
                              d['response_length'] != 'short'
                          ? 5
                          : 1,
                      maxLines:
                          type == AssessmentType.paragraph &&
                              d['response_length'] != 'short'
                          ? null
                          : 1,
                      maxLength: type == AssessmentType.paragraph
                          ? (d['max_characters'] as num? ?? 10000).toInt()
                          : 80,
                      keyboardType: type == AssessmentType.numeric
                          ? const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            )
                          : TextInputType.multiline,
                      inputFormatters: type == AssessmentType.numeric
                          ? [
                              TextInputFormatter.withFunction(
                                (oldValue, newValue) =>
                                    RegExp(
                                      r'^-?\d*(\.\d*)?$',
                                    ).hasMatch(newValue.text)
                                    ? newValue
                                    : oldValue,
                              ),
                            ]
                          : null,
                      decoration: InputDecoration(
                        labelText: type == AssessmentType.numeric
                            ? 'Your numeric response'
                            : 'Your response',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        _answer = {'value': v};
                        _changed();
                      },
                    ),
                  if (type == AssessmentType.multipleChoice)
                    for (var i = 0; i < options.length; i++)
                      d['allow_multiple'] == true
                          ? CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(options[i]),
                              value: (_answer['indices'] as List? ?? [])
                                  .contains(i),
                              onChanged: (v) {
                                final selected = {
                                  ..._answer['indices'] as List? ?? [],
                                };
                                if (v == true)
                                  selected.add(i);
                                else
                                  selected.remove(i);
                                _answer = {'indices': selected.toList()};
                                _changed();
                              },
                            )
                          : RadioListTile<int>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(options[i]),
                              value: i,
                              groupValue: _answer['index'] as int?,
                              onChanged: (v) {
                                _answer = {'index': v};
                                _changed();
                              },
                            ),
                  if (type == AssessmentType.trueFalse)
                    for (
                      var i = 0;
                      i < (d['questions'] as List? ?? []).length;
                      i++
                    )
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text((d['questions'] as List)[i]['text'].toString()),
                          Wrap(
                            spacing: 12,
                            children: [
                              for (final value in [true, false])
                                ChoiceChip(
                                  label: Text(value ? 'True' : 'False'),
                                  selected:
                                      (_answer['values'] as List? ?? [])
                                              .length >
                                          i &&
                                      (_answer['values'] as List)[i] == value,
                                  onSelected: (_) {
                                    final answers = List<dynamic>.from(
                                      _answer['values'] as List? ??
                                          List.filled(
                                            (d['questions'] as List).length,
                                            null,
                                          ),
                                    );
                                    answers[i] = value;
                                    _answer = {'values': answers};
                                    _changed();
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                  if (type == AssessmentType.matching)
                    for (
                      var i = 0;
                      i < (d['top_items'] as List? ?? []).length;
                      i++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              (_answer['mapping'] as Map? ??
                                      {})[String.fromCharCode(65 + i)]
                                  as String?,
                          decoration: InputDecoration(
                            labelText: (d['top_items'] as List)[i].toString(),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final j in List.generate(
                              (d['bottom_items'] as List? ?? []).length,
                              (i) => i,
                            ).reversed)
                              DropdownMenuItem(
                                value: String.fromCharCode(65 + j),
                                child: Text(
                                  (d['bottom_items'] as List)[j].toString(),
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            _answer = {
                              'mapping': {
                                ..._answer['mapping'] as Map? ?? {},
                                String.fromCharCode(65 + i): v,
                              },
                            };
                            _changed();
                          },
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(_status, style: AppTypography.helper),
          if (_error != null)
            TextButton(
              onPressed: _error!.contains('load') ? _load : () => _save(true),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_points > 0)
            Text(
              '+$_points EcoPoints earned!',
              style: AppTypography.sectionTitle,
            ),
          if (!_submitted)
            FilledButton(
              onPressed: _busy || _loading ? null : () => _save(true),
              child: Text(_busy ? 'Saving…' : 'Submit Response'),
            ),
          if (_submitted && _author)
            TextButton(
              onPressed: () => setState(() {
                _submitted = false;
                _correct = null;
                _status = 'Not started';
              }),
              child: const Text('Try preview again'),
            ),
        ],
      ),
    );
  }
}
