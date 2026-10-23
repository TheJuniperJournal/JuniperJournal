import 'filter_checkbox.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'impact_icon.dart';
import '../../features/project/pages/create_project.dart'
    show ProjectSettingIcon, ProjectSettingKind;
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

// ── FilterOption ──────────────────────────────────────────────────────────────

class FilterOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;

  const FilterOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
}

// ── Option lists ──────────────────────────────────────────────────────────────

const kProjectTypeOptions = [
  FilterOption(
    value: 'solo',
    label: 'Solo',
    description: 'Projects created and managed individually.',
    icon: Icons.person_outline,
  ),
  FilterOption(
    value: 'collaborative',
    label: 'Collaborative',
    description: 'Projects designed for working with other people.',
    icon: Icons.group_outlined,
  ),
];

bool matchesProjectType(String projectType, Set<String> selected) =>
    selected.isEmpty || selected.contains(projectType.trim().toLowerCase());

const kSubjectOptions = [
  FilterOption(
    value: 'Environment & Sustainability',
    label: 'Environment & Sustainability',
    description:
        'Focuses on understanding and improving natural systems, including ecosystems, climate, water, and resource use, to support long-term environmental health.',
    icon: Icons.eco_outlined,
  ),
  FilterOption(
    value: 'Engineering & Design',
    label: 'Engineering & Design',
    description:
        'Centers on creating, building, and optimizing solutions that address real-world sustainability challenges through innovation, prototyping, and problem-solving.',
    icon: Icons.build_outlined,
  ),
  FilterOption(
    value: 'Energy & Systems',
    label: 'Energy & Systems',
    description:
        'Explores how energy is produced, distributed, and used, with an emphasis on efficiency, renewable technologies, and system-level thinking.',
    icon: Icons.bolt_outlined,
  ),
  FilterOption(
    value: 'Community & Built Environment',
    label: 'Community & Built Environment',
    description:
        'Focuses on how people come together to shape sustainable spaces, from hosting workshops to improving shared environments, infrastructure, and local systems.',
    icon: Icons.location_city_outlined,
  ),
];

const kPhaseOptions = [
  FilterOption(
    value: 'Discovering',
    label: 'Discovering',
    description:
        'Exploring and understanding sustainability challenges by observing systems, researching topics, and identifying opportunities for impact.',
    icon: Icons.search_outlined,
  ),
  FilterOption(
    value: 'Ideating',
    label: 'Ideating',
    description:
        'Generating ideas and designing potential solutions to address sustainability challenges through creativity and problem-solving.',
    icon: Icons.lightbulb_outline,
  ),
  FilterOption(
    value: 'Prototyping',
    label: 'Prototyping',
    description:
        'Building and experimenting with early versions of ideas to test functionality, explore solutions, and bring concepts to life.',
    icon: Icons.build_outlined,
  ),
  FilterOption(
    value: 'Implemented',
    label: 'Implemented',
    description:
        'Putting solutions into action, creating real-world impact through completed projects, measurable outcomes, and sustained change.',
    icon: Icons.rocket_launch_outlined,
  ),
];

const kScaleOptions = [
  FilterOption(
    value: 'Small',
    label: 'Small',
    description:
        'Focused on a single action or idea, typically completed by an individual or small group, with a localized or short-term impact.',
    icon: Icons.person_outline,
  ),
  FilterOption(
    value: 'Medium',
    label: 'Medium',
    description:
        'Involves multiple steps or components, often requiring coordination or planning, with impact extending beyond a single activity or space.',
    icon: Icons.people_outline,
  ),
  FilterOption(
    value: 'Large',
    label: 'Large',
    description:
        'Spans multiple systems, groups, or locations, requiring significant planning, collaboration, or time, with broader and longer-term impact.',
    icon: Icons.public_outlined,
  ),
];

const kDifficultyOptions = [
  FilterOption(
    value: 'Easy',
    label: 'Easy',
    description:
        'Simple to start and complete, requiring minimal resources, prior knowledge, or time, and can be done independently with little planning.',
    icon: Icons.wb_sunny_outlined,
  ),
  FilterOption(
    value: 'Moderate',
    label: 'Moderate',
    description:
        'Requires some planning, effort, or learning, possibly involving multiple steps, tools, or collaboration to successfully complete.',
    icon: Icons.brightness_medium_outlined,
  ),
  FilterOption(
    value: 'Hard',
    label: 'Hard',
    description:
        'Highly involved and complex, requiring significant time, coordination, resources, or technical knowledge to execute effectively.',
    icon: Icons.brightness_high_outlined,
  ),
];

const kMetricOptions = [
  FilterOption(
    value: 'Biological Growth',
    label: 'Biological Growth',
    description:
        'Measures increases in plant life, biodiversity, or ecosystem health, including growth of vegetation, food systems, or natural habitats over time.',
    icon: Icons.spa_outlined,
  ),
  FilterOption(
    value: 'Energy',
    label: 'Energy',
    description:
        'Tracks energy saved, reduced, or generated through efficiency improvements, behavior changes, or renewable energy use.',
    icon: Icons.bolt_outlined,
  ),
  FilterOption(
    value: 'Education',
    label: 'Education',
    description:
        'Captures learning outcomes, knowledge gained, and awareness built through projects, workshops, or shared experiences.',
    icon: Icons.menu_book_outlined,
  ),
  FilterOption(
    value: 'Waste',
    label: 'Waste',
    description:
        'Measures waste reduced, diverted, or repurposed through recycling, composting, and efforts to minimize material consumption.',
    icon: Icons.delete_outline,
  ),
  FilterOption(
    value: 'Water',
    label: 'Water',
    description:
        'Tracks water saved, reused, or conserved through system improvements, behavioral changes, or sustainable water practices.',
    icon: Icons.water_drop_outlined,
  ),
];
const kImpactOptions = [
  FilterOption(
    value: 'Seed',
    label: 'Seed',
    description:
        'Represents initial impact, where actions begin to create measurable change at a small or localized level.',
    icon: Icons.grass,
  ),
  FilterOption(
    value: 'Sapling',
    label: 'Sapling',
    description:
        'Represents growing impact, where actions lead to consistent, measurable improvements beyond a single instance or moment.',
    icon: Icons.spa_outlined,
  ),
  FilterOption(
    value: 'Grove',
    label: 'Grove',
    description:
        'Represents expanding impact, where outcomes influence multiple people, systems, or areas through repeated or shared efforts.',
    icon: Icons.park_outlined,
  ),
  FilterOption(
    value: 'Forest',
    label: 'Forest',
    description:
        'Represents significant impact, where outcomes drive meaningful change across communities, environments, or systems over time.',
    icon: Icons.forest_outlined,
  ),
  FilterOption(
    value: 'Watershed',
    label: 'Watershed',
    description:
        'Represents transformative impact, where outcomes create lasting, system-level change that can scale, spread, or influence entire regions or networks.',
    icon: Icons.account_tree_outlined,
  ),
];
const kPatternOptions = [
  FilterOption(
    value: 'Reduction',
    label: 'Reduction',
    description:
        'Focuses on lowering negative impact by using less energy, water, or materials, improving efficiency, and minimizing waste or emissions.',
    icon: Icons.trending_down,
  ),
  FilterOption(
    value: 'Regeneration',
    label: 'Regeneration',
    description:
        'Focuses on restoring and improving natural systems, increasing biodiversity, and creating positive environmental growth beyond baseline conditions.',
    icon: Icons.eco_outlined,
  ),
  FilterOption(
    value: 'Substitution',
    label: 'Substitution',
    description:
        'Focuses on replacing high-impact systems, materials, or behaviors with more sustainable alternatives, such as switching to renewable or reusable solutions.',
    icon: Icons.swap_horiz,
  ),
  FilterOption(
    value: 'Behavior Change',
    label: 'Behavior Change',
    description:
        'Focuses on shifting habits, actions, and decision-making over time, influencing how individuals or groups engage with sustainability.',
    icon: Icons.alt_route,
  ),
  FilterOption(
    value: 'Capacity Building',
    label: 'Capacity Building',
    description:
        'Focuses on enabling long-term impact by building knowledge, skills, systems, or infrastructure that allow others to continue and scale sustainable actions.',
    icon: Icons.account_tree_outlined,
  ),
];

// ── ProjectFilterSheet ────────────────────────────────────────────────────────

class ProjectFilterSheet extends StatefulWidget {
  final String title;
  final List<FilterOption> options;
  final Set<String> initialSelected;
  final void Function(Set<String>) onApply;

  const ProjectFilterSheet({
    super.key,
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.onApply,
  });

  @override
  State<ProjectFilterSheet> createState() => _ProjectFilterSheetState();
}

class _ProjectFilterSheetState extends State<ProjectFilterSheet> {
  late final Set<String> _selected = Set.from(widget.initialSelected);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                widget.title,
                style: AppTypography.sectionTitle.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text('|', style: TextStyle(color: AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Select all that apply',
                  style: AppTypography.helper,
                ),
              ),
              IconButton(
                tooltip: 'Close filters',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.primary, height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final selected = _selected.contains(option.value);
                void toggle() => setState(
                  () => selected
                      ? _selected.remove(option.value)
                      : _selected.add(option.value),
                );
                return Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    onTap: toggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 36, height: 40, child: _icon(option)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: AppTypography.fieldLabel,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  option.description,
                                  style: AppTypography.helper.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterCheckbox(
                            value: selected,
                            onChanged: (_) => toggle(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onApply(Set.from(_selected));
                Navigator.pop(context);
              },
              child: Text(
                _selected.isEmpty ? 'Clear Filters' : 'Apply Filters',
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _icon(FilterOption option) {
    final kind = switch (widget.title) {
      'Subject' => ProjectSettingKind.subject,
      'Scale' => ProjectSettingKind.scale,
      'Difficulty' => ProjectSettingKind.difficulty,
      _ => null,
    };
    if (kind != null) {
      return Center(
        child: SizedBox.square(
          dimension: 32,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ProjectSettingIcon(kind: kind, value: option.value),
          ),
        ),
      );
    }
    return Center(
      child: const ['Metrics', 'Impact', 'Pattern'].contains(widget.title)
          ? SvgPicture.asset(
              impactIconAsset(widget.title, option.value),
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            )
          : Icon(option.icon, size: 28, color: AppColors.primary),
    );
  }
}
