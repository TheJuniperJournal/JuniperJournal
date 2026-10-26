part of 'project_development_flow.dart';

const _readingPaper = Color(0xFFFCFCF8);
const _readingInk = Color(0xFF293D31);
const _readingMuted = Color(0xFF6B756F);
const _readingGreen = Color(0xFF4D9865);
const _readingLine = Color(0xFFDCE6DC);
const _readingBody = TextStyle(
  fontFamily: 'Inter',
  fontSize: 16,
  height: 1.65,
  color: _readingInk,
);
const _readingLabel = TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
  height: 1.5,
  fontWeight: FontWeight.w600,
  color: _readingInk,
);
const _readingHelp = TextStyle(
  fontFamily: 'Inter',
  fontSize: 13,
  height: 1.6,
  color: _readingMuted,
);

/// The production reader uses saved journal data, never the design-review fixtures.
class JournalReadingPage extends StatefulWidget {
  const JournalReadingPage({super.key, required this.entry, this.projectsRepo});
  final JournalEntry entry;
  final ProjectsRepo? projectsRepo;
  @override
  State<JournalReadingPage> createState() => _JournalReadingPageState();
}

class _JournalReadingPageState extends State<JournalReadingPage> {
  late final ProjectsRepo _repo = widget.projectsRepo ?? ProjectsRepo();
  late final _IdeatingPreviewData? _ideas =
      normalizePhase(widget.entry.progress) == 'ideating'
      ? _IdeatingPreviewData.fromEntry(widget.entry)
      : null;
  late final Future<List<ImpactEntry>?> _impacts =
      normalizePhase(widget.entry.progress) == 'implementation'
      ? _repo.getImpactEntries(projectId: widget.entry.projectId)
      : Future.value(const []);
  bool get _canvas =>
      widget.entry.isFreeNotes ||
      (widget.entry.content.whereType<Map>().any(
            (row) => const [
              'header',
              'body',
              'image',
              'table',
              'math',
            ].contains(row['type']),
          ) &&
          !widget.entry.content.whereType<Map>().any(
            (row) => const [
              'observations',
              'observation',
              'analyze',
              'question',
              'challenge',
              'ideas',
              'prototyping',
              'overview',
            ].contains(row['stage']),
          ));
  String get _type => _canvas
      ? 'Free Notes'
      : widget.entry.prototypingTypeLabel ??
            switch (normalizePhase(widget.entry.progress)) {
              'discover' => 'Discovery',
              'ideating' => 'Ideation',
              'implementation' => 'Implementation',
              _ => 'Prototyping',
            };
  @override
  void dispose() {
    _ideas?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: PageScrollWithFooter(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        ContentAlignedBackButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        JournalEntryMenu(entry: widget.entry, repo: _repo),
                        IconButton(
                          tooltip: 'Close preview',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => Container(
                      key: const ValueKey('journal-reading-paper'),
                      color: _readingPaper,
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth < 500 ? 24 : 44,
                        36,
                        constraints.maxWidth < 500 ? 24 : 44,
                        40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_type.toUpperCase()}${_canvas ? '' : ' · GUIDED JOURNAL'}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              letterSpacing: 1.2,
                              color: _readingGreen,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.entry.title,
                            key: const ValueKey('journal-reading-title'),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 30,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.9,
                              color: _readingInk,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (widget.entry.createdAt != null ||
                              widget.entry.authorDisplayName?.isNotEmpty ==
                                  true)
                            Text(
                              [
                                if (widget.entry.createdAt != null)
                                  DateFormat(
                                    'MMMM d, yyyy',
                                  ).format(widget.entry.createdAt!.toLocal()),
                                if (widget
                                        .entry
                                        .authorDisplayName
                                        ?.isNotEmpty ==
                                    true)
                                  widget.entry.authorDisplayName!,
                              ].join(' · '),
                              style: _readingHelp.copyWith(fontSize: 12),
                            ),
                          if (_canvas) ...[
                            const SizedBox(height: 28),
                            JournalEntryEditorScreen(
                              projectId: widget.entry.projectId,
                              projectName: '',
                              tags: const [],
                              entryId: widget.entry.id,
                              initialTitle: widget.entry.title,
                              initialContent: widget.entry.content,
                              initialProgress: widget.entry.progress,
                              readOnly: true,
                              freeNotes: true,
                              canvasOnly: true,
                              projectsRepo: _repo,
                            ),
                          ] else ...[
                            for (final stage
                                in widget.entry.content.whereType<Map>())
                              ..._stage(stage),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _stage(Map stage) {
    final key = stage['stage'];
    final children = <Widget>[];
    void fields(Map<String, String> mapping) {
      for (final field in mapping.entries) {
        final raw = _readingText(stage[field.key]);
        final date = field.key == 'dateImplemented'
            ? DateTime.tryParse(raw)
            : null;
        final value = date == null
            ? raw
            : DateFormat('MMMM d, yyyy').format(date);
        if (value.isNotEmpty) children.add(_ReadingField(field.value, value));
      }
    }

    switch (key) {
      case 'observations':
      case 'observation':
        fields({
          'title': 'Discovery Title',
          'observed': 'What was observed?',
          'location': 'Location',
          'known': 'What is already known?',
          'affectedCommunities': 'Who is affected?',
        });
        children.addAll(_peopleAndEvidence(stage));
        return [_ReadingSection('Observe', children)];
      case 'analyze':
        for (final cause in _maps(stage['rootCauses'])) {
          children.add(
            _ReadingItem(
              title: _readingText(cause['title']),
              icon: SvgPicture.asset(
                'assets/project_setup/root_cause.svg',
                width: 24,
                height: 24,
              ),
              children: [
                if (_readingText(cause['description']) !=
                    _readingText(cause['title']))
                  _ReadingField(
                    'Description',
                    _readingText(cause['description']),
                  ),
                _ReadingField(
                  'Why do you think this occurs?',
                  _readingText(cause['reason']),
                ),
                ..._readingEvidence(cause['evidence']),
              ],
            ),
          );
        }
        fields({
          'patternChange': 'Pattern Changes',
          'patternExplanation': 'Why was this pattern selected?',
        });
        return [_ReadingSection('Analyze', children)];
      case 'question':
        for (final question in _maps(stage['questions'])) {
          children.add(
            _ReadingQuestion(
              _readingText(question['type']),
              _readingText(question['text']),
            ),
          );
        }
        return [_ReadingSection('Question', children)];
      case 'challenge':
        fields({'title': 'Challenge Title', 'problem': 'The challenge'});
        final objectives = _readingList(stage['objectives']);
        if (objectives.isNotEmpty)
          children.add(
            _ReadingList('Goals for the ideas', objectives, numbered: true),
          );
        final supporting = stage['supportingContext'];
        if (supporting is Map &&
            _readingText(
              supporting['name'] ?? supporting['fileName'],
            ).isNotEmpty)
          children.add(_ReadingAttachment(supporting));
        children.addAll(_peopleAndEvidence(stage));
        return [_ReadingSection('Challenge', children)];
      case 'ideas':
        for (final idea in _maps(stage['items'])) {
          children.add(
            _ReadingItem(
              title: _readingText(idea['title']),
              icon: SvgPicture.asset(
                'assets/prototyping/idea_bulb.svg',
                width: 24,
                height: 24,
              ),
              children: [
                _ReadingField(
                  'Description',
                  [
                    _readingText(idea['description']),
                    _readingText(idea['rationale']),
                  ].where((v) => v.isNotEmpty).join(' '),
                ),
                _ReadingField(
                  'What makes it promising',
                  _readingText(idea['strengths']),
                ),
                _ReadingField(
                  'What needs more thought',
                  _readingText(idea['challenges']),
                ),
                ..._readingEvidence(idea['evidence']),
              ],
            ),
          );
        }
        return [_ReadingSection('Ideas', children)];
      case 'decisionMatrix':
        if (_ideas == null || _ideas!.ideas.isEmpty) return [];
        final data = _ideas!;
        return [
          _ReadingSection('Decision Matrix', [
            const Text(
              'Ideas are rated from 1–5 against weighted criteria, with total scores out of 100.',
              style: _readingHelp,
            ),
            const SizedBox(height: 12),
            _ReadingTable(
              ['Criteria', ...data.ideas.map((i) => i.title.text)],
              [
                for (final c in data.criteria)
                  [
                    '${c.name.text} · ${c.weight.text}%',
                    ...data.ideas.map(
                      (i) => c.ratingFor(i.id)?.toString() ?? '—',
                    ),
                  ],
                [
                  'Total score / 100',
                  ...data.ideas.map((i) => _formatIdeaScore(data.scores[i.id])),
                ],
              ],
            ),
          ]),
        ];
      case 'prototyping':
        return _prototype(stage);
      case 'overview':
        fields({
          'summary': 'Summary',
          'dateImplemented': 'Implementation Date',
          'location': 'Location',
        });
        children.addAll(_peopleAndEvidence(stage));
        return [_ReadingSection('Overview', children)];
      case 'assessment':
        return [
          FutureBuilder<List<ImpactEntry>?>(
            future: _impacts,
            builder: (context, snapshot) {
              final impacts = (snapshot.data ?? const <ImpactEntry>[])
                  .where((i) => i.linkedJournalEntryId == widget.entry.id)
                  .toList();
              if (snapshot.connectionState != ConnectionState.done)
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: LinearProgressIndicator(),
                );
              if (impacts.isEmpty) return const SizedBox.shrink();
              return _ReadingSection('Assessment', [
                for (final impact in impacts) _ReadingImpact(impact),
              ]);
            },
          ),
        ];
      case 'learning':
        return [_readingLearning(stage)];
      case 'nextAction':
        fields({
          'learned': 'What I learned',
          'challenges': 'Questions still open',
          'nextSteps': 'What I’ll try next',
          'notes': 'Further notes',
        });
        if (stage['createdTimelineEvent'] is Map)
          children.add(_ReadingTimeline(stage['createdTimelineEvent'] as Map));
        return [_ReadingSection('Next Action', children)];
      case 'reflection':
        fields({
          'workedWell': 'What worked well?',
          'didntWork': 'What didn’t work well?',
          'keyTakeaways': 'Key Takeaways',
          'change': 'What would you change?',
        });
        if (stage['createdTimelineEvent'] is Map)
          children.add(_ReadingTimeline(stage['createdTimelineEvent'] as Map));
        return [_ReadingSection('Reflection', children)];
      default:
        return [];
    }
  }

  List<Widget> _peopleAndEvidence(Map stage) => [
    if (_maps(stage['involved']).isNotEmpty)
      JournalInvolvedPeoplePreview(
        people: _maps(stage['involved']),
        readingStyle: true,
      ),
    ..._readingEvidence(stage['evidence']),
  ];

  List<Widget> _prototype(Map stage) {
    final type = _PrototypeEntryType.parse(stage['entryType']?.toString());
    if (type == null) return _legacyPrototype(stage);
    final draft = _PrototypeJournalDraft(type, widget.entry);
    final data = draft.data;
    final components = _maps(data['selectedComponents']).isNotEmpty
        ? _maps(data['selectedComponents'])
        : [if (data['component'] is Map) data['component'] as Map];
    return [
      for (final c in components.take(1))
        _ReadingSection('Component', [
          _ReadingField('Name', _readingText(c['name'])),
          _ReadingField(
            'Purpose of the Component',
            _readingText(c['description']),
          ),
          if (_readingList(c['features']).isNotEmpty)
            _ReadingList('Key Features', _readingList(c['features'])),
        ]),
      _ReadingSection(
        type == _PrototypeEntryType.building
            ? 'Build'
            : type == _PrototypeEntryType.testing
            ? 'Test'
            : 'Technical Analysis',
        [
          for (final field in type.fields.where(
            (f) => f.$1 != 'feedback' && f.$1 != 'fieldNotes',
          ))
            _ReadingField(
              field.$2.replaceAll(' (Optional)', ''),
              _readingText(data[field.$1]),
            ),
          if (type == _PrototypeEntryType.analysis) ...[
            if (_readingList(data['dataSources']).isNotEmpty)
              _ReadingSources(_readingList(data['dataSources'])),
            _ReadingField(
              'Calculation Type',
              _readingText(data['calculationType']),
            ),
            _ReadingField(
              'Previously recorded method',
              _readingText(data['method']),
            ),
            _ReadingField(
              'Previously recorded interpretation',
              _readingText(data['interpretation']),
            ),
          ],
          _ReadingField('Outcomes & Rating', _readingText(data['outcome'])),
          if (type == _PrototypeEntryType.testing)
            _ReadingField('Feedback & Notes', _readingText(data['feedback'])),
          if (type == _PrototypeEntryType.analysis)
            _ReadingField('Field Notes', _readingText(data['fieldNotes'])),
          _ReadingField(
            'Previously recorded results',
            _readingText(data['results']),
          ),
          ..._peopleAndEvidence(data),
        ],
      ),
      if (_maps(data['materials']).isNotEmpty)
        _ReadingSection('Materials & Cost', [
          _ReadingTable(
            ['Item', 'Cost'],
            [
              for (final m in _maps(data['materials']))
                [
                  _readingText(m['name']),
                  '${data['materialsCurrency'] ?? 'USD'} ${m['cost'] ?? ''}',
                ],
            ],
          ),
          _ReadingField(
            'Total spent',
            '${data['materialsCurrency'] ?? 'USD'} ${_maps(data['materials']).fold<double>(0, (sum, m) => sum + (double.tryParse('${m['cost']}') ?? 0)).toStringAsFixed(2)}',
          ),
        ]),
    ];
  }

  List<Widget> _legacyPrototype(Map stage) => [
    for (final iteration in _maps(stage['iterations']))
      _ReadingSection(
        _readingText(iteration['title']).isEmpty
            ? 'Iteration'
            : _readingText(iteration['title']),
        [
          _ReadingField('Goal', _readingText(iteration['goal'])),
          _ReadingField('Notes', _readingText(iteration['notes'])),
          for (final c in _maps(iteration['components']))
            _ReadingItem(
              title: _readingText(c['name']),
              children: [
                _ReadingField(
                  'Purpose of the Component',
                  _readingText(c['description']),
                ),
                if (_readingList(c['features']).isNotEmpty)
                  _ReadingList('Key Features', _readingList(c['features'])),
                for (final log in _maps(c['buildLogs']))
                  _ReadingItem(
                    title: _readingText(log['title']),
                    children: [
                      _ReadingField(
                        'Build Process',
                        _readingText(log['summary']),
                      ),
                      _ReadingField(
                        'Challenges',
                        _readingText(log['challenges']),
                      ),
                      ..._readingEvidence(log['evidence']),
                      if (log['learning'] is Map)
                        _readingLearning(log['learning'] as Map),
                      if (log['nextAction'] is Map)
                        ..._stage({
                          ...log['nextAction'] as Map,
                          'stage': 'nextAction',
                        }),
                    ],
                  ),
                for (final test in _maps(c['testEntries']))
                  _ReadingItem(
                    title: _readingText(test['title']),
                    children: [
                      for (final field in const {
                        'objective': 'Objective',
                        'method': 'Method',
                        'expectedOutcome': 'Expected Outcome',
                        'outcome': 'Outcomes & Rating',
                        'feedback': 'Feedback & Notes',
                      }.entries)
                        _ReadingField(
                          field.value,
                          _readingText(test[field.key]),
                        ),
                      ..._readingEvidence(test['evidence']),
                      if (test['learning'] is Map)
                        _readingLearning(test['learning'] as Map),
                      if (test['nextAction'] is Map)
                        ..._stage({
                          ...test['nextAction'] as Map,
                          'stage': 'nextAction',
                        }),
                    ],
                  ),
              ],
            ),
          if (iteration['learning'] is Map)
            _readingLearning(iteration['learning'] as Map),
          if (iteration['nextAction'] is Map)
            ..._stage({
              ...iteration['nextAction'] as Map,
              'stage': 'nextAction',
            }),
        ],
      ),
  ];
}

String _readingText(dynamic value) {
  if (value == null) return '';
  if (value is List) return _readingList(value).join('\n');
  if (value is Map)
    return _readingText(
      value['text'] ?? value['label'] ?? value['name'] ?? value['title'],
    );
  return value.toString().trim();
}

List<String> _readingList(dynamic value) => value is List
    ? value.map(_readingText).where((s) => s.isNotEmpty).toList()
    : [];

const _readingDescriptions = {
  'Observe':
      'What is happening in the project’s surroundings, and where might there be an opportunity for a more sustainable approach?',
  'Analyze':
      'Possible root causes and patterns help explain the observations and identify what to investigate before deciding what to change.',
  'Question':
      'These questions guide the next investigation into the sustainability challenge.',
  'Component':
      'The part of the project being developed or examined in this entry.',
  'Build':
      'How the proposed solution takes shape, including the choices made as materials and ideas meet practical constraints.',
  'Test':
      'What happens when the design is tried, and how the results compare with what it was intended to do.',
  'Technical Analysis':
      'A closer look at the evidence behind the proposed change and what it suggests about the project’s performance or resource use.',
  'Overview':
      'How the sustainability project was put into practice, including the setting and people involved.',
  'Assessment':
      'What the available evidence suggests about the project’s impact, and how confidently that impact can be understood.',
  'Reflection':
      'What the implementation revealed about the approach and what could improve next time.',
  'Materials & Cost':
      'The materials and spending involved in bringing this version of the solution to life.',
  'Challenge':
      'The sustainability challenge this entry responds to and what a useful improvement would achieve.',
  'Ideas':
      'Different ways the project could address the challenge, with the benefits and limitations of each approach.',
  'Decision Matrix':
      'How the ideas compare against the priorities that matter for this project.',
  'Learning':
      'The ideas and ways of thinking developed through this work on the sustainability project.',
  'Next Action':
      'What this experience suggests trying next to move the sustainability project forward.',
};

class _ReadingSection extends StatelessWidget {
  const _ReadingSection(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final visible = children
        .where(
          (child) => child is! _ReadingField || child.value.trim().isNotEmpty,
        )
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.only(top: 26),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _readingLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 23,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: _readingGreen,
            ),
          ),
          if (_readingDescriptions[title] case final description?)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Text(description, style: _readingHelp),
            )
          else
            const SizedBox(height: 24),
          ...visible,
        ],
      ),
    );
  }
}

class _ReadingField extends StatelessWidget {
  const _ReadingField(this.label, this.value, {this.icon, this.description});
  final String label, value;
  final Widget? icon;
  final String? description;
  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    Widget? selectedIcon = icon;
    String? help = description;
    if (label == 'Outcomes & Rating') {
      selectedIcon = Icon(
        switch (value) {
          'Unsuccessful' => Icons.link_off_outlined,
          'Needs Revision' => Icons.local_fire_department_outlined,
          'Promising' => Icons.remove_circle_outline,
          'Validated' => Icons.science_outlined,
          _ => Icons.verified_user_outlined,
        },
        color: _devGreen,
        size: 24,
      );
      help = _prototypeTestOutcomes.where((o) => o[0] == value).firstOrNull?[1];
    } else if (label == 'Calculation Type') {
      selectedIcon = Icon(
        switch (value) {
          'Performance' => Icons.speed_outlined,
          'Comparison' => Icons.balance_outlined,
          'Estimate' => Icons.bar_chart_outlined,
          _ => Icons.paid_outlined,
        },
        color: _devGreen,
        size: 24,
      );
      help = switch (value) {
        'Performance' => 'Evaluate how well a design or system performs.',
        'Comparison' =>
          'Compare alternatives or existing and proposed conditions.',
        'Estimate' => 'Estimate a quantity using available information.',
        _ => 'Examine costs and the value of an option.',
      };
    } else if (label == 'Pattern Changes') {
      final option = _patternChangeOptions
          .where((o) => o.label == value)
          .firstOrNull;
      if (option != null) {
        selectedIcon = SizedBox(
          width: 24,
          height: 24,
          child: _StackedSvgIcon(assets: option.assets),
        );
        help = option.description;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _readingLabel),
          const SizedBox(height: 6),
          if (selectedIcon != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 24, height: 26, child: selectedIcon),
                const SizedBox(width: 10),
                Expanded(child: Text(value, style: _readingBody)),
              ],
            )
          else
            Text(value, style: _readingBody),
          if (help?.isNotEmpty == true)
            Padding(
              padding: EdgeInsets.only(
                top: 6,
                left: selectedIcon == null ? 0 : 34,
              ),
              child: Text(help!, style: _readingHelp),
            ),
        ],
      ),
    );
  }
}

class _ReadingList extends StatelessWidget {
  const _ReadingList(this.label, this.items, {this.numbered = false});
  final String label;
  final List<String> items;
  final bool numbered;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _readingLabel),
        const SizedBox(height: 6),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(numbered ? '${i + 1}. ' : '• ', style: _readingBody),
                Expanded(child: Text(items[i], style: _readingBody)),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ReadingItem extends StatelessWidget {
  const _ReadingItem({required this.title, required this.children, this.icon});
  final String title;
  final List<Widget> children;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.only(left: 20),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: _readingLine, width: 2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                title,
                style: _readingBody.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _ReadingQuestion extends StatelessWidget {
  const _ReadingQuestion(this.type, this.text);
  final String type, text;
  @override
  Widget build(BuildContext context) {
    final option = _questionTypeOptions
        .where((o) => o.label == type)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (option != null) ...[
                SizedBox(
                  width: 24,
                  height: 24,
                  child: _StackedSvgIcon(assets: option.assets),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                type,
                style: _readingLabel.copyWith(
                  color: option?.color ?? _readingInk,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 6),
            child: Text(text, style: _readingBody),
          ),
        ],
      ),
    );
  }
}

Widget _readingLearning(Map stage) {
  final lens = InquiryLensConfig.byValue(
    InquiryLensData.fromJson(
      stage['inquiryLensData'],
      legacyLens: _readingText(stage['inquiryLens']),
    ).selectedLens,
  );
  final dimensions = [
    ('DCI', 'Disciplinary Core Ideas', 'dci'),
    ('SEP', 'Science and Engineering Practices', 'sep'),
    ('CCCs', 'Crosscutting Concepts', 'ccc'),
  ];
  final selected = dimensions
      .where((d) => _readingList(stage[d.$3]).isNotEmpty)
      .toList();
  if (lens == null && selected.isEmpty) return const SizedBox.shrink();
  return _ReadingSection('Learning', [
    if (lens != null)
      _ReadingField(
        'Learning lens',
        lens.value,
        icon: SvgPicture.asset(lens.iconAsset, width: 24, height: 24),
        description: lens.description,
      ),
    if (selected.isNotEmpty) ...[
      const SizedBox(height: 8),
      const Text('Learning connections', style: _readingLabel),
      for (final d in selected)
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                'assets/learning_module/summary_${d.$3}.svg',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.$2, style: _readingLabel),
                    const SizedBox(height: 4),
                    Text(_learningDimensionContext(d.$1), style: _readingHelp),
                    const SizedBox(height: 10),
                    for (final value in _readingList(stage[d.$3]))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(value, style: _readingBody),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  ]);
}

class _ReadingSources extends StatelessWidget {
  const _ReadingSources(this.sources);
  final List<String> sources;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data Source', style: _readingLabel),
        const SizedBox(height: 6),
        const Text(
          'The information used to support this technical analysis.',
          style: _readingHelp,
        ),
        const SizedBox(height: 8),
        for (final source in sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(_analysisSourceIcon(source), color: _devGreen, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text(source, style: _readingBody)),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ReadingTimeline extends StatelessWidget {
  const _ReadingTimeline(this.event);
  final Map event;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border.all(color: _readingLine),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timeline, color: _devGreen, size: 24),
            SizedBox(width: 10),
            Text('Timeline event', style: _readingLabel),
          ],
        ),
        const SizedBox(height: 16),
        _ReadingField('Event', _readingText(event['name'] ?? event['event'])),
        _ReadingField(
          'Visibility',
          event['visibility'] == 'public' ? 'Public' : 'Project members only',
        ),
        _ReadingField(
          'Date',
          _readingText(event['startDate'] ?? event['date']),
        ),
        _ReadingField(
          'Time',
          [
            _readingText(event['startTime'] ?? event['time']),
            _readingText(event['endTime']),
          ].where((v) => v.isNotEmpty).join(' – '),
        ),
        _ReadingField(
          'Assigned to',
          _readingText(event['assigneeNames']).replaceAll('|', '\n'),
        ),
        _ReadingField('Location', _readingText(event['location'])),
        _ReadingField('Description', _readingText(event['description'])),
      ],
    ),
  );
}

class _ReadingImpact extends StatelessWidget {
  const _ReadingImpact(this.impact);
  final ImpactEntry impact;
  @override
  Widget build(BuildContext context) {
    Widget svg(String path) => SvgPicture.asset(path, width: 24, height: 24);
    final metric = switch (impact.metric) {
      'Biological Growth' => (
        'bio',
        'Measures ecological growth and restoration',
      ),
      'Education' => ('education', 'Measures learning and knowledge outcomes'),
      'Energy' => ('energy', 'Measures energy use and consumption'),
      'Waste' => ('waste', 'Measures waste diverted and generated'),
      _ => ('water', 'Measures water use and consumption'),
    };
    final pattern = switch (impact.patternType) {
      'Behavior Change' => 'behavior',
      'Capacity Building' => 'capacity',
      _ => impact.patternType.toLowerCase(),
    };
    final description = switch (impact.patternType) {
      'Reduction' =>
        'Use fewer resources or create less waste. For example, reduce water use or food waste.',
      'Substitution' =>
        'Replace a material or process with a lower-impact alternative. For example, use reusable containers instead of disposables.',
      'Regeneration' =>
        'Restore or renew natural systems. For example, improve soil health or plant native habitat.',
      'Behavior Change' =>
        'Help people adopt more sustainable habits. For example, encourage regular composting or switching off unused lights.',
      'Capacity Building' =>
        'Build the skills, tools, or support people need to keep making progress. For example, teach composting skills or provide shared equipment.',
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadingField('Impact Title', impact.title),
        _ReadingField(
          'Metric',
          impact.metric,
          icon: svg('assets/project_setup/impact_${metric.$1}.svg'),
          description: metric.$2,
        ),
        _ReadingField(
          'Pattern Type',
          impact.patternType,
          icon: svg('assets/project_setup/pattern_$pattern.svg'),
          description: description,
        ),
        _ReadingField(
          'Impact Scale',
          impact.impactScale,
          description:
              'The estimated size of the project’s impact, ranging from Seed (very small) to Watershed (very large).',
          icon: svg(
            'assets/impact/scale_${impact.impactScale.split(' ').first.toLowerCase()}.svg',
          ),
        ),
        if (impact.measurement != null)
          _ReadingField('Measurement', impact.measurementDisplay),
        _ReadingField('Evidence Type', impact.evidenceType),
        _ReadingField('Confidence Score', impact.confidenceScore),
      ],
    );
  }
}

class _ReadingTable extends StatelessWidget {
  const _ReadingTable(this.headers, this.rows);
  final List<String> headers;
  final List<List<String>> rows;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: c.maxWidth),
        child: DataTable(
          headingTextStyle: _readingLabel,
          dataTextStyle: _readingBody,
          columnSpacing: 32,
          horizontalMargin: 16,
          headingRowHeight: 56,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 100,
          dividerThickness: 1,
          columns: [for (final h in headers) DataColumn(label: Text(h))],
          rows: [
            for (final row in rows)
              DataRow(cells: [for (final value in row) DataCell(Text(value))]),
          ],
        ),
      ),
    ),
  );
}

class _ReadingAttachment extends StatelessWidget {
  const _ReadingAttachment(this.file);
  final Map file;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Supporting Context', style: _readingLabel),
        TextButton.icon(
          onPressed: () async {
            try {
              final bucket = _readingText(file['bucket']);
              final url = bucket.isEmpty || bucket == 'images'
                  ? _readingText(file['url'] ?? file['publicUrl'])
                  : await StorageService().createSignedUrl(
                      _readingText(file['path']),
                      bucketName: bucket,
                    );
              if (context.mounted) await _openEvidenceUrl(context, url);
            } catch (_) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This attachment is unavailable or you do not have access.',
                    ),
                  ),
                );
            }
          },
          icon: const Icon(Icons.attach_file, size: 20),
          label: Text(
            _readingText(file['name'] ?? file['fileName']),
            style: _readingBody,
          ),
        ),
      ],
    ),
  );
}

List<Widget> _readingEvidence(dynamic blocks) => [
  for (final item in _maps(blocks))
    if (_EvidenceBlock.fromMap(item) case final block?) _ReadingEvidence(block),
];

class _ReadingEvidence extends StatelessWidget {
  const _ReadingEvidence(this.block);
  final _EvidenceBlock block;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(block.iconAsset, width: 24, height: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(block.title, style: _readingLabel)),
          ],
        ),
        const SizedBox(height: 12),
        switch (block.type) {
          'Images' => Column(
            children: [
              for (final image in _maps(block.data['images']))
                _ReadingImage(image),
            ],
          ),
          'Sketch' => SketchEvidencePreview(data: block.sketchData!),
          'Graph' => GraphEvidencePreview(data: block.graphData!),
          'Table' => _TableEvidencePreview(data: block.tableData!),
          'Video' => _VideoEvidencePreview(data: block.videoData!),
          'Link' => TextButton.icon(
            onPressed: () =>
                _openEvidenceUrl(context, _readingText(block.data['url'])),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open reference'),
          ),
          _ => Text(
            _readingText(block.data['text'] ?? block.data['body']),
            style: _readingBody,
          ),
        },
        if (_readingText(
          block.data['caption'] ?? block.data['description'],
        ).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _readingText(block.data['caption'] ?? block.data['description']),
              style: _readingHelp,
            ),
          ),
      ],
    ),
  );
}

class _ReadingImage extends StatefulWidget {
  const _ReadingImage(this.image);
  final Map image;
  @override
  State<_ReadingImage> createState() => _ReadingImageState();
}

class _ReadingImageState extends State<_ReadingImage> {
  late final Future<String> _source = resolveEvidenceMediaUrl(
    widget.image,
    bucket: 'images',
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _source,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        );
      if (snapshot.hasError || snapshot.data?.isNotEmpty != true)
        return const Text('Image unavailable.', style: _readingHelp);
      final source = snapshot.data!;
      Widget image() => ProtectedImage.network(
        source,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Text('Image unavailable.', style: _readingHelp),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Enlarge image',
            child: AppTapTarget(
              onTap: () => showAppDialog<void>(
                context: context,
                builder: (context) => Dialog(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: InteractiveViewer(child: image()),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          tooltip: 'Close image',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: image(),
                ),
              ),
            ),
          ),
          if (_readingText(widget.image['description']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: Text(
                _readingText(widget.image['description']),
                style: _readingHelp,
              ),
            ),
        ],
      );
    },
  );
}
