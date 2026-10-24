import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/item_action_menu.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/date_time_pickers.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';
import '../../../backend/db/repositories/projects_repo.dart';

class InteractiveTimelinePage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> tags;
  final bool isOwner;

  const InteractiveTimelinePage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.tags,
    this.isOwner = true,
  });

  @override
  State<InteractiveTimelinePage> createState() =>
      _InteractiveTimelinePageState();
}

class _InteractiveTimelinePageState extends State<InteractiveTimelinePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final List<Map<String, String>> _timeline = [];
  final _projectsRepo = ProjectsRepo();

  bool _isSaving = false;
  DateTime? _lastSavedAt;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final timeline = await _projectsRepo.getTimeline(widget.projectId);
    if (timeline != null && mounted) {
      setState(() {
        _timeline.clear();
        _timeline.addAll(timeline);
      });
    }
  }

  Future<void> _saveTimeline() async {
    setState(() => _isSaving = true);
    await _projectsRepo.updateTimeline(
      id: widget.projectId,
      timeline: _timeline,
    );
    if (!mounted) return;
    setState(() {
      _lastSavedAt = DateTime.now();
      _isSaving = false;
    });
  }

  String? get _savedLabel {
    if (_lastSavedAt == null) return null;
    final h = _lastSavedAt!.hour % 12 == 0 ? 12 : _lastSavedAt!.hour % 12;
    final m = _lastSavedAt!.minute.toString().padLeft(2, '0');
    final ampm = _lastSavedAt!.hour < 12 ? 'AM' : 'PM';
    return 'Saved $h:$m $ampm';
  }

  // Parses a stored date string (ISO yyyy-MM-dd or legacy "MMM d, yyyy")
  // and returns a short "M/d" label.
  String _shortDate(String raw) {
    DateTime? dt = DateTime.tryParse(raw);
    dt ??= DateFormat('MMM d, yyyy').tryParseStrict(raw);
    if (dt == null) return raw;
    return '${dt.month}/${dt.day}';
  }

  // Returns the time string as-is (user types it directly).
  String _displayTime(String? raw) => raw ?? '';

  List<Map<String, String>> get _sortedTimeline {
    final sorted = List<Map<String, String>>.from(_timeline);
    sorted.sort((a, b) {
      DateTime? da = DateTime.tryParse(a['date'] ?? '');
      da ??= DateFormat('MMM d, yyyy').tryParseStrict(a['date'] ?? '');
      DateTime? db = DateTime.tryParse(b['date'] ?? '');
      db ??= DateFormat('MMM d, yyyy').tryParseStrict(b['date'] ?? '');
      if (da == null || db == null) return 0;
      return _sortAscending ? da.compareTo(db) : db.compareTo(da);
    });
    return sorted;
  }

  void _showEventSheet({Map<String, String>? existing, int? editIndex}) {
    final isEditing = existing != null;

    final eventCtrl = TextEditingController(text: existing?['event'] ?? '');
    final descCtrl = TextEditingController(
      text: existing?['description'] ?? '',
    );
    final locationCtrl = TextEditingController(
      text: existing?['location'] ?? '',
    );

    // Parse existing start date/time
    DateTime startDate =
        DateTime.tryParse(existing?['startDate'] ?? '') ??
        DateTime.tryParse(existing?['date'] ?? '') ??
        _selectedDay;
    DateTime endDate =
        DateTime.tryParse(existing?['endDate'] ?? '') ?? startDate;

    bool allDay =
        existing?['allDay'] == 'true' ||
        (existing?['time'] ?? '').toLowerCase() == 'all day';

    int startHour = 8, startMinute = 0;
    String startAmPm = 'AM';
    int endHour = 9, endMinute = 0;
    String endAmPm = 'AM';

    void parseTime(String raw, void Function(int h, int m, String ap) cb) {
      final isPm = raw.toUpperCase().contains('PM');
      final digits = raw.replaceAll(RegExp(r'[^0-9:]'), '').trim();
      final parts = digits.split(':');
      final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
      cb(h.clamp(1, 12), m.clamp(0, 59), isPm ? 'PM' : 'AM');
    }

    if (!allDay) {
      parseTime(existing?['startTime'] ?? existing?['time'] ?? '', (h, m, ap) {
        startHour = h;
        startMinute = m;
        startAmPm = ap;
      });
      parseTime(existing?['endTime'] ?? '', (h, m, ap) {
        endHour = h;
        endMinute = m;
        endAmPm = ap;
      });
    }

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          String formatDate(DateTime d) =>
              '${d.month}/${d.day}/${d.year.toString().substring(2)}';
          String formatTime(int h, int m) =>
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

          Widget pillButton(String label, VoidCallback onTap) => AppTapTarget(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surfaceInput,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppMetrics.fieldGap),
                  Text(
                    isEditing ? 'Edit Event' : 'New Event',
                    style: const TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.sectionTitleSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppMetrics.fieldGap),

                  _sheetField(eventCtrl, 'Event Name', autofocus: !isEditing),
                  const SizedBox(height: AppMetrics.labelGap),
                  _sheetField(descCtrl, 'Description', optional: true),
                  const SizedBox(height: AppMetrics.labelGap),
                  _sheetField(locationCtrl, 'Location', optional: true),
                  const SizedBox(height: AppMetrics.labelGap),

                  // Start
                  const Text(
                    'Start',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      pillButton(formatDate(startDate), () async {
                        final result = await showWheelDatePicker(
                          sheetCtx,
                          startDate,
                        );
                        if (result != null) {
                          setSheetState(() => startDate = result);
                        }
                      }),
                      const SizedBox(width: 10),
                      if (!allDay)
                        pillButton(
                          formatTime(startHour, startMinute),
                          () async {
                            final result = await showWheelTimePicker(
                              sheetCtx,
                              startHour,
                              startMinute,
                              startAmPm,
                            );
                            if (result != null) {
                              setSheetState(() {
                                startHour = result['hour'] as int;
                                startMinute = result['minute'] as int;
                                startAmPm = result['amPm'] as String;
                              });
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // End
                  const Text(
                    'End',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      pillButton(formatDate(endDate), () async {
                        final result = await showWheelDatePicker(
                          sheetCtx,
                          endDate,
                        );
                        if (result != null) {
                          setSheetState(() => endDate = result);
                        }
                      }),
                      const SizedBox(width: 10),
                      if (!allDay)
                        pillButton(formatTime(endHour, endMinute), () async {
                          final result = await showWheelTimePicker(
                            sheetCtx,
                            endHour,
                            endMinute,
                            endAmPm,
                          );
                          if (result != null) {
                            setSheetState(() {
                              endHour = result['hour'] as int;
                              endMinute = result['minute'] as int;
                              endAmPm = result['amPm'] as String;
                            });
                          }
                        }),
                    ],
                  ),
                  const SizedBox(height: AppMetrics.labelGap),

                  // All Day toggle
                  Row(
                    children: [
                      const Text(
                        'All Day',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Switch.adaptive(
                        value: allDay,
                        activeTrackColor: AppColors.primary,
                        onChanged: (v) => setSheetState(() => allDay = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppMetrics.fieldGap),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        if (eventCtrl.text.trim().isEmpty) {
                          showTopSnackBar(context, 'Event name is required');
                          return;
                        }
                        final navigator = Navigator.of(sheetCtx);
                        final startTimeStr = allDay
                            ? 'All Day'
                            : '$startHour:${startMinute.toString().padLeft(2, '0')} $startAmPm';
                        final endTimeStr = allDay
                            ? ''
                            : '$endHour:${endMinute.toString().padLeft(2, '0')} $endAmPm';
                        final entry = {
                          'date': DateFormat('yyyy-MM-dd').format(startDate),
                          'startDate': DateFormat(
                            'yyyy-MM-dd',
                          ).format(startDate),
                          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
                          'time': startTimeStr,
                          'startTime': startTimeStr,
                          'endTime': endTimeStr,
                          'allDay': allDay.toString(),
                          'event': eventCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'location': locationCtrl.text.trim(),
                        };
                        setState(() {
                          if (isEditing && editIndex != null) {
                            _timeline[editIndex] = entry;
                          } else {
                            _timeline.add(entry);
                          }
                        });
                        await _saveTimeline();
                        navigator.pop();
                      },
                      child: Text(
                        isEditing ? 'Save Changes' : 'Add Event',
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.buttonSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(sheetCtx);
                          setState(() => _timeline.removeAt(editIndex!));
                          await _saveTimeline();
                          navigator.pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Delete Event',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.buttonSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetField(
    TextEditingController controller,
    String label, {
    bool optional = false,
    bool autofocus = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final displayLabel = optional ? '$label (Optional)' : label;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      minLines: label == 'Description' ? 5 : 1,
      maxLines: label == 'Description' ? null : 1,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: AppTypography.bodySize,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '',
        hintStyle: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: AppColors.hintText,
          fontSize: AppTypography.helperSize,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildEventRow(
    Map<String, String> item,
    bool isHighlighted,
    int originalIndex,
  ) {
    final cardBg = isHighlighted ? AppColors.primary : AppColors.surfaceInput;
    final titleColor = isHighlighted ? AppColors.white : AppColors.textPrimary;
    final subColor = isHighlighted
        ? AppColors.white.withValues(alpha: 0.7)
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: time + date
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _displayTime(item['time']),
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontWeight: FontWeight.w500,
                    fontSize: AppTypography.bodySize,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _shortDate(item['date'] ?? ''),
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item['event'] ?? '',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontWeight: FontWeight.w500,
                            fontSize: AppTypography.bodySize,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (widget.isOwner)
                        ItemActionMenu(
                          onEdit: () => _showEventSheet(
                            existing: item,
                            editIndex: originalIndex,
                          ),
                          onDelete: () async {
                            final confirmed = await showAppDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Delete Event'),
                                content: const Text(
                                  'Delete this timeline event?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Color(0xFFFD1212),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !mounted) return;
                            setState(() => _timeline.removeAt(originalIndex));
                            await _saveTimeline();
                          },
                        ),
                    ],
                  ),
                  if ((item['description'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item['description']!,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        color: subColor,
                      ),
                    ),
                  ],
                  if ((item['location'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: subColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item['location']!,
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.bodySize,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedTimeline;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final navigator = Navigator.of(context);
          if (widget.isOwner) await _saveTimeline();
          if (mounted) navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (widget.isOwner) await _saveTimeline();
              if (mounted) navigator.pop();
            },
          ),
          title: const Text('Project Timeline', style: AppTypography.pageTitle),
          centerTitle: true,
          bottom: _savedLabel == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(28),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        _savedLabel!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          fontSize: AppTypography.pageTitleSize,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // ── Weekly calendar strip ──────────────────────────────────────
            TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              calendarFormat: CalendarFormat.week,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              availableGestures: AvailableGestures.horizontalSwipe,
              pageAnimationEnabled: true,
              pageAnimationDuration: const Duration(milliseconds: 350),
              pageAnimationCurve: Curves.easeInOutCubic,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: AppColors.textPrimary,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: AppColors.textPrimary,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w500,
                ),
                weekendStyle: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // All non-builder decorations must be rectangle (not circle) so
              // that AnimatedContainer never tweens circle ↔ borderRadius.
              calendarStyle: const CalendarStyle(
                defaultDecoration: BoxDecoration(),
                weekendDecoration: BoxDecoration(),
                outsideDecoration: BoxDecoration(),
                disabledDecoration: BoxDecoration(),
                todayDecoration: BoxDecoration(),
                selectedDecoration: BoxDecoration(),
                defaultTextStyle: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: AppTypography.bodySize,
                ),
                weekendTextStyle: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: AppTypography.bodySize,
                ),
                outsideDaysVisible: false,
              ),
              calendarBuilders: CalendarBuilders(
                // Today: light green circle (uses borderRadius: 999 to avoid
                // the circle-shape / borderRadius conflict).
                todayBuilder: (context, day, focusedDay) => Container(
                  margin: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: AppTypography.bodySize,
                    ),
                  ),
                ),
                // Selected: scale-bounce animation into a green rounded rect.
                selectedBuilder: (context, day, focusedDay) =>
                    TweenAnimationBuilder<double>(
                      key: ValueKey(day),
                      tween: Tween(begin: 0.65, end: 1.0),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, _) => Transform.scale(
                        scale: scale,
                        child: Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: AppColors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: AppTypography.bodySize,
                            ),
                          ),
                        ),
                      ),
                    ),
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── Column header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 52,
                    child: Text(
                      'DATE',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Action Item',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  AppTapTarget(
                    onTap: () =>
                        setState(() => _sortAscending = !_sortAscending),
                    child: Icon(
                      _sortAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── Timeline list ──────────────────────────────────────────────
            Expanded(
              child: sorted.isEmpty
                  ? const Center(
                      child: Text(
                        'No timeline events yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : PageScrollWithFooter(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final item = sorted[index];
                          final originalIndex = _timeline.indexOf(item);
                          return _buildEventRow(
                            item,
                            index == 0,
                            originalIndex,
                          );
                        },
                      ),
                    ),
            ),

            // ── Add button (owner only) ─────────────────────────────────────
            if (widget.isOwner)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: AppTapTarget(
                  onTap: () => _showEventSheet(),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add to timeline',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.buttonSize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
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

/// Accepts only digits, auto-inserts a colon, and enforces valid 12-hour
/// times (no leading zero required): hours 1–12, minutes 00–59.
///
/// Hour boundary rules:
///   • First digit 2–9  → hour is that single digit; remaining digits are minutes.
///   • First digit 1    → wait for second digit:
///       - 10 / 11 / 12 → 2-digit hour, remaining digits are minutes.
///       - 13–19         → hour is "1", the second digit becomes minute-tens.
///   • First digit 0    → rejected (no leading zeros).
class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final first = int.parse(digits[0]);

    // Reject 0 as the first digit (no "0X" hours in 12-hour format)
    if (first == 0) return oldValue;

    // ── Determine hour / minute split ─────────────────────────────────────
    String hourPart;
    String minDigits;

    if (first == 1 && digits.length >= 2) {
      final twoDigit = int.parse(digits.substring(0, 2));
      if (twoDigit <= 12) {
        // Valid 2-digit hour (10 / 11 / 12)
        hourPart = digits.substring(0, 2);
        minDigits = digits.substring(2);
      } else {
        // 13–19: treat first digit as complete hour
        hourPart = digits[0];
        minDigits = digits.substring(1);
      }
    } else {
      // First digit 1 alone, or 2–9: single-digit hour
      hourPart = digits[0];
      minDigits = digits.isNotEmpty && digits.length > 1
          ? digits.substring(1)
          : '';
    }

    // ── Validate minute digits ────────────────────────────────────────────
    if (minDigits.length > 2) return oldValue;
    if (minDigits.isNotEmpty && int.parse(minDigits[0]) > 5) return oldValue;
    if (minDigits.length == 2 && int.parse(minDigits) > 59) return oldValue;

    // ── Format ────────────────────────────────────────────────────────────
    final formatted = minDigits.isEmpty ? hourPart : '$hourPart:$minDigits';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
