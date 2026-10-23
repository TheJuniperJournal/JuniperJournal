/// Human-readable measurement + unit, e.g. "0 units", "1 unit", "3 people".
String formatMeasurement(double value, String? unit) {
  final isWhole = value == value.roundToDouble();
  final number = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  switch (unit) {
    case 'units':
      return '$number ${value == 1 ? 'unit' : 'units'}';
    case 'people':
      return '$number ${value == 1 ? 'person' : 'people'}';
    case null:
    case '':
      return number;
    default:
      return '$number $unit';
  }
}

class ImpactEntry {
  final String id;
  final String projectId;
  final String title;
  final String metric;
  final String impactScale;
  final String patternType;
  final String evidenceType;
  final String confidenceScore;
  final double? measurement;
  final String? measurementUnit;
  final double ecoPoints;
  final String? linkedJournalEntryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Measurement with pluralized unit, e.g. "12 units", or "—" when unset.
  String get measurementDisplay => measurement == null
      ? '—'
      : formatMeasurement(measurement!, measurementUnit);

  const ImpactEntry({
    required this.id,
    required this.projectId,
    required this.title,
    required this.metric,
    required this.impactScale,
    required this.patternType,
    required this.evidenceType,
    required this.confidenceScore,
    this.measurement,
    this.measurementUnit,
    required this.ecoPoints,
    this.linkedJournalEntryId,
    this.createdAt,
    this.updatedAt,
  });

  factory ImpactEntry.fromMap(Map<String, dynamic> map) => ImpactEntry(
    id: map['id']?.toString() ?? '',
    projectId: map['project_id']?.toString() ?? '',
    title: map['title']?.toString() ?? '',
    metric: map['metric']?.toString() ?? '',
    impactScale: map['impact_scale']?.toString() ?? '',
    patternType: map['pattern_type']?.toString() ?? '',
    evidenceType: map['evidence_type']?.toString() ?? '',
    confidenceScore: map['confidence_score']?.toString() ?? '',
    measurement: map['measurement'] != null
        ? (map['measurement'] as num).toDouble()
        : null,
    measurementUnit: map['measurement_unit']?.toString(),
    ecoPoints: (map['eco_points'] as num? ?? 0).toDouble(),
    linkedJournalEntryId: map['linked_journal_entry_id']?.toString(),
    createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
  );
}
