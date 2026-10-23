import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'journal_entry_view.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/shared/widgets/date_time_pickers.dart';

const _timelineGreen = Color(0xFF5DB075);
const _timelineText = Color(0xFF212525);
const _timelineMuted = Color(0xFFBCC1CD);
const _timelineCard = Colors.white;
const _timelineLine = Color(0xFFFAF9F9);

class ProjectTimelineTab extends StatefulWidget {
  const ProjectTimelineTab({
    super.key,
    required this.projectId,
    required this.isOwner,
    this.projectsRepo,
    this.initialEventId,
  });

  final String projectId;
  final bool isOwner;
  final ProjectsRepo? projectsRepo;
  final String? initialEventId;

  @override
  State<ProjectTimelineTab> createState() => _ProjectTimelineTabState();
}

class _ProjectTimelineTabState extends State<ProjectTimelineTab> {
  late final ProjectsRepo _projectsRepo;
  final _usersRepo = UsersRepo();
  final _weekController = PageController(initialPage: 10000);
  final List<_TimelineEvent> _events = [];
  final List<UserProfile> _members = [];
  final List<JournalEntry> _journalEntries = [];

  late DateTime _selectedDate;
  late DateTime _baseWeekStart;
  String? _currentUserId;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
    final now = DateTime.now();
    _selectedDate = DateUtils.dateOnly(now);
    _baseWeekStart = _startOfWeek(_selectedDate);
    _load();
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  bool _notificationOpened = false;

  Future<void> _load() async {
    try {
      if (!await _projectsRepo.canViewInternalProjectLogs(widget.projectId)) {
        if (mounted)
          setState(() {
            _isLoading = false;
            _loadFailed = true;
          });
        return;
      }
      final results = await Future.wait([
        _projectsRepo.getTimeline(widget.projectId),
        _projectsRepo.getProjectCollaborators(projectId: widget.projectId),
        _usersRepo.getCurrentUserProfile(),
        _projectsRepo.getJournalEntries(projectId: widget.projectId),
      ]);
      final timeline = results[0] as List<Map<String, String>>?;
      final collaborators = results[1] as List<UserProfile>;
      final profile = results[2] as UserProfile?;
      final journals = results[3] as List<JournalEntry>?;
      if (!mounted) return;

      final currentUser = AuthService.instance.currentUser;
      final currentProfile =
          profile ??
          (currentUser == null
              ? null
              : UserProfile(
                  id: currentUser.id,
                  displayName: currentUser.userMetadata?['display_name']
                      ?.toString(),
                  username:
                      currentUser.userMetadata?['username']?.toString() ??
                      currentUser.email,
                ));

      setState(() {
        _currentUserId = currentUser?.id ?? currentProfile?.id;
        _members
          ..clear()
          ..addAll([
            if (currentProfile != null) currentProfile,
            ...collaborators.where((member) => member.id != currentProfile?.id),
          ]);
        _journalEntries
          ..clear()
          ..addAll(journals ?? const []);
        _events
          ..clear()
          ..addAll((timeline ?? const []).map(_TimelineEvent.fromMap));
        _isLoading = false;
        _loadFailed = timeline == null || journals == null;
      });
      if (!_notificationOpened && widget.initialEventId != null) {
        _notificationOpened = true;
        final event = _events
            .where(
              (item) =>
                  item.id == widget.initialEventId ||
                  item.name == widget.initialEventId,
            )
            .firstOrNull;
        if (event != null)
          setState(() {
            _selectedDate = DateUtils.dateOnly(event.start);
            _baseWeekStart = _startOfWeek(_selectedDate);
          });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (event != null) {
            _openEvent(event);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This timeline event was removed or is no longer available.',
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Timeline load: $e');
      if (mounted)
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
    }
  }

  Future<void> _save() async {
    await _projectsRepo.updateTimeline(
      id: widget.projectId,
      timeline: _events.map((event) => event.toMap()).toList(),
    );
  }

  List<_TimelineEvent> get _selectedEvents {
    final events = _events
        .where((event) => DateUtils.isSameDay(event.start, _selectedDate))
        .toList();
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  Future<void> _openCreateEvent() async {
    if (!widget.isOwner) return;
    final event = await showAppModalBottomSheet<_TimelineEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTimelineEventSheet(
        selectedDate: _selectedDate,
        members: _members,
        currentUserId: _currentUserId,
        journalEntries: _journalEntries,
      ),
    );
    if (event == null || !mounted) return;

    setState(() => _events.add(event));
    await _save();
  }

  Future<void> _openEvent(_TimelineEvent event) async {
    final deleted = await showAppModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TimelineEventDetailSheet(
        event: event,
        canDelete: widget.isOwner,
        onOpenJournal: event.journalEntryId == null
            ? null
            : () {
                Navigator.of(sheetContext).pop(false);
                _openLinkedJournal(event);
              },
      ),
    );
    if (deleted != true || !mounted) return;

    setState(() => _events.removeWhere((item) => item.id == event.id));
    await _save();
  }

  Future<void> _openLinkedJournal(_TimelineEvent event) async {
    try {
      final entries = await _projectsRepo.getJournalEntries(
        projectId: widget.projectId,
      );
      final entry = entries
          ?.where((item) => item.id == event.journalEntryId)
          .firstOrNull;
      final project = await _projectsRepo.getProjectById(widget.projectId);
      if (!mounted) return;
      if (entry == null || project == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This journal entry is no longer available.'),
          ),
        );
        return;
      }
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => JournalEntryView(
            entry: entry,
            project: project,
            projectsRepo: _projectsRepo,
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the journal entry. Please try again.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load the timeline.'),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadFailed = false;
                });
                _load();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final events = _selectedEvents;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 150,
          child: SizedBox(
            height: 76,
            child: PageView.builder(
              controller: _weekController,
              onPageChanged: (page) {
                final offset = page - 10000;
                setState(() {
                  final currentWeek = _baseWeekStart.add(
                    Duration(days: offset * 7),
                  );
                  if (!_isInWeek(_selectedDate, currentWeek)) {
                    _selectedDate = currentWeek;
                  }
                });
              },
              itemBuilder: (context, page) {
                final weekStart = _baseWeekStart.add(
                  Duration(days: (page - 10000) * 7),
                );
                return _WeekCalendar(
                  weekStart: weekStart,
                  selectedDate: _selectedDate,
                  onSelected: (date) => setState(() => _selectedDate = date),
                );
              },
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 20,
          top: 227,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
        ),
        const Positioned(
          left: 38,
          top: 240,
          child: Text(
            'TIME',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _timelineMuted,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Positioned(
          left: 107,
          top: 240,
          child: Text(
            'Action Item',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _timelineMuted,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Positioned(
          left: 97,
          top: 278,
          bottom: 76,
          child: Container(width: 2, color: _timelineLine),
        ),
        if (widget.isOwner)
          Positioned(
            right: 20,
            top: 232,
            child: TextButton.icon(
              onPressed: _openCreateEvent,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add to timeline'),
            ),
          ),
        Positioned(
          left: 38,
          top: 278,
          right: 36,
          bottom: 70,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final event in events)
                _TimelineEventRow(
                  event: event,
                  currentUserId: _currentUserId,
                  onTap: () => _openEvent(event),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({
    required this.weekStart,
    required this.selectedDate,
    required this.onSelected,
  });

  final DateTime weekStart;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(21, 6, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var index = 0; index < 7; index++)
            Builder(
              builder: (context) {
                final date = DateUtils.dateOnly(
                  weekStart.add(Duration(days: index)),
                );
                final selected = DateUtils.isSameDay(date, selectedDate);
                return GestureDetector(
                  onTap: () => onSelected(date),
                  child: Container(
                    width: 40,
                    height: 57,
                    decoration: BoxDecoration(
                      color: selected ? _timelineGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          days[index],
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: selected ? Colors.white : _timelineMuted,
                            fontSize: AppTypography.helperSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: selected ? Colors.white : _timelineText,
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({
    required this.event,
    required this.currentUserId,
    required this.onTap,
  });

  final _TimelineEvent event;
  final String? currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assignedToCurrent =
        currentUserId != null && event.assigneeIds.contains(currentUserId);
    final cardColor = assignedToCurrent ? _timelineGreen : _timelineCard;
    final textColor = assignedToCurrent ? Colors.white : _timelineText;
    final mutedColor = assignedToCurrent ? Colors.white : _timelineText;
    final iconColor = assignedToCurrent
        ? Colors.white
        : const Color(0xFF8D84A6);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 43,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    event.allDay ? 'All' : _timeOnly(event.start),
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: _timelineText,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${event.start.month}/${event.start.day}',
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: _timelineMuted,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 137),
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(
                    color: assignedToCurrent
                        ? _timelineGreen
                        : const Color(0xFFE5E5E5),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: textColor,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: _EllipsisIcon(color: iconColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (event.description.isNotEmpty)
                      Text(
                        event.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: textColor,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (event.location.isNotEmpty) ...[
                      const SizedBox(height: AppMetrics.fieldGap),
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: _LocationIcon(color: iconColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                color: mutedColor,
                                fontSize: AppTypography.helperSize,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.assigneeNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        event.assigneeNames.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: mutedColor,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
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

class _CreateTimelineEventSheet extends StatefulWidget {
  const _CreateTimelineEventSheet({
    required this.selectedDate,
    required this.members,
    required this.currentUserId,
    required this.journalEntries,
  });

  final DateTime selectedDate;
  final List<UserProfile> members;
  final String? currentUserId;
  final List<JournalEntry> journalEntries;

  @override
  State<_CreateTimelineEventSheet> createState() =>
      _CreateTimelineEventSheetState();
}

class _CreateTimelineEventSheetState extends State<_CreateTimelineEventSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  int _startHour = 8;
  int _startMinute = 0;
  String _startAmPm = 'AM';
  int _endHour = 9;
  int _endMinute = 0;
  String _endAmPm = 'AM';
  bool _allDay = false;
  final Set<String> _assigneeIds = {};
  JournalEntry? _linkedJournal;

  @override
  void initState() {
    super.initState();
    _startDate = widget.selectedDate;
    _endDate = widget.selectedDate;
    if (widget.currentUserId != null) _assigneeIds.add(widget.currentUserId!);
    if (_assigneeIds.isEmpty && widget.members.isNotEmpty) {
      _assigneeIds.add(widget.members.first.id);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final result = await showWheelDatePicker(context, _startDate);
    if (result == null || !mounted) return;
    setState(() {
      _startDate = result;
      if (_endDate.isBefore(_startDate)) _endDate = result;
    });
  }

  Future<void> _pickEndDate() async {
    final result = await showWheelDatePicker(context, _endDate);
    if (result == null || !mounted) return;
    setState(() => _endDate = result);
  }

  Future<void> _pickStartTime() async {
    final result = await showWheelTimePicker(
      context,
      _startHour,
      _startMinute,
      _startAmPm,
    );
    if (result == null || !mounted) return;
    setState(() {
      _startHour = result['hour'] as int;
      _startMinute = result['minute'] as int;
      _startAmPm = result['amPm'] as String;
    });
  }

  Future<void> _pickEndTime() async {
    final result = await showWheelTimePicker(
      context,
      _endHour,
      _endMinute,
      _endAmPm,
    );
    if (result == null || !mounted) return;
    setState(() {
      _endHour = result['hour'] as int;
      _endMinute = result['minute'] as int;
      _endAmPm = result['amPm'] as String;
    });
  }

  void _create() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final assignees = widget.members
        .where((member) => _assigneeIds.contains(member.id))
        .toList();

    Navigator.of(context).pop(
      _TimelineEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        start: _combine(_startDate, _startHour, _startMinute, _startAmPm),
        end: _combine(_endDate, _endHour, _endMinute, _endAmPm),
        allDay: _allDay,
        assigneeIds: assignees.map((member) => member.id).toList(),
        assigneeNames: assignees
            .map((member) => member.resolvedDisplayName)
            .toList(),
        journalEntryId: _linkedJournal?.id,
        journalEntryTitle: _linkedJournal?.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: 724,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: Stack(
                  children: [
                    const Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 23,
                        child: Divider(
                          height: 1,
                          thickness: 2,
                          color: Color(0xFF707070),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: IconButton(
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const SizedBox(
                          width: 18,
                          height: 18,
                          child: _CloseIcon(),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Create Event',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.primary,
                          fontSize: AppTypography.buttonSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppMetrics.labelGap),
              _TimelineField(label: 'Event Name', controller: _nameController),
              const SizedBox(height: 10),
              _TimelineField(
                label: 'Description',
                optional: true,
                controller: _descriptionController,
              ),
              const SizedBox(height: 10),
              _TimelineField(
                label: 'Location',
                optional: true,
                controller: _locationController,
              ),
              const SizedBox(height: 10),
              const _SheetLabel('Start'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SheetLabel('Date'),
                      const SizedBox(height: 6),
                      _DateTimePill(
                        label: _shortInputDate(_startDate),
                        onTap: _pickStartDate,
                      ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  if (!_allDay)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SheetLabel('Time'),
                        const SizedBox(height: 6),
                        _DateTimePill(
                          label: _shortInputTime(_startHour, _startMinute),
                          onTap: _pickStartTime,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const _SheetLabel('End'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SheetLabel('Date'),
                      const SizedBox(height: 6),
                      _DateTimePill(
                        label: _shortInputDate(_endDate),
                        onTap: _pickEndDate,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  if (!_allDay)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SheetLabel('Time'),
                        const SizedBox(height: 6),
                        _DateTimePill(
                          label: _shortInputTime(_endHour, _endMinute),
                          onTap: _pickEndTime,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const _SheetLabel('All Day'),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => setState(() => _allDay = !_allDay),
                    child: _AllDayToggle(value: _allDay),
                  ),
                ],
              ),
              const SizedBox(height: AppMetrics.labelGap),
              const _SheetLabel('Assign To'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final member in widget.members)
                    _AssigneeChip(
                      member: member,
                      selected: _assigneeIds.contains(member.id),
                      onTap: () {
                        setState(() {
                          if (!_assigneeIds.add(member.id) &&
                              _assigneeIds.length > 1) {
                            _assigneeIds.remove(member.id);
                          }
                        });
                      },
                    ),
                  const Text(
                    '+  Add People',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.primary,
                      fontSize: AppTypography.buttonSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SheetLabel('Link Journal Entry'),
              const SizedBox(height: 12),
              JournalEntryLinkSelector(
                entries: widget.journalEntries,
                selected: _linkedJournal,
                onSelected: (entry) => setState(() => _linkedJournal = entry),
              ),
              const SizedBox(height: 45),
              Center(
                child: GestureDetector(
                  onTap: _create,
                  child: Container(
                    width: 91,
                    height: 31,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _timelineGreen,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'Create',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: Colors.white,
                        fontSize: AppTypography.buttonSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

class _TimelineEventDetailSheet extends StatelessWidget {
  const _TimelineEventDetailSheet({
    required this.event,
    required this.canDelete,
    this.onOpenJournal,
  });
  final _TimelineEvent event;
  final bool canDelete;
  final VoidCallback? onOpenJournal;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 560,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 40),
                const Expanded(
                  child: Text(
                    'Timeline Event',
                    textAlign: TextAlign.center,
                    style: AppTypography.sectionTitle,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Icon(Icons.event_outlined, size: 36, color: _timelineGreen),
            const SizedBox(height: 12),
            Text(
              event.name,
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle,
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                event.description,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _timelineGreen.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _EventPreviewField(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: _longDate(event.start),
                  ),
                  const SizedBox(height: 16),
                  _EventPreviewField(
                    icon: Icons.schedule,
                    label: 'Time',
                    value: event.allDay
                        ? 'All Day'
                        : '${_timeWithAmPm(event.start)} – ${_timeWithAmPm(event.end)}',
                  ),
                  const SizedBox(height: 16),
                  _EventPreviewField(
                    icon: Icons.people_outline,
                    label: 'Assigned to',
                    value: event.assigneeNames.isEmpty
                        ? 'Unassigned'
                        : event.assigneeNames.join(', '),
                  ),
                  const SizedBox(height: 16),
                  _EventPreviewField(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: event.location.isEmpty
                        ? 'No location'
                        : event.location,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onOpenJournal,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Linked Journal Entry',
                          style: AppTypography.helper,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.journalEntryTitle ?? 'No linked journal entry',
                          style: AppTypography.body,
                        ),
                      ],
                    ),
                  ),
                  if (onOpenJournal != null) const Icon(Icons.arrow_forward),
                ],
              ),
            ),
            if (canDelete) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Event'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _EventPreviewField extends StatelessWidget {
  const _EventPreviewField({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: _timelineGreen),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.helper),
            const SizedBox(height: 4),
            Text(value, style: AppTypography.body),
          ],
        ),
      ),
    ],
  );
}

class _TimelineField extends StatelessWidget {
  const _TimelineField({
    required this.label,
    required this.controller,
    this.optional = false,
  });

  final String label;
  final bool optional;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textPrimary,
              fontSize: AppTypography.helperSize,
              fontWeight: FontWeight.w500,
            ),
            children: [
              if (optional)
                const TextSpan(
                  text: ' (Optional)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: 44),
          child: TextField(
            controller: controller,
            minLines: label.toLowerCase().contains('description') ? 4 : 1,
            maxLines: label.toLowerCase().contains('description') ? null : 1,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _timelineGreen),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _timelineGreen),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: AppColors.textPrimary,
        fontSize: AppTypography.helperSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _DateTimePill extends StatelessWidget {
  const _DateTimePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 33,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: _timelineGreen),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.captionSize,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 6),
            const SizedBox(width: 12, height: 12, child: _ChevronDownIcon()),
          ],
        ),
      ),
    );
  }
}

class _AllDayToggle extends StatelessWidget {
  const _AllDayToggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 28,
      decoration: BoxDecoration(
        color: value ? _timelineGreen : const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: AnimatedAlign(
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.all(1),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssigneeChip extends StatelessWidget {
  const _AssigneeChip({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final UserProfile member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black.withValues(alpha: .1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: selected ? null : Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(profile: member, size: 20),
            const SizedBox(width: 10),
            Text(
              member.resolvedDisplayName,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodySize,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 10),
              const SizedBox(width: 10, height: 10, child: _CloseDarkIcon()),
            ],
          ],
        ),
      ),
    );
  }
}

class JournalEntryLinkSelector extends StatefulWidget {
  const JournalEntryLinkSelector({
    super.key,
    required this.entries,
    required this.selected,
    required this.onSelected,
    this.selectable = true,
  });
  final List<JournalEntry> entries;
  final JournalEntry? selected;
  final ValueChanged<JournalEntry?> onSelected;
  final bool selectable;
  @override
  State<JournalEntryLinkSelector> createState() =>
      _JournalEntryLinkSelectorState();
}

class _JournalEntryLinkSelectorState extends State<JournalEntryLinkSelector> {
  final _fieldKey = GlobalKey();
  Future<void> _open() async {
    if (!widget.selectable || widget.entries.isEmpty) return;
    final box = _fieldKey.currentContext!.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final selected = await showMenu<JournalEntry>(
      context: context,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      constraints: BoxConstraints.tightFor(width: rect.width),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(rect.left, rect.bottom + 4, rect.width, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final entry in widget.entries)
          PopupMenuItem(
            value: entry,
            height: 36,
            child: Text(
              entry.title,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
                color: _timelineText,
              ),
            ),
          ),
      ],
    );
    if (selected != null && mounted) widget.onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.selectable,
    child: GestureDetector(
      key: _fieldKey,
      onTap: widget.selectable ? _open : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 39,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: widget.entries.isEmpty
                ? const Color(0xFFE8E8E8)
                : _timelineGreen,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 22, child: _JournalIcon()),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                widget.selected?.title ??
                    (widget.entries.isEmpty
                        ? 'No journal entries'
                        : 'Select journal entry'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.helperSize,
                ),
              ),
            ),
            if (widget.selectable)
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: _timelineMuted,
              ),
          ],
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.size});

  final UserProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: _timelineGreen.withValues(alpha: .2),
        alignment: Alignment.center,
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(avatarUrl, fit: BoxFit.cover)
            : Text(
                profile.resolvedDisplayName.characters.first.toUpperCase(),
                style: TextStyle(
                  color: _timelineGreen,
                  fontSize: size * .45,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.start,
    required this.end,
    required this.allDay,
    required this.assigneeIds,
    required this.assigneeNames,
    this.journalEntryId,
    this.journalEntryTitle,
  });

  final String id;
  final String name;
  final String description;
  final String location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final List<String> assigneeIds;
  final List<String> assigneeNames;
  final String? journalEntryId;
  final String? journalEntryTitle;

  factory _TimelineEvent.fromMap(Map<String, dynamic> map) {
    final date =
        DateTime.tryParse(map['startDate']?.toString() ?? '') ??
        DateTime.tryParse(map['date']?.toString() ?? '') ??
        DateTime.now();
    final start =
        DateTime.tryParse(map['start']?.toString() ?? '') ??
        _dateWithParsedTime(
          date,
          map['startTime']?.toString() ?? map['time']?.toString(),
        );
    return _TimelineEvent(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: map['name']?.toString() ?? map['event']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      start: start,
      end:
          DateTime.tryParse(map['end']?.toString() ?? '') ??
          _dateWithParsedTime(
            DateTime.tryParse(map['endDate']?.toString() ?? '') ?? date,
            map['endTime']?.toString(),
          ),
      allDay: map['allDay']?.toString() == 'true',
      assigneeIds: _stringList(map['assigneeIds']),
      assigneeNames: _stringList(map['assigneeNames']),
      journalEntryId: map['journalEntryId']?.toString(),
      journalEntryTitle: map['journalEntryTitle']?.toString(),
    );
  }

  Map<String, String> toMap() {
    return {
      'id': id,
      'name': name,
      'event': name,
      'description': description,
      'location': location,
      'date': DateFormat('yyyy-MM-dd').format(start),
      'startDate': DateFormat('yyyy-MM-dd').format(start),
      'endDate': DateFormat('yyyy-MM-dd').format(end),
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'time': allDay ? 'All Day' : _timeWithAmPm(start),
      'startTime': allDay ? 'All Day' : _timeWithAmPm(start),
      'endTime': allDay ? '' : _timeWithAmPm(end),
      'allDay': allDay.toString(),
      'assigneeIds': assigneeIds.join('|'),
      'assigneeNames': assigneeNames.join('|'),
      if (journalEntryId != null) 'journalEntryId': journalEntryId!,
      if (journalEntryTitle != null) 'journalEntryTitle': journalEntryTitle!,
    };
  }
}

DateTime _startOfWeek(DateTime date) {
  final day = DateUtils.dateOnly(date);
  return day.subtract(Duration(days: day.weekday % 7));
}

bool _isInWeek(DateTime date, DateTime weekStart) {
  final day = DateUtils.dateOnly(date);
  final start = DateUtils.dateOnly(weekStart);
  final end = start.add(const Duration(days: 7));
  return !day.isBefore(start) && day.isBefore(end);
}

String _shortInputDate(DateTime date) {
  final year = date.year.toString().substring(2);
  return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/$year';
}

String _shortInputTime(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

DateTime _combine(DateTime date, int hour, int minute, String amPm) {
  var h = hour % 12;
  if (amPm == 'PM') h += 12;
  return DateTime(date.year, date.month, date.day, h, minute);
}

String _timeOnly(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '$hour:${date.minute.toString().padLeft(2, '0')}';
}

String _timeWithAmPm(DateTime date) {
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '${_timeOnly(date)} $suffix';
}

String _longDate(DateTime date) => DateFormat('MMMM d, yyyy').format(date);

DateTime _dateWithParsedTime(DateTime date, String? raw) {
  if (raw == null || raw.toLowerCase() == 'all day') return date;
  final match = RegExp(
    r'(\d{1,2}):(\d{2})\s*(AM|PM)?',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return date;
  final hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final minute = int.tryParse(match.group(2) ?? '') ?? 0;
  final amPm = (match.group(3) ?? 'AM').toUpperCase();
  return _combine(date, hour, minute, amPm);
}

List<String> _stringList(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  if (value is String && value.isNotEmpty) return value.split('|');
  return const [];
}

abstract class _LinePainter extends CustomPainter {
  _LinePainter(this.color);

  final Color color;

  Paint get stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LocationIcon extends StatelessWidget {
  const _LocationIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _LocationPainter(color));
}

class _LocationPainter extends _LinePainter {
  _LocationPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .5, size.height * .95)
      ..cubicTo(
        size.width * .2,
        size.height * .58,
        size.width * .17,
        size.height * .38,
        size.width * .28,
        size.height * .2,
      )
      ..cubicTo(
        size.width * .4,
        0,
        size.width * .6,
        0,
        size.width * .72,
        size.height * .2,
      )
      ..cubicTo(
        size.width * .83,
        size.height * .38,
        size.width * .8,
        size.height * .58,
        size.width * .5,
        size.height * .95,
      );
    canvas.drawPath(path, stroke);
    canvas.drawCircle(
      size.center(Offset(0, -size.height * .16)),
      size.width * .12,
      stroke,
    );
  }
}

class _EllipsisIcon extends StatelessWidget {
  const _EllipsisIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _EllipsisPainter(color));
}

class _EllipsisPainter extends CustomPainter {
  _EllipsisPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final y in [.3, .5, .7]) {
      canvas.drawCircle(Offset(size.width / 2, size.height * y), 1.7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CloseIcon extends StatelessWidget {
  const _CloseIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ClosePainter(_timelineGreen));
}

class _CloseDarkIcon extends StatelessWidget {
  const _CloseDarkIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ClosePainter(Colors.black));
}

class _ClosePainter extends _LinePainter {
  _ClosePainter(super.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), stroke);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), stroke);
  }
}

class _ChevronDownIcon extends StatelessWidget {
  const _ChevronDownIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ChevronDownPainter());
}

class _ChevronDownPainter extends _LinePainter {
  _ChevronDownPainter() : super(_timelineGreen);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * .2, size.height * .35),
      Offset(size.width * .5, size.height * .65),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height * .65),
      Offset(size.width * .8, size.height * .35),
      stroke,
    );
  }
}

class _JournalIcon extends StatelessWidget {
  const _JournalIcon();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _JournalPainter());
}

class _JournalPainter extends _LinePainter {
  _JournalPainter() : super(_timelineGreen);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .28, 0),
      Offset(size.width * .28, size.height * .28),
      stroke,
    );
  }
}
