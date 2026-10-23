import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../../../shared/widgets/filter_checkbox.dart';
import '../../../shared/widgets/project_filter_sheet.dart';
import 'package:flutter/material.dart';
import '../../../backend/auth/auth_service.dart';
import '../../../backend/db/models/project.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import 'project_dashboard.dart';

/// Linked projects remain available here independently of public feed updates.
class CommunityProjectLibrary extends StatefulWidget {
  const CommunityProjectLibrary({super.key, required this.communityId});
  final String communityId;
  @override
  State<CommunityProjectLibrary> createState() =>
      _CommunityProjectLibraryState();
}

class _CommunityProjectLibraryState extends State<CommunityProjectLibrary> {
  Set<String> _types = {};
  late Future<List<Project>> _projects = _load();
  Future<List<Project>> _load() =>
      ProjectsRepo().getLinkedCommunityProjects(widget.communityId);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community Library')),
    body: FutureBuilder<List<Project>>(
      future: _projects,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final projects = snapshot.data!
            .where((p) => matchesProjectType(p.projectType, _types))
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _projects = _load());
            await _projects;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  children: [
                    for (final option in kProjectTypeOptions)
                      FilterCheckboxOption(
                        label: Text(option.label),
                        selected: _types.contains(option.value),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _types.add(option.value);
                          } else {
                            _types.remove(option.value);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              if (projects.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No projects added yet.')),
                ),
              for (final project in projects)
                ListTile(
                  leading: const Icon(Icons.book_outlined),
                  title: Text(project.projectName),
                  subtitle: Text(
                    project.problemStatement ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => pushAppRoute(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectDashboard(
                        projectId: project.id,
                        projectName: project.projectName,
                        tags: project.tags,
                        isOwner:
                            project.userId ==
                            AuthService.instance.currentUser?.id,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
