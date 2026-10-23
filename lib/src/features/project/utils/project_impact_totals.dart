import '../../../backend/db/models/impact_entry.dart';

/// Sum persisted awards. Measurements with different units remain separate.
class ProjectImpactTotals {
  ProjectImpactTotals(Iterable<ImpactEntry> entries)
    : entries = List.unmodifiable(entries);
  final List<ImpactEntry> entries;
  double get ecoPoints => entries.fold(
    0,
    (sum, entry) => sum + (entry.ecoPoints.isFinite ? entry.ecoPoints : 0),
  );
  double pointsFor(String metric) => entries
      .where((entry) => entry.metric.toLowerCase() == metric.toLowerCase())
      .fold(
        0,
        (sum, entry) => sum + (entry.ecoPoints.isFinite ? entry.ecoPoints : 0),
      );
  List<String> measurementsFor(String metric) {
    final totals = <String, double>{};
    for (final entry in entries.where(
      (entry) => entry.metric.toLowerCase() == metric.toLowerCase(),
    )) {
      final value = entry.measurement;
      if (value == null || !value.isFinite) continue;
      final unit = entry.measurementUnit ?? '';
      totals[unit] = (totals[unit] ?? 0) + value;
    }
    return [
      for (final entry in totals.entries)
        formatMeasurement(entry.value, entry.key),
    ];
  }
}
