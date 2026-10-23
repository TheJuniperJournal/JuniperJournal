import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/design_challenge.dart';
import 'package:juniper_journal/src/backend/db/repositories/challenges_repo.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class ChallengeFundingForm extends StatefulWidget {
  final DesignChallenge challenge;

  const ChallengeFundingForm({super.key, required this.challenge});

  @override
  State<ChallengeFundingForm> createState() => _ChallengeFundingFormState();
}

class _ChallengeFundingFormState extends State<ChallengeFundingForm> {
  final _repo = ChallengesRepo();
  final _newItemCtrl = TextEditingController();

  late double _budgetMin;
  late double _budgetMax;
  bool _noRestriction = false;
  late List<String> _materials;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _budgetMin = widget.challenge.budgetMin.toDouble();
    _budgetMax = widget.challenge.budgetMax?.toDouble() ?? 100.0;
    _noRestriction = widget.challenge.budgetMax == null;
    _materials = List.from(widget.challenge.materials);
  }

  @override
  void dispose() {
    _newItemCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await _repo.updateFundingAndMaterials(
      id: widget.challenge.id,
      budgetMin: _budgetMin.round(),
      budgetMax: _noRestriction ? null : _budgetMax.round(),
      materials: _materials,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      showTopSnackBar(context, 'Failed to save. Please try again.');
    }
  }

  String _budgetLabel() {
    if (_noRestriction) return 'No Restriction';
    final min = _budgetMin.round();
    final max = _budgetMax.round();
    if (min == max) return '\$$min';
    return '\$$min – \$$max';
  }

  Color _budgetColor() {
    if (_noRestriction) return AppColors.primary;
    final max = _budgetMax.round();
    if (max <= 25) return AppColors.primary;
    if (max <= 50) return Colors.orange;
    return Colors.red.shade700;
  }

  String _budgetTag() {
    if (_noRestriction) return 'NO BUDGET RESTRICTION';
    final max = _budgetMax.round();
    if (max <= 25) return 'LOW COST PROJECT';
    if (max <= 50) return 'MODERATE COST PROJECT';
    return 'HIGH COST PROJECT';
  }

  void _addMaterial() {
    final text = _newItemCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _materials.add(text));
    _newItemCtrl.clear();
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
        title: const Text(
          'Funding and Materials',
          style: AppTypography.pageTitle,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Budget circle indicator
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _budgetColor(), width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _budgetLabel(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTypography.sectionTitleSize,
                        fontWeight: FontWeight.w800,
                        color: _budgetColor(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Budget',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.helperSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            // Slider
            if (!_noRestriction) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '\$0',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.helperSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '\$100',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.helperSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              RangeSlider(
                values: RangeValues(
                  _budgetMin.clamp(0, _budgetMax),
                  _budgetMax.clamp(_budgetMin, 100),
                ),
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.primaryTint,
                onChanged: (v) => setState(() {
                  _budgetMin = v.start;
                  _budgetMax = v.end;
                }),
              ),
              const SizedBox(height: 8),
            ],

            // No Restriction toggle
            Row(
              children: [
                const Text(
                  'No Budget Restriction',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _noRestriction,
                  onChanged: (v) => setState(() => _noRestriction = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),

            // Budget tag
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _budgetColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _budgetTag(),
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const Text(
              'Materials',
              style: TextStyle(
                fontFamily: AppTypography.headingFamily,
                fontSize: AppTypography.sectionTitleSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            ..._materials.asMap().entries.map((entry) {
              return Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.bodySize,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _materials.removeAt(entry.key)),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.divider),
                ],
              );
            }),

            // Add item row
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _newItemCtrl,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '',
                      hintStyle: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.hintText,
                        fontSize: AppTypography.helperSize,
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _addMaterial(),
                  ),
                ),
                TextButton(onPressed: _addMaterial, child: const Text('Add')),
              ],
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
}
