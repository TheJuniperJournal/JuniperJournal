/// Transparent artwork shared by impact submission and project filters.
String impactIconAsset(String group, String value) {
  if (group == 'Metrics') {
    final name = switch (value) {
      'Biological Growth' => 'bio',
      'Education' => 'education',
      'Energy' => 'energy',
      'Waste' => 'waste',
      _ => 'water',
    };
    return 'assets/project_setup/impact_$name.svg';
  }
  if (group == 'Pattern') {
    final name = switch (value) {
      'Behavior Change' => 'behavior',
      'Capacity Building' => 'capacity',
      _ => value.toLowerCase(),
    };
    return 'assets/project_setup/pattern_$name.svg';
  }
  return 'assets/impact/scale_${value.split(' (').first.toLowerCase()}.svg';
}
