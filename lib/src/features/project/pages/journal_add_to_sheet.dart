import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/desktop_modal_layer.dart';
import '../../../backend/db/models/community.dart';
import 'journal_phase_dialog.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'project_development_flow.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

class JournalAddToSheet extends StatefulWidget {
  const JournalAddToSheet({super.key, this.projectsRepo, this.community});
  final Community? community;
  final ProjectsRepo? projectsRepo;

  @override
  State<JournalAddToSheet> createState() => _JournalAddToSheetState();
}

class _JournalAddToSheetState extends State<JournalAddToSheet> {
  late final _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
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
    var projects = widget.community == null
        ? await _projectsRepo.getLibraryProjects()
        : await _projectsRepo.getLinkedCommunityProjects(widget.community!.id);
    if (widget.community != null) {
      final permissions = await Future.wait(
        projects.map((p) => _projectsRepo.canViewInternalProjectLogs(p.id)),
      );
      projects = [
        for (var i = 0; i < projects.length; i++)
          if (permissions[i]) projects[i],
      ];
    }
    if (!mounted) return;
    setState(() {
      _allProjects = projects;
      _filtered = _allProjects
          .where(
            (p) => p.projectName.toLowerCase().contains(
              _searchController.text.toLowerCase().trim(),
            ),
          )
          .toList();
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
    FocusScope.of(context).unfocus();
    setState(() => _isCreating = true);

    var selectedPhase = normalizePhase(project.progress);
    if (!phaseKeys.contains(selectedPhase)) selectedPhase = 'discover';
    while (mounted) {
      final phase = await chooseJournalPhase(
        context,
        selectedPhase: selectedPhase,
        projectName: project.projectName,
      );
      if (!mounted) return;
      if (phase == null) break;
      selectedPhase = phase;
      final opened = await openNewProjectJournal(
        context,
        projectId: project.id,
        phase: phase,
        projectsRepo: _projectsRepo,
      );
      if (!mounted) return;
      if (opened) {
        Navigator.pop(context);
        return;
      }
      // Closing the type chooser returns to this project's phase choice.
    }
    if (mounted) setState(() => _isCreating = false);
  }

  Future<void> _createProject() async {
    await pushAppPage(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProjectScreen(
          initialCommunity: widget.community,
          projectsRepo: _projectsRepo,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !_isCreating,
      maintainState: true,
      child: Container(
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
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.buttonSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: AppTapTarget(
                        onTap: () => Navigator.pop(context, false),
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

              if (widget.community != null) ...[
                Text(
                  'For ${widget.community!.name}',
                  textAlign: TextAlign.center,
                  style: AppTypography.helper,
                ),
                const SizedBox(height: 16),
              ],
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search projects',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  'Recent Projects',
                                  style: TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.bodySize,
                                    fontWeight: FontWeight.w500,
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

                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                24,
                                16,
                                20,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isCreating
                                      ? null
                                      : _createProject,
                                  icon: const Icon(Icons.add, size: 20),
                                  label: const Text('Create Project'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    minimumSize: const Size.fromHeight(52),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    side: BorderSide(
                                      color: AppColors.primary.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: AppTypography.button,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
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
              ? ProtectedImage.network(project.imageUrl!, fit: BoxFit.cover)
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
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.bodySize,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: isLoading ? null : onTap,
    );
  }
}
