import 'home.dart';
import 'explore_page.dart' show projectMatchesBrowse;
import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import '../../../shared/widgets/explore_project_card.dart';
import '../../../shared/widgets/account_required_prompt.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';
import '../../../shared/widgets/profile_ecopoints_card.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:flutter/cupertino.dart';
import '../../../shared/widgets/profile_subject_progress.dart';
import 'package:flutter/material.dart';
import '../../../backend/auth/auth_service.dart';
import '../../../backend/db/models/user_profile.dart';
import '../../../backend/db/models/project.dart';
import '../../../backend/db/repositories/users_repo.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../backend/db/repositories/friends_repo.dart';
import '../../../shared/styling/app_typography.dart';
import '../../../shared/widgets/journal_section_header.dart';
import '../../project/pages/journal_entry_view.dart';
import 'settings.dart';

void openUserProfile(BuildContext context, String userId) {
  pushAppRoute(
    context,
    MaterialPageRoute(builder: (_) => PublicUserProfilePage(userId: userId)),
  );
}

class PublicUserProfilePage extends StatefulWidget {
  const PublicUserProfilePage({
    super.key,
    required this.userId,
    this.profile,
    this.usersRepo,
    this.projectsRepo,
    this.friendsRepo,
    this.currentUserId,
  });
  final String? currentUserId;
  final UsersRepo? usersRepo;
  final ProjectsRepo? projectsRepo;
  final FriendsRepo? friendsRepo;
  final String userId;
  final UserProfile? profile;
  @override
  State<PublicUserProfilePage> createState() => _PublicUserProfilePageState();
}

class _PublicUserProfilePageState extends State<PublicUserProfilePage> {
  Route<dynamic>? _profileRoute;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _profileRoute) return;
    _profileRoute = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route != null)
        desktopRouteObserver.registerProfile(route, true);
    });
  }

  @override
  void dispose() {
    final route = _profileRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null) desktopRouteObserver.registerProfile(route, false);
    });
    super.dispose();
  }

  int _section = 0;
  String? _selectedSubject;
  Future<List<UserProfile>?>? _friends;
  bool get _own {
    try {
      return widget.userId ==
          (widget.currentUserId ?? AuthService.instance.currentUser?.id);
    } catch (_) {
      return false;
    }
  }

  late final _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
  late Future<
    ({
      UserProfile? person,
      bool allowed,
      List<Project> projects,
      Map<String, dynamic> progress,
    })
  >
  _data = _load();
  Future<
    ({
      UserProfile? person,
      bool allowed,
      List<Project> projects,
      Map<String, dynamic> progress,
    })
  >
  _load() async {
    final people = await (widget.usersRepo ?? UsersRepo()).getProfilesByIds([
      widget.userId,
    ]);
    final person = people.firstOrNull ?? widget.profile;
    final allowed = await (widget.friendsRepo ?? FriendsRepo())
        .canViewUserProjects(targetUserId: widget.userId);
    if (!allowed)
      return (
        person: person,
        allowed: false,
        projects: <Project>[],
        progress: <String, dynamic>{},
      );
    final projects = _own
        ? <Project>[]
        : await _projectsRepo.getProjectsByUserId(userId: widget.userId);
    final progress = await _projectsRepo.ecoPointsSummary(widget.userId);
    return (
      person: person,
      allowed: true,
      projects: projects ?? <Project>[],
      progress: progress,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Profile'),
    ),
    body: FutureBuilder(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _data = _load()),
              child: const Text('Could not load profile. Retry'),
            ),
          );
        final data = snapshot.data;
        final person = data?.person;
        if (person == null)
          return const Center(child: Text('This profile is unavailable.'));
        final own = _own;
        final visibleProjects = data!.projects
            .where(
              (project) =>
                  _selectedSubject == null ||
                  projectMatchesBrowse(project, subjects: {_selectedSubject!}),
            )
            .toList();
        final total = (data!.progress['total'] as num? ?? 0).toDouble();
        final subjects = Map<String, dynamic>.from(
          data.progress['subjects'] as Map? ?? {},
        );
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: PageScrollWithFooter(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 52,
                      backgroundImage: person.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(person.avatarUrl!)
                          : null,
                      child: person.avatarUrl?.isNotEmpty == true
                          ? null
                          : const Icon(Icons.person_outline, size: 44),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    person.resolvedDisplayName,
                    textAlign: TextAlign.center,
                    style: AppTypography.pageTitle,
                  ),
                  if (person.username?.isNotEmpty == true)
                    Text(
                      '@${person.username}',
                      textAlign: TextAlign.center,
                      style: AppTypography.helper,
                    ),
                  if (data.allowed && person.bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(person.bio, textAlign: TextAlign.center),
                    ),
                  if (own) const SizedBox(height: 12),
                  if (own)
                    Center(
                      child: OutlinedButton(
                        onPressed: () async {
                          await pushAppRoute(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                          if (mounted) setState(() => _data = _load());
                        },
                        child: const Text('Profile settings'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (data.allowed) ...[
                    ProfileEcoPointsCard(points: total.toDouble()),
                    const SizedBox(height: 24),
                  ],
                  if (!data.allowed)
                    const Text(
                      'This profile is private. Only friends can view their progress and library.',
                      textAlign: TextAlign.center,
                    )
                  else ...[
                    CupertinoSlidingSegmentedControl<int>(
                      groupValue: _section,
                      children: {
                        0: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text('Progress'),
                        ),
                        1: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text('Friends'),
                        ),
                        if (!own)
                          2: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text('Journal Library'),
                          ),
                      },
                      onValueChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _section = value;
                          if (value == 1)
                            _friends ??= (widget.friendsRepo ?? FriendsRepo())
                                .getVisibleFriendsForUser(widget.userId);
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_section == 0) ...[
                      ProfileSubjectProgress(
                        onSubjectSelected: (subject) {
                          if (own) {
                            pushAppRoute(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HomeShellScreen(
                                  initialSection: 1,
                                  initialLibrarySubject: subject,
                                  restoreJournal: false,
                                ),
                              ),
                            );
                          } else {
                            setState(() {
                              _selectedSubject = subject;
                              _section = 2;
                            });
                          }
                        },
                        total: total,
                        points: subjects.map(
                          (k, v) => MapEntry(k, (v as num).toDouble()),
                        ),
                      ),
                    ],
                    if (_section == 1)
                      FutureBuilder<List<UserProfile>?>(
                        future: _friends,
                        builder: (context, friends) {
                          if (friends.connectionState != ConnectionState.done)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          if (friends.hasError || friends.data == null)
                            return const Text(
                              'Could not load friends. Please try again.',
                            );
                          final count = friends.data!.length;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Text(
                                  '$count ${count == 1 ? 'Friend' : 'Friends'}',
                                  style: AppTypography.sectionTitle,
                                ),
                              ),
                              if (count == 0)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'No friends to display yet.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              for (final friend in friends.data!)
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        friend.avatarUrl?.isNotEmpty == true
                                        ? NetworkImage(friend.avatarUrl!)
                                        : null,
                                    child: friend.avatarUrl?.isNotEmpty == true
                                        ? null
                                        : const Icon(Icons.person_outline),
                                  ),
                                  title: Text(friend.resolvedDisplayName),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      openUserProfile(context, friend.id),
                                ),
                            ],
                          );
                        },
                      ),
                    if (!own && _section == 2) ...[
                      const Text(
                        'Journal Library',
                        style: AppTypography.sectionTitle,
                      ),
                      const SizedBox(height: 12),
                      if (_selectedSubject != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InputChip(
                            deleteIcon: const Icon(Icons.close),
                            deleteButtonTooltipMessage: 'Clear subject filter',
                            label: Text(_selectedSubject!),
                            onDeleted: () =>
                                setState(() => _selectedSubject = null),
                          ),
                        ),
                      if (visibleProjects.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            _selectedSubject == null
                                ? 'No projects to show yet.'
                                : 'No visible projects for this subject yet.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 560 ? 2 : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 16) /
                              columns;
                          return Wrap(
                            spacing: 16,
                            children: [
                              for (final project in visibleProjects)
                                SizedBox(
                                  width: width,
                                  child: ExploreProjectCard(
                                    project: project,
                                    onOpen: () => openJournalProject(
                                      context,
                                      project,
                                      _projectsRepo,
                                    ),
                                    onBookmark: () async {
                                      if (_projectsRepo.currentUserId == null) {
                                        await showAccountRequiredPrompt(
                                          context,
                                        );
                                      } else {
                                        await _projectsRepo.bookmarkProject(
                                          id: project.id,
                                        );
                                      }
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
