import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/features/project/utils/project_impact_totals.dart';

ImpactEntry entry(
  String id,
  String metric,
  double points,
  double measurement,
  String unit,
) => ImpactEntry(
  id: id,
  projectId: 'p',
  title: id,
  metric: metric,
  impactScale: 'Seed',
  patternType: 'Reduction',
  evidenceType: 'Measured',
  confidenceScore: 'High',
  ecoPoints: points,
  measurement: measurement,
  measurementUnit: unit,
);
void main() {
  test('empty projects have no invented points or measurements', () {
    final totals = ProjectImpactTotals([]);
    expect(totals.ecoPoints, 0);
    expect(totals.pointsFor('Water'), 0);
    expect(totals.measurementsFor('Water'), isEmpty);
  });
  test(
    'saved awards and compatible measurements update on create, edit and delete',
    () {
      final water = entry('a', 'Water', 12, 10, 'litres');
      final other = entry('b', 'Water', 8, 2, 'gallons');
      final energy = entry('c', 'Energy', 3, 5, 'kWh');
      final totals = ProjectImpactTotals([water, other, energy]);
      expect(totals.ecoPoints, 23);
      expect(totals.pointsFor('Water'), 20);
      expect(totals.measurementsFor('Water'), ['10 litres', '2 gallons']);
      final edited = ProjectImpactTotals([
        entry('a', 'Water', 15, 14, 'litres'),
        other,
        energy,
      ]);
      expect(edited.ecoPoints, 26);
      expect(ProjectImpactTotals([energy]).pointsFor('Water'), 0);
    },
  );
}
