import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/repositories/challenges_repo.dart';
import 'package:juniper_journal/src/features/community/pages/challenge_creator_dashboard.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

const _kMetrics = [
  'Energy',
  'Waste',
  'Water',
  'Biological Growth',
  'Educational Impact',
];
const _kPatterns = ['Behavior', 'Regeneration', 'Reduction', 'Substitution'];
const _kCommunityPatterns = ['Capacity Building'];

class ChallengeRequirementsForm extends StatefulWidget {
  final String communityId;
  final String type;
  final String name;
  final String? prompt;
  final String? imageUrl;
  final String? scale;
  final String? difficulty;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool allDay;

  const ChallengeRequirementsForm({
    super.key,
    required this.communityId,
    required this.type,
    required this.name,
    this.prompt,
    this.imageUrl,
    this.scale,
    this.difficulty,
    this.startsAt,
    this.endsAt,
    this.allDay = false,
  });

  @override
  State<ChallengeRequirementsForm> createState() =>
      _ChallengeRequirementsFormState();
}

class _ChallengeRequirementsFormState extends State<ChallengeRequirementsForm> {
  final _repo = ChallengesRepo();
  final _linkCtrl = TextEditingController();

  int _journalEntries = 0;
  bool _measurementRequired = false;
  Set<String> _selectedMetrics = {};
  Set<String> _selectedPatterns = {};
  int _minGroupMembers = 1;
  bool _saving = false;

  bool get _isPatternChange => widget.type == 'pattern_change';
  bool get _isCommunityImpact => widget.type == 'community_impact';

  List<String> get _patternOptions =>
      _isCommunityImpact ? _kCommunityPatterns : _kPatterns;

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmExit() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit Challenge Creation?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(); // requirements
      Navigator.of(context).pop(); // setup
      Navigator.of(context).pop(); // type picker
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    // 1. Create the challenge record
    final challenge = await _repo.createChallenge(
      communityId: widget.communityId,
      type: widget.type,
      name: widget.name,
      prompt: widget.prompt,
      imageUrl: widget.imageUrl,
      scale: widget.scale,
      difficulty: widget.difficulty,
      startsAt: widget.startsAt,
      endsAt: widget.endsAt,
      allDay: widget.allDay,
    );

    if (challenge == null) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTopSnackBar(context, 'Failed to create challenge. Please try again.');
      return;
    }

    // 2. Save requirements
    await _repo.updateRequirements(
      id: challenge.id,
      requiredJournalEntries: _journalEntries,
      measurementRequired: _measurementRequired,
      requiredMetrics: _selectedMetrics.toList(),
      requiredPatterns: _selectedPatterns.toList(),
      minGroupMembers: _minGroupMembers,
      externalLink: _linkCtrl.text.trim().isEmpty
          ? null
          : _linkCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    // Replace entire creation stack with dashboard
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ChallengeCreatorDashboard(challengeId: challenge.id),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            size: 28,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Set Requirements', style: AppTypography.pageTitle),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 22,
              color: AppColors.textSecondary,
            ),
            onPressed: _confirmExit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Journal entries stepper
            _rowField(
              'Required Journal Entries',
              Row(
                children: [
                  _stepperBtn(
                    Icons.remove,
                    () => setState(
                      () =>
                          _journalEntries = (_journalEntries - 1).clamp(0, 99),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_journalEntries',
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _stepperBtn(
                    Icons.add,
                    () => setState(
                      () =>
                          _journalEntries = (_journalEntries + 1).clamp(0, 99),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            // Measurement required toggle
            _rowField(
              'Measurement Required',
              Switch(
                value: _measurementRequired,
                onChanged: (v) => setState(() => _measurementRequired = v),
                activeColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            // Community Impact: min group members
            if (_isCommunityImpact) ...[
              _rowField(
                'Minimum Group Members Required',
                Row(
                  children: [
                    _stepperBtn(
                      Icons.remove,
                      () => setState(
                        () => _minGroupMembers = (_minGroupMembers - 1).clamp(
                          1,
                          50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_minGroupMembers',
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _stepperBtn(
                      Icons.add,
                      () => setState(
                        () => _minGroupMembers = (_minGroupMembers + 1).clamp(
                          1,
                          50,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
            ],

            // Required metrics
            _sectionLabel('Required Metrics (Multi-Select)'),
            const SizedBox(height: 10),
            _pillGrid(_kMetrics, _selectedMetrics),
            const SizedBox(height: AppMetrics.fieldGap),

            // Required pattern (Pattern Change → select 1; Community Impact → select from list)
            if (_isPatternChange) ...[
              _sectionLabel('Required Pattern (Select 1)'),
              const SizedBox(height: 10),
              _pillGrid(_patternOptions, _selectedPatterns, maxSelect: 1),
              const SizedBox(height: AppMetrics.fieldGap),
            ] else if (_isCommunityImpact) ...[
              _sectionLabel('Required Patterns'),
              const SizedBox(height: 10),
              _pillGrid(_patternOptions, _selectedPatterns),
              const SizedBox(height: AppMetrics.fieldGap),
            ],

            // External link
            Row(
              children: [
                _sectionLabel('Insert External Link'),
                const SizedBox(width: 8),
                const Icon(
                  Icons.link,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _linkCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '',
                hintStyle: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.hintText,
                  fontSize: AppTypography.bodySize,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.borderLight,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppMetrics.journalSectionGap),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.buttonSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowField(String label, Widget trailing) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      trailing,
    ],
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
  );

  Widget _stepperBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary),
      ),
      child: Icon(icon, size: 16, color: AppColors.primary),
    ),
  );

  Widget _pillGrid(
    List<String> options,
    Set<String> selected, {
    int? maxSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSelected = selected.contains(o);
        return GestureDetector(
          onTap: () => setState(() {
            if (isSelected) {
              selected.remove(o);
            } else {
              if (maxSelect != null && selected.length >= maxSelect) {
                selected.clear();
              }
              selected.add(o);
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.borderLight,
              ),
            ),
            child: Text(
              o.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
