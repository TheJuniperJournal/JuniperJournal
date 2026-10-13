import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class JournalAddToSheet extends StatefulWidget {
  const JournalAddToSheet({super.key});

  @override
  State<JournalAddToSheet> createState() => _JournalAddToSheetState();
}

class _JournalAddToSheetState extends State<JournalAddToSheet> {
  final _projectsRepo = ProjectsRepo();
  final _searchController = TextEditingController();

  List<Project> _allProjects = [];
  List<Project> _filtered = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final projects = await _projectsRepo.getCurrentUserProjects();
    if (!mounted) return;
    setState(() {
      _allProjects = projects ?? [];
      _filtered = _allProjects;
      _isLoading = false;
    });
  }

  void _filter() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _allProjects
          : _allProjects
                .where((p) => p.projectName.toLowerCase().contains(q))
                .toList();
    });
  }

  Future<void> _addToProject(Project project) async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    final nextNumber =
        (await _projectsRepo.getJournalEntries(
          projectId: project.id,
        ))?.length ??
        0;

    final created = await _projectsRepo.createJournalEntry(
      projectId: project.id,
      title: 'Entry ${nextNumber + 1}',
      content: const [],
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (created == null) {
      showTopSnackBar(context, 'Failed to create journal entry', isError: true);
      return;
    }

    Navigator.pop(context); // close sheet
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalEntryEditorScreen(
          projectId: project.id,
          projectName: project.projectName,
          tags: project.tags,
          entryId: created.id,
          initialTitle: created.title,
          initialContent: const [],
          initialProgress: null,
        ),
      ),
    );
  }

  Future<void> _createProject() async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Add to',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        size: 22,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search projects',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Material(
                color: Colors.transparent,
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        children: [
                          if (_filtered.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Text(
                                'Recent Projects',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ..._filtered.map(
                            (p) => _ProjectRow(
                              project: p,
                              isLoading: _isCreating,
                              onTap: () => _addToProject(p),
                            ),
                          ),
                          if (_filtered.isEmpty && !_isLoading)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                'No projects found.',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),

                          // Create Project row
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            title: const Text(
                              'Create Project',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: _createProject,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.onTap,
    required this.isLoading,
  });

  final Project project;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 60,
          height: 60,
          child: (project.imageUrl != null && project.imageUrl!.isNotEmpty)
              ? Image.network(project.imageUrl!, fit: BoxFit.cover)
              : Container(
                  color: AppColors.avatarBackground,
                  child: const Icon(
                    Icons.landscape_outlined,
                    color: AppColors.avatarIcon,
                    size: 28,
                  ),
                ),
        ),
      ),
      title: Text(
        project.projectName,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: isLoading ? null : onTap,
    );
  }
}
