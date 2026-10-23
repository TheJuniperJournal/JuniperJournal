import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class CollaboratorsSheet extends StatefulWidget {
  final String projectId;
  final String projectName;
  final bool isOwner;
  final String? ownerUserId;

  const CollaboratorsSheet({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.isOwner,
    this.ownerUserId,
  });

  @override
  State<CollaboratorsSheet> createState() => _CollaboratorsSheetState();
}

class _CollaboratorsSheetState extends State<CollaboratorsSheet> {
  final _projectsRepo = ProjectsRepo();
  final _friendsRepo = FriendsRepo();
  final _usersRepo = UsersRepo();

  bool _isLoading = true;
  UserProfile? _ownerProfile;
  List<UserProfile> _collaborators = [];
  List<UserProfile> _friends = [];
  Set<String> _pendingInviteUserIds = {};
  Set<String> _collaboratorUserIds = {};
  final Map<String, bool> _removingById = {};
  final Map<String, bool> _invitingById = {};

  String? get _currentUserId => AuthService.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final futures = <Future>[
      _projectsRepo.getProjectCollaborators(projectId: widget.projectId),
      if (widget.ownerUserId != null)
        _usersRepo.getProfilesByIds([widget.ownerUserId!]),
      if (widget.isOwner) ...[
        _friendsRepo.getFriends(),
        _projectsRepo.getPendingOutgoingInvites(projectId: widget.projectId),
      ],
    ];

    final results = await Future.wait(futures);
    if (!mounted) return;

    int i = 0;
    final collaborators = results[i++] as List<UserProfile>;

    UserProfile? ownerProfile;
    if (widget.ownerUserId != null) {
      final ownerProfiles = results[i++] as List<UserProfile>;
      ownerProfile = ownerProfiles.isNotEmpty ? ownerProfiles.first : null;
    }

    final friends = widget.isOwner
        ? (results[i++] as List<UserProfile>?) ?? []
        : <UserProfile>[];
    final pendingIds = widget.isOwner
        ? (results[i++] as Set<String>)
        : <String>{};

    setState(() {
      _ownerProfile = ownerProfile;
      _collaborators = collaborators;
      _collaboratorUserIds = collaborators.map((c) => c.id).toSet();
      _friends = friends;
      _pendingInviteUserIds = pendingIds;
      _isLoading = false;
    });
  }

  Future<void> _invite(UserProfile friend) async {
    setState(() => _invitingById[friend.id] = true);
    final ok = await _projectsRepo.inviteCollaborator(
      projectId: widget.projectId,
      userId: friend.id,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _pendingInviteUserIds.add(friend.id));
    } else {
      showTopSnackBar(context, 'Failed to send invite', isError: true);
    }
    setState(() => _invitingById.remove(friend.id));
  }

  Future<void> _remove(UserProfile collaborator) async {
    setState(() => _removingById[collaborator.id] = true);
    final ok = await _projectsRepo.removeCollaborator(
      projectId: widget.projectId,
      userId: collaborator.id,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _collaborators.removeWhere((c) => c.id == collaborator.id);
        _collaboratorUserIds.remove(collaborator.id);
      });
    } else {
      showTopSnackBar(context, 'Failed to remove collaborator', isError: true);
    }
    setState(() => _removingById.remove(collaborator.id));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Collaborators',
                  style: TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    fontSize: AppTypography.sectionTitleSize,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: [
                          _buildCurrentCollaboratorsSection(),
                          if (widget.isOwner) ...[
                            const SizedBox(height: AppMetrics.fieldGap),
                            _buildInviteFriendsSection(),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentCollaboratorsSection() {
    // Exclude self from the displayed list
    final visibleCollaborators = _collaborators
        .where((c) => c.id != _currentUserId)
        .toList();

    final hasAnyone = _ownerProfile != null || visibleCollaborators.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Collaborators',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (!hasAnyone)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No collaborators yet.',
              style: TextStyle(color: Colors.black45),
            ),
          )
        else ...[
          // Owner row — always first, no remove button
          if (_ownerProfile != null)
            _CollaboratorTile(
              profile: _ownerProfile!,
              badge: 'owner',
              showRemove: false,
              isRemoving: false,
              onRemove: () {},
            ),
          // Accepted collaborators (excluding self)
          ...visibleCollaborators.map(
            (c) => _CollaboratorTile(
              profile: c,
              badge: null,
              showRemove: widget.isOwner,
              isRemoving: _removingById[c.id] == true,
              onRemove: () => _remove(c),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInviteFriendsSection() {
    final invitableFriends = _friends
        .where(
          (f) =>
              !_collaboratorUserIds.contains(f.id) &&
              f.id != widget.ownerUserId,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invite a Friend',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (invitableFriends.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No friends available to invite.',
              style: TextStyle(color: Colors.black45),
            ),
          )
        else
          ...invitableFriends.map((friend) {
            final isPending = _pendingInviteUserIds.contains(friend.id);
            final isInviting = _invitingById[friend.id] == true;
            return _InviteFriendTile(
              profile: friend,
              isPending: isPending,
              isInviting: isInviting,
              onInvite: isPending ? null : () => _invite(friend),
            );
          }),
      ],
    );
  }
}

class _CollaboratorTile extends StatelessWidget {
  final UserProfile profile;
  final String? badge;
  final bool showRemove;
  final bool isRemoving;
  final VoidCallback onRemove;

  const _CollaboratorTile({
    required this.profile,
    required this.badge,
    required this.showRemove,
    required this.isRemoving,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryTint,
        backgroundImage:
            (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
            ? NetworkImage(profile.avatarUrl!)
            : null,
        child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
            ? const Icon(Icons.person_outline, color: AppColors.primary)
            : null,
      ),
      title: Row(
        children: [
          Text(
            profile.resolvedDisplayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: profile.username != null && profile.username!.isNotEmpty
          ? Text(
              '@${profile.username}',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
              ),
            )
          : null,
      trailing: showRemove
          ? isRemoving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    tooltip: 'Remove collaborator',
                    onPressed: onRemove,
                  )
          : null,
    );
  }
}

class _InviteFriendTile extends StatelessWidget {
  final UserProfile profile;
  final bool isPending;
  final bool isInviting;
  final VoidCallback? onInvite;

  const _InviteFriendTile({
    required this.profile,
    required this.isPending,
    required this.isInviting,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryTint,
        backgroundImage:
            (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
            ? NetworkImage(profile.avatarUrl!)
            : null,
        child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
            ? const Icon(Icons.person_outline, color: AppColors.primary)
            : null,
      ),
      title: Text(
        profile.resolvedDisplayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: profile.username != null && profile.username!.isNotEmpty
          ? Text(
              '@${profile.username}',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
              ),
            )
          : null,
      trailing: isInviting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isPending
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Invited',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : FilledButton(
              onPressed: onInvite,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Invite'),
            ),
    );
  }
}
