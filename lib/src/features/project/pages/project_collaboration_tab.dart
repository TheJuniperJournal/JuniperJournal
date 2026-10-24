import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/widgets/flower_reaction_button.dart';
import '../../../shared/widgets/app_tab_transition.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/item_action_menu.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/app_scroll_behavior.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../backend/db/models/bulletin_post.dart';
import '../../../backend/db/models/project.dart';
import '../../../backend/db/models/user_profile.dart';
import '../../../backend/db/repositories/project_bulletin_repo.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../backend/db/repositories/users_repo.dart';
import '../../../services/media_service.dart';
import 'create_project.dart';

const _green = Color(0xFF5DB075);

enum CollaborationSection { bulletin, members, communities }

class ProjectCollaborationTab extends StatefulWidget {
  const ProjectCollaborationTab({
    super.key,
    required this.projectId,
    required this.projectsRepo,
    this.bulletinRepo,
    this.readOnly = false,
    this.pickImage,
    this.refreshToken = 0,
    this.initialSection = CollaborationSection.bulletin,
    this.initialPostId,
    this.initialCommentId,
  });
  final bool readOnly;
  final int refreshToken;
  final CollaborationSection initialSection;
  final String? initialPostId;
  final String? initialCommentId;
  final String projectId;
  final ProjectsRepo projectsRepo;
  final ProjectBulletinRepo? bulletinRepo;
  final Future<String?> Function()? pickImage;
  @override
  State<ProjectCollaborationTab> createState() =>
      _ProjectCollaborationTabState();
}

class _ProjectCollaborationTabState extends State<ProjectCollaborationTab> {
  late final ProjectBulletinRepo _bulletin =
      widget.bulletinRepo ?? ProjectBulletinRepo();
  late CollaborationSection _section = widget.initialSection;
  bool _notificationOpened = false;
  final _notificationPostKey = GlobalKey();
  Project? _project;
  UserProfile? _owner;
  List<UserProfile> _members = [];
  Map<String, String> _roles = {};
  bool _manage = false, _participant = false, _loading = true, _busy = false;
  String? _error;
  List<BulletinPost> _posts = [];
  List<Map<String, dynamic>> _reactions = [];
  final Set<String> _filters = {};
  final _memberSearch = TextEditingController();
  final _communitySearch = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _category = projectPostCategories.first;
  String? _editing;
  final _feedScroll = ScrollController();
  VoidCallback? _refreshPostDialog;
  BuildContext? _postDialogContext;
  final List<String> _images = [];
  bool _showMessageError = false;
  bool _showTitleError = false;
  String? get _userId => _bulletin.currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectCollaborationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  @override
  void dispose() {
    _memberSearch.dispose();
    _communitySearch.dispose();
    _title.dispose();
    _body.dispose();
    _feedScroll.dispose();
    super.dispose();
  }

  Widget _directoryBody({
    required TextEditingController controller,
    required String hint,
    required Widget child,
  }) => Column(
    children: [
      TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.bodySize,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.helperSize,
          ),
          prefixIcon: const Icon(Icons.search, color: _green, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(controller.clear),
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(child: SingleChildScrollView(child: child)),
    ],
  );

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Map<String, String> _memberStatuses = {};
  List<Map<String, dynamic>> _communityRequests = [];
  Future<void> _load() async {
    try {
      final internal =
          !widget.readOnly &&
          await widget.projectsRepo.canViewInternalProjectLogs(
            widget.projectId,
          );
      _participant = internal;
      if (!internal) {
        final project = await widget.projectsRepo.getProjectById(
          widget.projectId,
        );
        if (project == null) throw StateError('Project unavailable');
        final directory = await widget.projectsRepo.getPublicProjectDirectory(
          widget.projectId,
        );
        if (!mounted) return;
        setState(() {
          _project = project;
          _members = directory;
          _owner = directory.where((p) => p.id == project.userId).firstOrNull;
          _members = directory.where((p) => p.id != project.userId).toList();
          _roles = {};
          _manage = false;
          _participant = false;
          _section = _section == CollaborationSection.bulletin
              ? CollaborationSection.members
              : _section;
          _posts = [];
          _reactions = [];
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        widget.projectsRepo.getProjectById(widget.projectId),
        widget.projectsRepo.getProjectInvitees(projectId: widget.projectId),
        widget.projectsRepo.getProjectMemberRoles(widget.projectId),
        widget.projectsRepo.canManageProject(widget.projectId),
      ]);
      final project = results[0] as Project?;
      final members = results[1] as List<UserProfile>?;
      final roles = results[2] as Map<String, String>;
      final manage = results[3] as bool;
      if (project == null) throw StateError('Project unavailable');
      if (members == null) throw StateError('Members unavailable');
      final statuses = await widget.projectsRepo.getProjectMemberStatuses(
        widget.projectId,
      );
      List<Map<String, dynamic>> requests = [];
      if (manage) {
        try {
          requests = await widget.projectsRepo.getCommunityProjectInvitations(
            projectId: widget.projectId,
          );
        } catch (_) {}
      }
      final owners = project.userId == null
          ? <UserProfile>[]
          : await UsersRepo().getProfilesByIds([project.userId!]);
      final participant =
          _userId != null &&
          (project.userId == _userId ||
              members.any(
                (m) => m.id == _userId && statuses[m.id] != 'pending',
              ));
      final posts = participant
          ? await _bulletin.posts(widget.projectId)
          : <BulletinPost>[];
      final reactions = await _bulletin.reactions(
        posts.map((p) => p.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _memberStatuses = statuses;
        _communityRequests = requests;
        _project = project;
        _members = members;
        _roles = roles;
        _manage = manage;
        _owner = owners.firstOrNull;
        _participant = participant;
        _posts = posts;
        _reactions = reactions;
        _loading = false;
        _error = null;
      });
      if (!_notificationOpened && widget.initialPostId != null) {
        _notificationOpened = true;
        final post = posts
            .where((item) => item.id == widget.initialPostId)
            .firstOrNull;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (post != null) {
            final target = _notificationPostKey.currentContext;
            if (target != null)
              Scrollable.ensureVisible(target, alignment: .05);
            if (widget.initialCommentId != null)
              _comments(post, commentId: widget.initialCommentId);
          } else {
            _message('This discussion was removed or is no longer available.');
          }
        });
      }
    } catch (e) {
      debugPrint('Project collaboration load: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load collaboration. Please retry.';
        });
      }
    }
  }

  Future<void> _mutate(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await action()) {
        _message('Could not save the change. Please retry.');
        return;
      }
      await _load();
    } catch (e) {
      _message('Could not save the change. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMembers() async {
    final selected = await showAppDialog<List<UserProfile>>(
      context: context,
      builder: (_) => ProjectMemberPicker(
        existingMembers: const [],
        excludedIds: {
          if (_project?.userId != null) _project!.userId!,
          ..._members.map((m) => m.id),
        },
        confirmLabel: 'Send Invites',
        communityIds: [
          for (final request in _communityRequests.where(
            (r) => r['status'] == 'pending',
          ))
            request['community_id'].toString(),
          for (final link in _project!.communityLinks) link['id'].toString(),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await _mutate(() async {
      var ok = true;
      for (final member in selected.where(
        (m) => m.id != _project?.userId && !_members.any((p) => p.id == m.id),
      )) {
        if (!await widget.projectsRepo.inviteCollaborator(
          projectId: widget.projectId,
          userId: member.id,
        )) {
          ok = false;
        }
      }
      return ok;
    });
  }

  Future<void> _communities() async {
    final selected = await showAppDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => ProjectCommunityPicker(initial: _project!.communityLinks),
    );
    if (selected != null && mounted) {
      await _mutate(
        () => widget.projectsRepo.updateProjectCommunities(
          widget.projectId,
          selected,
        ),
      );
    }
  }

  void _communityRole(String id, String? role) {
    final links = [
      for (final link in _project!.communityLinks)
        if (link['id'] != id || role != null)
          {
            ...link,
            if (link['id'] == id) 'role': role,
            if (role == 'home' && link['id'] != id && link['role'] == 'home')
              'role': 'collaborator',
          },
    ];
    _mutate(
      () =>
          widget.projectsRepo.updateProjectCommunities(widget.projectId, links),
    );
  }

  void _updateComposer(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    _refreshPostDialog?.call();
  }

  Future<void> _openNewPost() async {
    _showMessageError = false;
    _showTitleError = false;
    await showAppDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          _postDialogContext = context;
          ModalDraftScope.onDiscard(context, () {
            _title.clear();
            _body.clear();
            _images.clear();
          });
          _refreshPostDialog = () {
            if (context.mounted) refresh(() {});
          };
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 380,
                maxHeight: MediaQuery.sizeOf(context).height * .85,
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Create Forum Post',
                                  style: AppTypography.pageTitle,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close new post',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.pop(context),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                          const Divider(height: 1, color: Color(0xFFD0D0D0)),
                          const SizedBox(height: AppMetrics.labelGap),
                          _composer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    _refreshPostDialog = null;
    _postDialogContext = null;
  }

  Future<void> _savePost() async {
    if (_busy) return;
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      _updateComposer(() {
        _showTitleError = _title.text.trim().isEmpty;
        _showMessageError = _body.text.trim().isEmpty;
      });
      return;
    }
    _updateComposer(() => _busy = true);
    try {
      await _bulletin.save(
        projectId: widget.projectId,
        title: _title.text.trim(),
        body: _body.text,
        category: _category,
        images: List.from(_images),
      );
      _title.clear();
      _body.clear();
      _images.clear();
      await _load();
      final dialog = _postDialogContext;
      if (dialog != null && dialog.mounted) {
        ModalDraftScope.saved(dialog);
        Navigator.of(dialog).pop();
      }
    } catch (e) {
      _message('Could not save the post. Your draft is still here.');
    } finally {
      if (mounted) _updateComposer(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    if (_busy) return;
    if (_images.length >= 2) {
      _message('Maximum of two photos per post. Remove one to add another.');
      return;
    }
    _updateComposer(() => _busy = true);
    final url = widget.pickImage != null
        ? await widget.pickImage!()
        : await MediaService().pickAndUploadImage(
            ImageSource.gallery,
            folder: 'project-bulletin',
          );
    if (!mounted) return;
    _updateComposer(() {
      if (url != null) {
        _images.add(url);
        if (_postDialogContext != null)
          ModalDraftScope.changed(_postDialogContext!);
      }
      _busy = false;
    });
  }

  Future<void> _postAction(BulletinPost post, String action) async {
    if (action == 'edit') {
      setState(() => _editing = post.id);
      return;
    }
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This removes the post and its comments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _mutate(() async {
        await _bulletin.delete(post.id);
        return true;
      });
    }
  }

  Future<void> _comments(BulletinPost post, {String? commentId}) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => _ProjectComments(
        post: post,
        repo: _bulletin,
        initialCommentId: commentId,
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const ValueKey('collaboration-subtabs'),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    for (final section in CollaborationSection.values.where(
                      (s) => _participant || s != CollaborationSection.bulletin,
                    ))
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: Size.zero,
                            backgroundColor: _section == section
                                ? Colors.white
                                : Colors.transparent,
                            foregroundColor: _section == section
                                ? const Color(0xFF202124)
                                : Colors.grey,
                          ),
                          onPressed: () => setState(() => _section = section),
                          child: Text(
                            switch (section) {
                              CollaborationSection.bulletin => 'Bulletin',
                              CollaborationSection.members => 'Members',
                              CollaborationSection.communities => 'Communities',
                            },
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Column(
                  children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                )
              else ...[
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: AppContentTransition(
                    duration: const Duration(milliseconds: 280),
                    index: _section,
                    child: switch (_section) {
                      CollaborationSection.members => _directoryBody(
                        controller: _memberSearch,
                        hint: 'Search members by name or username',
                        child: ProjectMembersSection(
                          searchQuery: _memberSearch.text,
                          members:
                              _project!.projectType == 'solo' && _participant
                              ? []
                              : _members,
                          owner: _project!.projectType == 'solo' && _participant
                              ? null
                              : _owner,
                          roles: _roles,
                          statuses: _memberStatuses,
                          canManageRoles: _manage && !_busy,
                          onAddPeople: _addMembers,
                          onRemoveMember: (p) => _mutate(
                            () => widget.projectsRepo.removeCollaborator(
                              projectId: widget.projectId,
                              userId: p.id,
                            ),
                          ),
                          onRoleChanged: (id, role) => _mutate(
                            () => widget.projectsRepo.setProjectMemberRole(
                              widget.projectId,
                              id,
                              role,
                            ),
                          ),
                        ),
                      ),
                      CollaborationSection.communities => _directoryBody(
                        controller: _communitySearch,
                        hint: 'Search communities',
                        child: ProjectCommunitiesSection(
                          searchQuery: _communitySearch.text,
                          links: [
                            ..._project!.communityLinks,
                            for (final request in _communityRequests.where(
                              (r) => r['status'] == 'pending',
                            ))
                              if (!_project!.communityLinks.any(
                                (link) =>
                                    link['id'].toString() ==
                                    request['community_id'].toString(),
                              ))
                                {
                                  'id': request['community_id'].toString(),
                                  'name':
                                      request['community_name']?.toString() ??
                                      'Community',
                                  'imageUrl': request['community_image_url'],
                                  'status': 'pending',
                                  'invitationId': request['id'].toString(),
                                },
                          ],
                          showOptional: false,
                          canManage: _manage && !_busy,
                          onAdd: _communities,
                          onRemove: (id) {
                            final pending = _communityRequests
                                .where(
                                  (r) =>
                                      r['status'] == 'pending' &&
                                      r['community_id'].toString() == id,
                                )
                                .firstOrNull;
                            if (pending != null) {
                              _mutate(() async {
                                await widget.projectsRepo
                                    .cancelCommunityProjectInvitation(
                                      pending['id'].toString(),
                                    );
                                return true;
                              });
                            } else {
                              _communityRole(id, null);
                            }
                          },
                          onHome: (id) => _communityRole(id, 'home'),
                          onCollaborator: (id) =>
                              _communityRole(id, 'collaborator'),
                        ),
                      ),
                      CollaborationSection.bulletin => _buildBulletin(),
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_section == CollaborationSection.bulletin &&
            _participant &&
            !_loading &&
            _error == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: SizedBox(
                width: 250,
                height: 44,
                child: FilledButton.icon(
                  key: const ValueKey('create-forum-post'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _busy ? null : _openNewPost,
                  icon: const Icon(Icons.add_circle_outline, size: 23),
                  label: const Text(
                    'Create Forum Post',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.buttonSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBulletin() {
    final visible = _posts
        .where((p) => _filters.isEmpty || _filters.contains(p.category))
        .toList();
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: AppScrollbar(
        controller: _feedScroll,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            key: const ValueKey('project-forum-feed'),
            controller: _feedScroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text(
                      'Filter',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: _green,
                        fontSize: AppTypography.helperSize,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: SingleChildScrollView(
                          key: const ValueKey('forum-category-filters'),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final category in projectPostCategories)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(
                                      category,
                                      style: const TextStyle(
                                        fontFamily: AppTypography.bodyFamily,
                                        fontSize: AppTypography.captionSize,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white,
                                      ),
                                    ),
                                    selected: _filters.contains(category),
                                    showCheckmark: false,
                                    backgroundColor: _green,
                                    selectedColor: const Color(0xFF3E8753),
                                    side: BorderSide.none,
                                    shape: const StadiumBorder(),
                                    onSelected: (_) => setState(() {
                                      if (!_filters.add(category)) {
                                        _filters.remove(category);
                                      }
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_filters.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear filters',
                        onPressed: () => setState(_filters.clear),
                        icon: const Icon(Icons.close, size: 16, color: _green),
                      ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    key: const ValueKey('forum-empty-space'),
                    height: 180,
                    child: Center(
                      child: Text(
                        !_participant
                            ? 'The bulletin is available to project members.'
                            : _posts.isEmpty
                            ? 'Nothing yet… Tap + to start a discussion.'
                            : 'No posts match your filters.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: Colors.grey,
                          fontSize: AppTypography.bodySize,
                        ),
                      ),
                    ),
                  ),
                ),
              SliverList.list(
                children: [
                  for (final post in visible)
                    KeyedSubtree(
                      key: post.id == widget.initialPostId
                          ? _notificationPostKey
                          : ValueKey('forum-post-${post.id}'),
                      child: _bulletinWidth(_postCard(post)),
                    ),
                ],
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postCard(BulletinPost post) {
    if (_editing == post.id) {
      return _InlineForumPostEditor(
        key: ValueKey('inline-post-editor-${post.id}'),
        post: post,
        onCancel: () => setState(() => _editing = null),
        onExpand: _expandImage,
        pickImage:
            widget.pickImage ??
            () => MediaService().pickAndUploadImage(
              ImageSource.gallery,
              folder: 'project-bulletin',
            ),
        onSave: (title, body, category, images) async {
          try {
            await _bulletin.save(
              projectId: widget.projectId,
              id: post.id,
              title: title,
              body: body,
              category: category,
              images: images,
            );
            await _load();
            if (mounted) setState(() => _editing = null);
            return true;
          } catch (e) {
            _message('Could not save changes. Your edit is still here.');
            return false;
          }
        },
      );
    }

    final reactions = _reactions.where((r) => r['post_id'] == post.id).toList();
    final liked = reactions.any((r) => r['user_id'] == _userId);
    return Container(
      key: ValueKey('bulletin-post-${post.id}'),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  for (final url in post.imageUrls.take(2))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ProtectedImage.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                _avatar(post.authorAvatarUrl, 12),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    post.authorLabel,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (post.userId == _userId || _manage)
                  Theme(
                    data: Theme.of(context).copyWith(
                      highlightColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                    ),
                    child: ItemActionMenu(
                      onEdit: post.userId == _userId
                          ? () => _postAction(post, 'edit')
                          : null,
                      onDelete: () => _postAction(post, 'delete'),
                      editLabel: 'Edit Post',
                      deleteLabel: 'Delete Post',
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontWeight: FontWeight.w500,
                    fontSize: AppTypography.bodySize,
                  ),
                ),
                Container(
                  key: ValueKey('post-category-${post.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF438BC0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    post.category.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: Colors.white,
                      fontSize: AppTypography.captionSize,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: _ExpandablePostText(body: post.body),
          ),
          const Divider(height: 1, color: Color(0xFFDEDEDE)),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMM d').format(post.createdAt.toLocal()),
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.helperSize,
                      color: Colors.grey,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: liked ? 'Remove reaction' : 'React',
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _busy
                      ? null
                      : () => _mutate(() async {
                          await _bulletin.react(post.id, liked);
                          return true;
                        }),
                  icon: SvgPicture.asset(
                    'assets/prototyping/build_flower.svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      liked ? _green : Colors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                Text(
                  '${reactions.length}',
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: Colors.grey,
                    fontSize: AppTypography.helperSize,
                  ),
                ),
                IconButton(
                  tooltip: 'Comments',
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => _comments(post),
                  icon: SvgPicture.asset(
                    'assets/prototyping/build_comment.svg',
                    width: 18,
                    height: 18,
                  ),
                ),
                Text(
                  '${post.commentCount}',
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: Colors.grey,
                    fontSize: AppTypography.helperSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _expandImage(String url) => showAppDialog<void>(
    context: _postDialogContext ?? context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close image',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: ProtectedImage.network(
                  url,
                  key: const ValueKey('expanded-forum-image'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Image could not be loaded.'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bulletinWidth(Widget child) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: JournalPageLayout.widthFor(context, mobileWidth: 320),
        ),
        child: SizedBox(width: constraints.maxWidth * .9, child: child),
      ),
    ),
  );

  Widget _composer() => _composerContent();

  Widget _composerContent() => Container(
    key: const ValueKey('project-forum-editor'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _avatar(
              _members.where((m) => m.id == _userId).firstOrNull?.avatarUrl ??
                  (_owner?.id == _userId ? _owner?.avatarUrl : null),
              12,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: AppMetrics.controlHeight,
                child: IgnorePointer(
                  ignoring: _busy,
                  child: ProjectChipMenu(
                    value: _category,
                    hint: 'Post category',
                    options: projectPostCategories,
                    showError: false,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                    onSelected: (category) =>
                        _updateComposer(() => _category = category),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              tooltip: 'Add photo (up to 2)',
              onPressed: _busy ? null : _attach,
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                color: _green,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(88, 36),
              ),
              onPressed: _busy ? null : _savePost,
              child: Text(
                'Post',
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Title', style: AppTypography.helper),
        const SizedBox(height: 6),
        TextField(
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          key: const ValueKey('forum-post-title'),
          controller: _title,
          maxLength: 160,
          onChanged: (value) {
            if (_showTitleError && value.trim().isNotEmpty) {
              _updateComposer(() => _showTitleError = false);
            }
          },
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
          ),
          decoration: InputDecoration(
            hintText: 'Give your post a title',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _showTitleError ? Colors.red : const Color(0xFFD0D0D0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _showTitleError ? Colors.red : const Color(0xFFD0D0D0),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Post body', style: AppTypography.helper),
        const SizedBox(height: 6),
        TextField(
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          key: const ValueKey('forum-post-body'),
          controller: _body,
          onChanged: (value) {
            if (_showMessageError && value.trim().isNotEmpty) {
              _updateComposer(() => _showMessageError = false);
            }
          },
          minLines: 5,
          maxLines: null,
          maxLength: 10000,
          decoration: InputDecoration(
            hintText: 'Share your question, idea, or update…',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: _showMessageError ? Colors.red : const Color(0xFFD0D0D0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: _showMessageError ? Colors.red : const Color(0xFFD0D0D0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: _showMessageError ? Colors.red : const Color(0xFFD0D0D0),
              ),
            ),
          ),
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
          ),
        ),
        if (_images.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Images',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        if (_images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = ((constraints.maxWidth - 32) / 2)
                    .clamp(0, 140)
                    .toDouble();
                return Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 32,
                  runSpacing: 8,
                  children: [
                    for (final url in _images)
                      SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Semantics(
                                button: true,
                                label: 'Expand attached image',
                                child: InkWell(
                                  key: ValueKey('forum-image-preview-$url'),
                                  onTap: () => _expandImage(url),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ProtectedImage.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(
                                            color: Color(0xFFF2F2F2),
                                            child: Icon(
                                              Icons.image_outlined,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: IconButton(
                                  tooltip: 'Remove attached image',
                                  padding: EdgeInsets.zero,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: _busy
                                      ? null
                                      : () => _updateComposer(
                                          () => _images.remove(url),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );
}

Widget _avatar(String? url, double radius) => CircleAvatar(
  radius: radius,
  backgroundImage: url?.isNotEmpty == true ? NetworkImage(url!) : null,
  child: url?.isNotEmpty == true
      ? null
      : Icon(Icons.person_outline, size: radius),
);

class _ExpandablePostText extends StatelessWidget {
  const _ExpandablePostText({required this.body});
  final String body;
  @override
  Widget build(BuildContext context) => Text(
    body,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      height: 1.25,
    ),
  );
}

class _ProjectComments extends StatefulWidget {
  const _ProjectComments({
    required this.post,
    required this.repo,
    this.initialCommentId,
  });
  final String? initialCommentId;
  final BulletinPost post;
  final ProjectBulletinRepo repo;
  @override
  State<_ProjectComments> createState() => _ProjectCommentsState();
}

class _ProjectCommentsState extends State<_ProjectComments> {
  final _text = ConversationController();
  late var _future = widget.repo.comments(widget.post.id);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving || _text.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repo.comment(widget.post.id, _text.payload);
      if (mounted) {
        setState(() {
          _text.clear();
          _future = widget.repo.comments(widget.post.id);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not add comment. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 550),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Comments',
                    style: TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: AppTypography.pageTitleSize,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close comments',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Could not load comments.');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snapshot.data!;
                  for (final c in comments) {
                    _text.remember(c.userId, c.authorLabel, c.authorUsername);
                  }
                  final selected = comments
                      .where((item) => item.id == widget.initialCommentId)
                      .firstOrNull;
                  Widget commentTile(dynamic c, {bool notified = false}) =>
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        tileColor: notified ? AppColors.primaryTint : null,
                        leading: _avatar(c.authorAvatarUrl, 16),
                        title: Text(
                          c.authorLabel,
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConversationBody(c.body),
                            TextButton(
                              onPressed: () =>
                                  _text.replyTo(c.id, c.authorLabel, c.body),
                              child: const Text('Reply'),
                            ),
                          ],
                        ),
                        trailing: FlowerReactionButton(
                          target: FlowerTarget.collaborationComment,
                          targetId: c.id,
                        ),
                      );
                  return ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      if (selected != null) ...[
                        const Text(
                          'Notified reply',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        commentTile(selected, notified: true),
                        const Divider(),
                      ],
                      Text(
                        widget.post.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTypography.sectionTitleSize,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.post.body),
                      for (final image in widget.post.imageUrls)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ProtectedImage.network(
                            image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('Image unavailable'),
                          ),
                        ),
                      const Divider(),
                      if (comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No comments yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      for (final c in comments)
                        if (c.id != selected?.id) commentTile(c),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ConversationComposer(
              controller: _text,
              child: TextField(
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                controller: _text,
                focusNode: _text.focusNode,
                enabled: !_saving,
                maxLength: 4000,
                maxLines: null,
                minLines: 5,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                ),
                decoration: const InputDecoration(
                  hintText: 'Write a comment…',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 160,
                height: 44,
                child: FilledButton(
                  onPressed: _saving ? null : _send,
                  child: Text(_saving ? 'Posting…' : 'Comment'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InlineForumPostEditor extends StatefulWidget {
  const _InlineForumPostEditor({
    super.key,
    required this.post,
    required this.onCancel,
    required this.onSave,
    required this.pickImage,
    required this.onExpand,
  });
  final BulletinPost post;
  final VoidCallback onCancel;
  final Future<bool> Function(String, String, String, List<String>) onSave;
  final Future<String?> Function() pickImage;
  final ValueChanged<String> onExpand;
  @override
  State<_InlineForumPostEditor> createState() => _InlineForumPostEditorState();
}

class _InlineForumPostEditorState extends State<_InlineForumPostEditor>
    with AutomaticKeepAliveClientMixin {
  late final _title = TextEditingController(text: widget.post.title);
  late final _body = TextEditingController(text: widget.post.body);
  late String _category = widget.post.category;
  late final List<String> _images = List.from(widget.post.imageUrls);
  bool _saving = false;
  String? _error;
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = 'Add a title and message.');
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(
      _title.text.trim(),
      _body.text.trim(),
      _category,
      List.from(_images),
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _attach() async {
    if (_saving) return;
    if (_images.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum of two photos per post. Remove one to add another.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final url = await widget.pickImage();
      if (mounted && url != null) setState(() => _images.add(url));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    counterText: '',
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD0D0D0)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD0D0D0)),
    ),
  );
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _avatar(widget.post.authorAvatarUrl, 12),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.post.authorLabel,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontWeight: FontWeight.w500,
                    fontSize: AppTypography.bodySize,
                  ),
                ),
              ),
              const Text(
                'Editing post',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: AppMetrics.controlHeight,
            child: IgnorePointer(
              ignoring: _saving,
              child: ProjectChipMenu(
                value: _category,
                hint: 'Post category',
                options: projectPostCategories,
                showError: false,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
                onSelected: (v) => setState(() => _category = v),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            controller: _title,
            enabled: !_saving,
            maxLength: 160,
            decoration: _decoration('Post title'),
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            controller: _body,
            enabled: !_saving,
            minLines: 5,
            maxLines: null,
            maxLength: 10000,
            decoration: _decoration('Message'),
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
            ),
          ),
          if (_images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final photoSize = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final url in _images)
                        SizedBox(
                          key: ValueKey('inline-photo-$url'),
                          width: photoSize,
                          height: photoSize,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: InkWell(
                                  onTap: () => widget.onExpand(url),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ProtectedImage.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image_outlined),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  tooltip: 'Remove image from post',
                                  onPressed: _saving
                                      ? null
                                      : () =>
                                            setState(() => _images.remove(url)),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: Colors.red,
                fontSize: AppTypography.helperSize,
              ),
            ),
          const SizedBox(height: AppMetrics.labelGap),
          Row(
            key: const ValueKey('forum-edit-actions'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Add image to post',
                onPressed: _saving ? null : _attach,
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _green,
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(72, 36)),
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  minimumSize: const Size(76, 36),
                ),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
