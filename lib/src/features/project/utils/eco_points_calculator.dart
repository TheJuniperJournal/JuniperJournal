import 'dart:math';

// Fixed base points per impact entry. The journal entry's progress stage
// contributes its own points separately; we don't fold it into each impact.
const impactBasePoints = 15.0;

const impactScaleMultipliers = {
  'Seed (Very Small)': 1.00,
  'Sapling (Small)': 1.25,
  'Grove (Moderate)': 1.50,
  'Forest (Large)': 1.75,
  'Watershed (Very Large)': 2.25,
};

const confidenceMultipliers = {'Low': 0.70, 'Medium': 0.85, 'High': 1.00};

// Threshold lookup: list of (threshold, multiplier) pairs in ascending order.
const _sqftThresholds = [
  (0, 1.00),
  (10, 1.05),
  (25, 1.10),
  (50, 1.20),
  (100, 1.30),
  (250, 1.40),
  (500, 1.50),
  (1000, 1.60),
  (2500, 1.75),
  (5000, 2.00),
];

const _kgThresholds = [
  (0, 1.00),
  (5, 1.05),
  (10, 1.10),
  (20, 1.20),
  (50, 1.30),
  (100, 1.40),
  (250, 1.50),
  (500, 1.60),
  (1000, 1.75),
  (2500, 2.00),
];

double measurementMultiplier(double m, String unit) {
  if (unit == 'units' || unit == 'people') {
    return min(1.0 + 0.5 * log(m + 1) / ln10, 2.0);
  }
  final thresholds = unit == 'kg' ? _kgThresholds : _sqftThresholds;
  double result = 1.0;
  for (final (threshold, mult) in thresholds) {
    if (m >= threshold) {
      result = mult;
    } else {
      break;
    }
  }
  return result;
}

double calculateEcoPoints({
  required String? impactScale,
  required String? confidenceScore,
  double? measurement,
  String? measurementUnit,
}) {
  final imp = impactScaleMultipliers[impactScale] ?? 1.0;
  final conf = confidenceMultipliers[confidenceScore] ?? 1.0;
  double meas = 1.0;
  if (measurement != null && measurement > 0 && measurementUnit != null) {
    meas = measurementMultiplier(measurement, measurementUnit);
  }
  final raw = imp * conf * meas * impactBasePoints;
  return double.parse(raw.toStringAsFixed(2));
}
