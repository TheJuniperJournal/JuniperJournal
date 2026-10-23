import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/project.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';

class FriendProjectsPage extends StatefulWidget {
  final String userId;
  final String displayName;

  const FriendProjectsPage({
    super.key,
    required this.userId,
    required this.displayName,
  });

  @override
  State<FriendProjectsPage> createState() => _FriendProjectsPageState();
}

class _FriendProjectsPageState extends State<FriendProjectsPage> {
  final _projectsRepo = ProjectsRepo();
  final _friendsRepo = FriendsRepo();

  bool _isLoading = true;
  bool _canView = false;
  List<Project> _projects = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final canView = await _friendsRepo.canViewUserProjects(
      targetUserId: widget.userId,
    );

    if (!mounted) return;

    if (!canView) {
      setState(() {
        _canView = false;
        _projects = const [];
        _isLoading = false;
      });
      return;
    }

    final projects = await _projectsRepo.getProjectsByUserId(
      userId: widget.userId,
    );
    if (!mounted) return;

    setState(() {
      _canView = true;
      _projects = projects ?? const <Project>[];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 18,
            color: AppColors.border,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.displayName}\'s Projects',
          style: AppTypography.pageTitle,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_canView
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'This user\'s projects are private.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              )
            : _projects.isEmpty
            ? const Center(
                child: Text(
                  'No projects available.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final project = _projects[index];
                  final projectName = project.projectName.isNotEmpty
                      ? project.projectName
                      : 'Untitled Project';
                  final projectId = project.id;
                  final tags = project.tags;

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryTint,
                      child: const Icon(
                        Icons.folder_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      projectName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: tags.isEmpty
                        ? const Text('No tags')
                        : Text(tags.join(' • ')),
                    onTap: () {
                      pushAppRoute(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectDashboard(
                            projectId: projectId,
                            projectName: projectName,
                            tags: tags,
                            isOwner: false,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
