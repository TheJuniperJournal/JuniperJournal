import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../backend/db/models/project_activity_event.dart';
import '../../../backend/db/models/journal_entry.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../shared/widgets/app_navigation.dart';
import '../../../shared/widgets/user_avatar.dart';

class ProjectActivityFeed extends StatefulWidget {
  const ProjectActivityFeed({
    super.key,
    required this.projectId,
    required this.repo,
    required this.entries,
    required this.onOpen,
  });
  final String projectId;
  final ProjectsRepo repo;
  final List<JournalEntry> entries;
  final ValueChanged<ProjectActivityEvent> onOpen;
  @override
  State<ProjectActivityFeed> createState() => _ProjectActivityFeedState();
}

class _ProjectActivityFeedState extends State<ProjectActivityFeed> {
  late Future<List<ProjectActivityEvent>?> _activity;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProjectActivityFeed old) {
    super.didUpdateWidget(old);
    if (old.entries != widget.entries || old.projectId != widget.projectId)
      _load();
  }

  void _load() {
    _activity = widget.repo.getProjectActivity(widget.projectId, limit: 4);
  }

  List<ProjectActivityEvent> get _fallback =>
      widget.entries.map(ProjectActivityEvent.fromEntry).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<ProjectActivityEvent>?>(
        future: _activity,
        builder: (context, snapshot) {
          final items = snapshot.data ?? _fallback;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    snapshot.connectionState == ConnectionState.waiting
                        ? 'Loading activity…'
                        : 'No activity yet.',
                  ),
                ),
              for (final item in items.take(3))
                ActivityFeedTile(
                  key: ValueKey('activity-${item.id}'),
                  event: item,
                  onTap: () => widget.onOpen(item),
                ),
              if (items.length > 3)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final selected = await pushAppRoute<ProjectActivityEvent>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectActivityHistory(
                            projectId: widget.projectId,
                            repo: widget.repo,
                            fallback: _fallback,
                          ),
                        ),
                      );
                      if (selected != null && mounted) widget.onOpen(selected);
                    },
                    child: const Text('View more activity'),
                  ),
                ),
            ],
          );
        },
      );
}

class ActivityFeedTile extends StatelessWidget {
  const ActivityFeedTile({super.key, required this.event, required this.onTap});
  final ProjectActivityEvent event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserAvatar(avatarUrl: event.avatarUrl, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${event.actorName} ${event.description}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'MMM d, yyyy · h:mm a',
                      ).format(event.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF5DB075),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProjectActivityHistory extends StatefulWidget {
  const ProjectActivityHistory({
    super.key,
    required this.projectId,
    required this.repo,
    required this.fallback,
  });
  final String projectId;
  final ProjectsRepo repo;
  final List<ProjectActivityEvent> fallback;
  @override
  State<ProjectActivityHistory> createState() => _ProjectActivityHistoryState();
}

class _ProjectActivityHistoryState extends State<ProjectActivityHistory> {
  final _items = <ProjectActivityEvent>[];
  bool _loading = false, _more = true;
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    final rows = await widget.repo.getProjectActivity(
      widget.projectId,
      offset: _offset,
      limit: 15,
    );
    if (!mounted) return;
    setState(() {
      final next = rows ?? widget.fallback.skip(_offset).take(15).toList();
      final ids = _items.map((e) => e.id).toSet();
      _items.addAll(next.where((e) => ids.add(e.id)));
      _offset += next.length;
      _more = next.length == 15;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Project Activity'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final item in _items)
              ActivityFeedTile(
                key: ValueKey('activity-${item.id}'),
                event: item,
                onTap: () => Navigator.of(context).pop(item),
              ),
            if (_items.isEmpty && !_loading) const Text('No activity yet.'),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_more)
              TextButton(
                onPressed: _load,
                child: const Text('Load more activity'),
              ),
          ],
        ),
      ),
    ),
  );
}
