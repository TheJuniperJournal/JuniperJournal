import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';

class MetricsPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> tags;

  const MetricsPage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.tags,
  });

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  // METRIC OPTIONS + THRESHOLDS
  final List<Map<String, dynamic>> metricOptions = [
    {
      "name": "Educational",
      "unit": "People",
      "circleLabel": "People Reached",
      "thresholds": {"low": 20, "medium": 200},
    },
    {
      "name": "BioGrowth",
      "unit": "Sq Ft",
      "circleLabel": "Habitat Restored",
      "thresholds": {"low": 50, "medium": 500},
    },
    {
      "name": "Water",
      "unit": "Gallons",
      "circleLabel": "Gallons Saved",
      "thresholds": {"low": 1000, "medium": 10000},
    },
    {
      "name": "Energy",
      "unit": "kWh",
      "circleLabel": "Energy Saved",
      "thresholds": {"low": 500, "medium": 5000},
    },
    {
      "name": "CO₂",
      "unit": "lbs CO₂",
      "circleLabel": "CO₂ Avoided",
      "thresholds": {"low": 500, "medium": 5000},
    },
    {
      "name": "Waste",
      "unit": "lbs",
      "circleLabel": "Waste Diverted",
      "thresholds": {"low": 100, "medium": 1000},
    },
  ];

  Map<String, dynamic>? selectedMetric;

  // User inputs (only baseline + post)
  final baselineCtrl = TextEditingController();
  final postCtrl = TextEditingController();

  // Fixed default values
  final double scale = 1;
  final double duration = 1;

  // Calculated values
  double? impactValue;
  String impactLabel = "LOW IMPACT";
  Color impactColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    baselineCtrl.addListener(calculateImpact);
    postCtrl.addListener(calculateImpact);
  }

  // IMPACT CALCULATION
  void calculateImpact() {
    if (selectedMetric == null) return;

    double baseline = double.tryParse(baselineCtrl.text) ?? 0;
    double post = double.tryParse(postCtrl.text) ?? 0;

    // Impact = |Baseline - Post| × 1 × 1
    double value = (baseline - post).abs();

    final thresholds = selectedMetric!["thresholds"];
    double low = (thresholds["low"] as num).toDouble();
    double med = (thresholds["medium"] as num).toDouble();

    if (value > med) {
      impactLabel = "HIGH IMPACT";
      impactColor = Colors.orange[700]!;
    } else if (value > low) {
      impactLabel = "MEDIUM IMPACT";
      impactColor = Colors.blue;
    } else {
      impactLabel = "LOW IMPACT";
      impactColor = AppColors.primary;
    }

    setState(() {
      impactValue = value;
    });
  }

  // INPUT FIELD
  Widget buildInputRow(String label, TextEditingController ctrl, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Center(
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // IMPACT CIRCLE
  Widget buildImpactCircle(String label) {
    if (impactValue == null) return const SizedBox(height: 180);

    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider, width: 3),
              ),
            ),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 3),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  impactValue!.toStringAsFixed(0),
                  style: const TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    fontSize: AppTypography.heroSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Net Impact",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? unit = selectedMetric?["unit"];
    String? circleLabel = selectedMetric?["circleLabel"];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: ContentAlignedBackButton(
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(widget.projectName, style: AppTypography.pageTitle),
        centerTitle: true,
        actions: const [],
        shape: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.6),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: PageScrollWithFooter(
          child: ListView(
            children: [
              // TAGS DISPLAY
              Wrap(
                spacing: 8,
                children: widget.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.primary,
                        fontSize: AppTypography.captionSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppMetrics.fieldGap),

              // SELECT METRIC
              DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: selectedMetric,
                decoration: InputDecoration(
                  labelText: "Select Impact Metric",
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                ),
                items: metricOptions.map((opt) {
                  return DropdownMenuItem(value: opt, child: Text(opt["name"]));
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedMetric = value);
                  calculateImpact();
                },
              ),

              const SizedBox(height: AppMetrics.fieldGap),

              if (selectedMetric != null)
                Column(
                  children: [
                    buildInputRow("Baseline", baselineCtrl, unit!),
                    const SizedBox(height: AppMetrics.fieldGap),

                    buildInputRow("Post", postCtrl, unit),
                    const SizedBox(height: AppMetrics.sectionGap),

                    if (circleLabel != null) buildImpactCircle(circleLabel),

                    const SizedBox(height: AppMetrics.fieldGap),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: impactColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        impactLabel,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: AppTypography.bodySize,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
