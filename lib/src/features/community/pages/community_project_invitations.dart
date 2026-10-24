import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:flutter/material.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../shared/styling/app_typography.dart';

class CommunityProjectInvitationsButton extends StatefulWidget {
  const CommunityProjectInvitationsButton({
    super.key,
    required this.communityId,
    this.compact = false,
  });
  final String communityId;
  final bool compact;
  @override
  State<CommunityProjectInvitationsButton> createState() =>
      _CommunityProjectInvitationsButtonState();
}

class _CommunityProjectInvitationsButtonState
    extends State<CommunityProjectInvitationsButton> {
  final _repo = ProjectsRepo();
  late Future<List<Map<String, dynamic>>> _requests = _load();
  Future<List<Map<String, dynamic>>> _load() =>
      _repo.getCommunityProjectInvitations(communityId: widget.communityId);
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.hasError || !snapshot.hasData)
            return const SizedBox.shrink();
          final count = (snapshot.data ?? [])
              .where((r) => r['status'] == 'pending')
              .length;
          if (widget.compact)
            return IconButton(
              tooltip: 'Project Invitations',
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(
                  Icons.mail_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              onPressed: () async {
                await pushAppRoute(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityProjectInvitationsPage(
                      communityId: widget.communityId,
                      repo: _repo,
                    ),
                  ),
                );
                if (mounted) setState(() => _requests = _load());
              },
            );
          return Center(
            child: TextButton.icon(
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.mail_outline),
              ),
              label: const Text('Project Invitations'),
              onPressed: () async {
                await pushAppRoute(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityProjectInvitationsPage(
                      communityId: widget.communityId,
                      repo: _repo,
                    ),
                  ),
                );
                if (mounted) setState(() => _requests = _load());
              },
            ),
          );
        },
      );
}

class CommunityProjectInvitationsPage extends StatefulWidget {
  const CommunityProjectInvitationsPage({
    super.key,
    required this.communityId,
    required this.repo,
  });
  final String communityId;
  final ProjectsRepo repo;
  @override
  State<CommunityProjectInvitationsPage> createState() =>
      _CommunityProjectInvitationsPageState();
}

class _CommunityProjectInvitationsPageState
    extends State<CommunityProjectInvitationsPage> {
  late Future<List<Map<String, dynamic>>> _requests = _load();
  bool _busy = false;
  Future<List<Map<String, dynamic>>> _load() => widget.repo
      .getCommunityProjectInvitations(communityId: widget.communityId);
  Future<void> _decide(String id, bool accept) async {
    setState(() => _busy = true);
    try {
      await widget.repo.reviewCommunityProjectInvitation(id, accept);
      if (mounted) setState(() => _requests = _load());
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not record this decision. It may have already been reviewed. Refresh and try again.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project Invitations')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _requests = _load()),
              child: const Text('Could not load invitations. Retry'),
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final requests = snapshot.data!;
        if (requests.isEmpty)
          return const Center(child: Text('No project invitations yet.'));
        return PageScrollWithFooter(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Review project requests on behalf of this community. One administrator’s decision applies to everyone.',
                style: AppTypography.helper,
              ),
              if (_busy) const LinearProgressIndicator(),
              for (final request in requests)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['project_name']?.toString() ?? 'Project',
                          style: AppTypography.sectionTitle,
                        ),
                        Text(
                          'By ${request['creator_name'] ?? 'Project creator'}',
                          style: AppTypography.helper,
                        ),
                        const SizedBox(height: 8),
                        Text(request['problem_statement']?.toString() ?? ''),
                        const SizedBox(height: 8),
                        Text('Status: ${request['status']}'),
                        if (request['decided_at'] != null)
                          Text(
                            'Reviewed by ${request['decided_by_name'] ?? 'an administrator'} · ${request['decided_at']}',
                            style: AppTypography.helper,
                          ),
                        if (request['status'] == 'pending')
                          Wrap(
                            spacing: 12,
                            children: [
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _decide(
                                        request['id'].toString(),
                                        false,
                                      ),
                                child: const Text('Decline'),
                              ),
                              FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _decide(
                                        request['id'].toString(),
                                        true,
                                      ),
                                child: const Text('Accept'),
                              ),
                            ],
                          ),
                      ],
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
