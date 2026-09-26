import 'dart:async';
import 'package:flutter/material.dart';
import '../session_manager.dart';
import 'portal_webview_screen.dart';


class _TimeLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _TimeLabel({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final muted = isDark
        ? Colors.white.withOpacity(0.56)
        : const Color(0xFF77797D);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_rounded, size: 14, color: muted),
        const SizedBox(width: 5),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> timetable = [];
  List<Map<String, dynamic>> holidays = [];
  List<Map<String, dynamic>> attendance = [];

  bool isLoading = true;
  bool isGridView = false;

  String selectedDay = 'M';
  DateTime selectedDate = DateTime.now();

  final List<String> days = ['M', 'T', 'W', 'Th', 'F'];

  final Map<String, String> fullDayLabels = {
    'M': 'Monday',
    'T': 'Tuesday',
    'W': 'Wednesday',
    'Th': 'Thursday',
    'F': 'Friday',
  };

  final Map<String, String> dayNameMap = {
    'M': 'Monday',
    'T': 'Tuesday',
    'W': 'Wednesday',
    'Th': 'Thursday',
    'F': 'Friday',
  };

  // StudentSquare unified visual system.
  static const Color accent = Color(0xFF6376F5);
  static const Color healthy = Color(0xFF55C98A);
  static const Color warning = Color(0xFFE0B84F);
  static const Color danger = Color(0xFFE86B6B);

  static const Color darkBackground = Color(0xFF090A0B);
  static const Color darkSurface = Color(0xFF111315);
  static const Color darkSecondary = Color(0xFF181A1D);
  static const Color lightBackground = Color(0xFFF6F6F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSecondary = Color(0xFFEEEEEA);

  Timer? _calendarTimer;
  DateTime? _lastSyncedCalendarDate;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncToCurrentDate();

    // Keep the visible date/day correct even when the app remains open
    // across midnight. This is intentionally lightweight.
    _calendarTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _syncToCurrentDate();
    });

    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncToCurrentDate();
    }
  }

  bool _isWeekday(DateTime date) =>
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

  void _syncToCurrentDate({bool force = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final newDay = _isWeekday(today) ? days[today.weekday - 1] : '';

    if (!force &&
        _lastSyncedCalendarDate != null &&
        _lastSyncedCalendarDate!.year == today.year &&
        _lastSyncedCalendarDate!.month == today.month &&
        _lastSyncedCalendarDate!.day == today.day) {
      return;
    }

    _lastSyncedCalendarDate = today;

    if (!mounted) {
      selectedDate = today;
      selectedDay = newDay;
      return;
    }

    setState(() {
      selectedDate = today;
      selectedDay = newDay;
    });
  }

  Future<void> _loadData() async {
    try {
      final cachedTimetable = await SessionManager.getTimetable();
      final cachedHolidays = await SessionManager.getHolidays();
      final cachedAttendance = await SessionManager.getAttendance();

      if (!mounted) return;

      setState(() {
        timetable = cachedTimetable;
        holidays = cachedHolidays;
        attendance = cachedAttendance;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String? _getHolidayForSelectedDate() {
    final dateStr = _formatDate(selectedDate);

    for (final holiday in holidays) {
      if (holiday['date']?.toString() == dateStr) {
        return holiday['name']?.toString();
      }
    }

    return null;
  }

  Map<String, String> _parseDetails(
    String rawSubject,
    String rawTime, {
    String? rawRoom,
  }) {
    String subject = rawSubject.trim();
    String room = rawRoom?.trim() ?? '';
    String faculty = '';
    String batch = '';

    // Room may be stored as a separate field by the timetable scraper.
    // Accept the common field formats here so the UI does not depend on one
    // exact parser key. The dedicated room field always has priority.
    if (room.isEmpty) {
      for (final value in [
        rawRoom,
      ]) {
        final candidate = value?.trim() ?? '';
        if (candidate.isNotEmpty) {
          room = candidate;
          break;
        }
      }
    }

    try {
      if (rawSubject.contains(':')) {
        final parts = rawSubject.split(':');

        subject = parts[0].trim();

        if (parts.length > 1) {
          String secondPart = parts[1].trim();

          final roomMatch = RegExp(r'\(([^)]+)\)').firstMatch(secondPart);

          if (roomMatch != null) {
            final roomBlock = roomMatch.group(1)?.trim() ?? '';
            // Keep the complete room value. Previously C-304 became C.
            if (room.isEmpty && roomBlock.isNotEmpty) {
              room = roomBlock;
            }
            secondPart =
                secondPart.replaceAll(roomMatch.group(0)!, '').trim();
          }

          faculty = secondPart;
        }

        if (parts.length > 2) {
          batch = parts[2].replaceAll(RegExp(r'[()]'), '').trim();
        }
      } else {
        // Also support exports where room is embedded in the subject without
        // the faculty/batch colon structure.
        final roomMatch = RegExp(r'\(([^)]+)\)').firstMatch(rawSubject);
        if (room.isEmpty && roomMatch != null) {
          final roomBlock = roomMatch.group(1)?.trim() ?? '';
          if (_looksLikeRoom(roomBlock)) {
            room = roomBlock;
          }
        }
      }
    } catch (_) {
      subject = rawSubject.trim();
    }

    return {
      'subject': subject.isEmpty ? 'Subject' : subject,
      'faculty': faculty.isEmpty ? 'Faculty Name' : faculty,
      'batch': batch,
      'room': room.isEmpty ? 'N/A' : room,
      'time': rawTime.trim(),
    };
  }

  bool _looksLikeRoom(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;

    // Covers values such as C-304, A101, CR-12, Lab-2, Room 204, etc.
    return RegExp(
      r'^(?:room\s*)?[A-Za-z]{0,4}[- ]?\d{1,4}[A-Za-z]?$|^(?:lab|classroom|cr)[- ]?[A-Za-z0-9-]+$',
      caseSensitive: false,
    ).hasMatch(text);
  }

  String _roomFromItem(Map<String, dynamic> item) {
    // Try dedicated room fields first. This is important because the room
    // should survive independently of the subject/faculty formatting.
    const keys = [
      'room',
      'roomNumber',
      'room_number',
      'classroom',
      'classRoom',
      'location',
      'venue',
    ];

    for (final key in keys) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return '';
  }

  String _displayRoom(String room) {
    final value = room.trim();
    if (value.isEmpty || value.toLowerCase() == 'n/a') return 'N/A';

    // The university timetable exports rooms like:
    // "8003-B_BL8-GF". The app only needs the first room identifier.
    final hyphenIndex = value.indexOf('-');
    if (hyphenIndex > 0) {
      return value.substring(0, hyphenIndex).trim();
    }

    return value;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
  }

  Map<String, dynamic>? _getAttendanceForSubject(String subject) {
    final normalizedSubject = _normalize(subject);

    if (normalizedSubject.isEmpty) return null;

    Map<String, dynamic>? partialMatch;

    for (final item in attendance) {
      final name = item['name']?.toString() ?? '';
      final normalizedName = _normalize(name);

      if (normalizedName == normalizedSubject) {
        return item;
      }

      if (normalizedName.contains(normalizedSubject) ||
          normalizedSubject.contains(normalizedName)) {
        partialMatch = item;
      }
    }

    return partialMatch;
  }

  int _timeToMinutes(String value) {
    final parsed = _extractTimes(value);
    return parsed.isEmpty ? 9999 : parsed.first;
  }

  List<int> _extractTimes(String rawTime) {
    final text = rawTime
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final matches = RegExp(
      r'(\d{1,2})(?::(\d{1,2}))?\s*(am|pm)?',
      caseSensitive: false,
    ).allMatches(text).toList();

    if (matches.isEmpty) return [];

    String? sharedMeridiem;
    for (final match in matches) {
      final m = match.group(3)?.toLowerCase();
      if (m != null) {
        sharedMeridiem = m;
        break;
      }
    }

    return matches.take(2).map((match) {
      int hour = int.tryParse(match.group(1) ?? '') ?? 0;
      final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
      final meridiem = (match.group(3)?.toLowerCase()) ?? sharedMeridiem;

      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;

      return hour * 60 + minute;
    }).toList();
  }

  String _formatHour(int minutes) {
    final safeMinutes = minutes.clamp(0, 24 * 60 - 1);
    final hour24 = safeMinutes ~/ 60;
    final minute = safeMinutes % 60;
    final hour12 = hour24 == 0
        ? 12
        : hour24 > 12
            ? hour24 - 12
            : hour24;

    final suffix = hour24 >= 12 ? 'pm' : 'am';
    final minuteText = minute == 0 ? '' : ':${minute.toString().padLeft(2, '0')}';
    return '$hour12$minuteText $suffix';
  }

  bool _isToday() {
    final now = DateTime.now();

    return now.year == selectedDate.year &&
        now.month == selectedDate.month &&
        now.day == selectedDate.day;
  }

  String _getClassStatus(
    Map<String, dynamic> item,
    int index,
    List<Map<String, dynamic>> classes,
  ) {
    if (!_isToday()) {
      return '';
    }

    final now = DateTime.now();
    final range = _extractTimes(item['time']?.toString() ?? '');

    if (range.length < 2) {
      return '';
    }

    final start = range[0];
    final end = range[1];
    final current = now.hour * 60 + now.minute;

    if (current >= start && current < end) {
      return 'Ongoing';
    }

    if (current < start) {
      final hasEarlierUpcoming = classes.take(index).any((other) {
        final otherRange = _extractTimes(other['time']?.toString() ?? '');
        return otherRange.isNotEmpty && otherRange[0] > current;
      });

      if (!hasEarlierUpcoming) {
        return 'Next';
      }
    }

    return '';
  }

  Future<void> _updateTimetable() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PortalWebViewScreen(
          initialUrl: 'https://timetable.sruniv.com/batchReport',
        ),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  void _selectDay(String day) {
    final index = days.indexOf(day);
    if (index < 0) return;

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));

    setState(() {
      selectedDay = day;
      selectedDate = monday.add(Duration(days: index));
    });
  }

  Widget _buildHeader(bool isDark) {
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIMETABLE',
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Schedule',
                    style: TextStyle(
                      color: primary,
                      fontSize: 30,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),
            _iconButton(
              icon: Icons.sync_rounded,
              isDark: isDark,
              onTap: _updateTimetable,
            ),
            const SizedBox(width: 6),
            _iconButton(
              icon: Icons.view_list_rounded,
              isDark: isDark,
              active: !isGridView,
              onTap: () => setState(() => isGridView = false),
            ),
            const SizedBox(width: 5),
            _iconButton(
              icon: Icons.grid_view_rounded,
              isDark: isDark,
              active: isGridView,
              onTap: () => setState(() => isGridView = true),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (!isGridView) ...[
          if (_isWeekday(selectedDate)) ...[
            _buildDaySwitcher(isDark),
          ] else ...[
            _buildWeekendLabel(isDark),
          ],
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                '${selectedDate.day.toString().padLeft(2, '0')} ${_monthName(selectedDate.month)} ${selectedDate.year}',
                style: TextStyle(
                  color: primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                _syncToCurrentDate(force: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? darkSecondary : lightSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.055)
                        : Colors.black.withOpacity(0.055),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.today_rounded, size: 15, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      'Today',
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }

  Widget _iconButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final fg = active
        ? Colors.white
        : isDark
            ? Colors.white.withOpacity(0.78)
            : const Color(0xFF55585D);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? accent
              : isDark
                  ? darkSecondary
                  : lightSecondary,
          border: Border.all(
            color: active
                ? accent.withOpacity(0.35)
                : isDark
                    ? Colors.white.withOpacity(0.055)
                    : Colors.black.withOpacity(0.055),
          ),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }

  Widget _buildWeekendLabel(bool isDark) {
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final label = selectedDate.weekday == DateTime.saturday ? 'SATURDAY' : 'SUNDAY';

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? darkSecondary : lightSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.055) : Colors.black.withOpacity(0.055),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.event_rounded, size: 16, color: muted),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const Spacer(),
          Text('NO REGULAR CLASSES', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildDaySwitcher(bool isDark) {
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final background = isDark ? darkSecondary : lightSecondary;

    return Container(
      height: 68,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.045)
              : Colors.black.withOpacity(0.045),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / days.length;
          final selectedIndex = days.indexOf(selectedDay);
          final safeSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;

          return Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(
                  -1 + (2 * safeSelectedIndex / (days.length - 1)),
                  0,
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: segmentWidth,
                  height: 60,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
              Row(
                children: days.map((day) {
                  final selected = day == selectedDay;
                  final label = fullDayLabels[day] ?? day;
                  final short = label.substring(0, 3);

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectDay(day),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            color: selected ? Colors.white : muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(day),
                              const SizedBox(height: 2),
                              Text(
                                short,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white.withOpacity(0.78)
                                      : primary.withOpacity(0.48),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHolidayCard(String holidayName) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: warning.withOpacity(0.09),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: warning.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: warning.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded, color: warning, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NO CLASSES',
                  style: TextStyle(
                    color: warning,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  holidayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF111111),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status, {required bool isDark}) {
    if (status.isEmpty) return const SizedBox.shrink();

    final color = status == 'Ongoing' ? danger : healthy;
    final icon = status == 'Ongoing'
        ? Icons.play_arrow_rounded
        : Icons.arrow_forward_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  String _listTimeRange(Map<String, dynamic> item) {
    final rawTime = (item['time'] ?? '').toString().trim();
    final parsed = _extractTimes(rawTime);

    if (parsed.length >= 2 && parsed[1] > parsed[0]) {
      return '${_formatHour(parsed[0])} - ${_formatHour(parsed[1])}';
    }

    final itemDay = (item['day'] ?? '').toString().trim().toLowerCase();
    final start = parsed.isNotEmpty ? parsed.first : _timeToMinutes(rawTime);

    if (start == 9999) return rawTime;

    int? nextStart;
    for (final other in timetable) {
      final otherDay = (other['day'] ?? '').toString().trim().toLowerCase();
      if (otherDay != itemDay) continue;

      final otherTimes = _extractTimes((other['time'] ?? '').toString());
      if (otherTimes.isEmpty) continue;

      final otherStart = otherTimes.first;
      if (otherStart > start &&
          (nextStart == null || otherStart < nextStart!)) {
        nextStart = otherStart;
      }
    }

    final end = nextStart ?? (start + 60);
    return '${_formatHour(start)} - ${_formatHour(end)}';
  }

  Widget _buildTimelineCard({
    required Map<String, dynamic> item,
    required Map<String, String> details,
    required String status,
    required bool isDark,
  }) {
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final surface = isDark ? darkSurface : lightSurface;
    final border = isDark
        ? Colors.white.withOpacity(0.055)
        : Colors.black.withOpacity(0.055);

    final statusColor = status == 'Ongoing'
        ? danger
        : status == 'Next'
            ? healthy
            : accent;

    final isLunchBreak = details['subject'] == 'Lunch Break';
    final cardHeight = isLunchBreak ? 82.0 : 128.0;

    return SizedBox(
      height: cardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Center(
              child: Container(
                width: status.isNotEmpty ? 9 : 6,
                height: status.isNotEmpty ? 9 : 42,
                decoration: BoxDecoration(
                  color: status.isNotEmpty
                      ? statusColor
                      : isLunchBreak
                          ? muted.withOpacity(0.45)
                          : accent.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLunchBreak) ...[
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.restaurant_rounded, size: 16, color: muted),
                        const SizedBox(width: 8),
                        Text(
                          'LUNCH BREAK',
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ] else Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TimeLabel(
                              text: _listTimeRange(item),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              details['subject']!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primary,
                                fontSize: 17,
                                height: 1.08,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.25,
                              ),
                            ),
                            if ((details['faculty'] ?? '').isNotEmpty && details['faculty'] != 'Faculty Name') ...[
                              const SizedBox(height: 5),
                              Text(
                                details['faculty']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 76,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.location_on_rounded, size: 14, color: muted),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    _displayRoom(details['room'] ?? '') == 'N/A'
                                        ? '—'
                                        : _displayRoom(details['room'] ?? ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if ((details['batch'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                details['batch']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (status.isNotEmpty) ...[
                    const Spacer(),
                    _buildStatusTag(status, isDark: isDark),
                  ] else ...[
                    const Spacer(),
                    Text(
                      'SCHEDULED',
                      style: TextStyle(color: muted, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.1),
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

  Widget _buildNextClassCard(
    List<Map<String, dynamic>> classes,
    bool isDark,
  ) {
    if (classes.isEmpty) return const SizedBox.shrink();

    Map<String, dynamic>? target;
    String targetStatus = '';
    for (int i = 0; i < classes.length; i++) {
      final status = _getClassStatus(classes[i], i, classes);
      if (status == 'Ongoing' || status == 'Next') {
        target = classes[i];
        targetStatus = status;
        if (status == 'Ongoing') break;
      }
    }

    if (target == null) return const SizedBox.shrink();

    final details = _parseDetails(
      target['subject']?.toString() ?? '',
      target['time']?.toString() ?? '',
      rawRoom: _roomFromItem(target),
    );
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final surface = isDark ? darkSurface : lightSurface;
    final border = isDark ? Colors.white.withOpacity(0.055) : Colors.black.withOpacity(0.055);
    final statusColor = targetStatus == 'Ongoing' ? danger : healthy;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 66,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetStatus == 'Ongoing' ? 'ONGOING CLASS' : 'NEXT CLASS',
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
                const SizedBox(height: 5),
                Text(
                  details['subject']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
                const SizedBox(height: 7),
                _TimeLabel(text: _listTimeRange(target), isDark: isDark),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.location_on_rounded, size: 17, color: muted),
              const SizedBox(height: 4),
              Text(
                _displayRoom(details['room'] ?? '') == 'N/A'
                    ? '—'
                    : _displayRoom(details['room'] ?? ''),
                style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _classOccupiesWindow(Map<String, dynamic> item, int startMinutes, int endMinutes) {
    final range = _extractTimes(item['time']?.toString() ?? '');
    if (range.isEmpty) return false;

    final classStart = range.first;
    final classEnd = range.length > 1 && range[1] > classStart
        ? range[1]
        : classStart + 60;

    return classStart < endMinutes && classEnd > startMinutes;
  }

  Map<String, dynamic>? _lunchBreakForDay(
    List<Map<String, dynamic>> classes,
    String fullDay,
  ) {
    final candidates = <int>[690, 720, 750, 780, 810, 840];

    for (final start in candidates) {
      final end = start + 60;
      final occupied = classes.any((item) {
        final itemDay = item['day']?.toString().trim().toLowerCase() ?? '';
        if (itemDay != fullDay.toLowerCase()) return false;
        return _classOccupiesWindow(item, start, end);
      });

      if (!occupied) {
        return {
          'day': fullDay,
          'subject': 'Lunch Break',
          'time': '${_formatHour(start)} - ${_formatHour(end)}',
          'room': '',
          '_lunch': true,
        };
      }
    }

    // Lunch is compulsory. If every candidate is occupied, place it at the
    // latest permitted start rather than removing it from the schedule.
    const fallbackStart = 840;
    return {
      'day': fullDay,
      'subject': 'Lunch Break',
      'time': '${_formatHour(fallbackStart)} - ${_formatHour(fallbackStart + 60)}',
      'room': '',
      '_lunch': true,
    };
  }

  Widget _buildTimeline(
    List<Map<String, dynamic>> classes,
    bool isDark,
  ) {
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final fullDay = fullDayLabels[selectedDay] ?? 'Monday';

    final sorted = [...classes];
    final lunch = _lunchBreakForDay(classes, fullDay);
    if (lunch != null) sorted.add(lunch);

    sorted.sort(
      (a, b) => _timeToMinutes(a['time']?.toString() ?? '').compareTo(
        _timeToMinutes(b['time']?.toString() ?? ''),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TODAY’S CLASSES',
              style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6),
            ),
            const Spacer(),
            Text(
              '${classes.length} ${classes.length == 1 ? 'CLASS' : 'CLASSES'}',
              style: TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Positioned(
              left: 8,
              top: 5,
              bottom: 18,
              child: Container(
                width: 1,
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
              ),
            ),
            Column(
              children: List.generate(sorted.length, (index) {
                final item = sorted[index];
                final details = _parseDetails(
                  item['subject']?.toString() ?? '',
                  item['time']?.toString() ?? '',
                  rawRoom: _roomFromItem(item),
                );
                final status = item['_lunch'] == true
                    ? ''
                    : _getClassStatus(item, index, sorted);

                return Padding(
                  padding: EdgeInsets.only(bottom: index == sorted.length - 1 ? 0 : 10),
                  child: _buildTimelineCard(
                    item: item,
                    details: details,
                    status: status,
                    isDark: isDark,
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _gridTimeSlots(List<Map<String, dynamic>> allClasses) {
    final starts = <int>{};

    for (final item in allClasses) {
      final range = _extractTimes(item['time']?.toString() ?? '');
      if (range.isNotEmpty) {
        starts.add(range.first);
      }
    }

    final sorted = starts.toList()..sort();

    return sorted.map(_formatHour).toList();
  }

  Map<int, Map<String, dynamic>> _classesByStart(
    List<Map<String, dynamic>> classes,
  ) {
    final result = <int, Map<String, dynamic>>{};

    for (final item in classes) {
      final range = _extractTimes(item['time']?.toString() ?? '');
      if (range.isNotEmpty) {
        result[range.first] = item;
      }
    }

    return result;
  }

  String _gridTimeRange(
    List<Map<String, dynamic>> allClasses,
    int startMinutes,
    List<int> slots,
  ) {
    // Prefer the real end time when the timetable provides one.
    int? latestEnd;
    for (final item in allClasses) {
      final range = _extractTimes(item['time']?.toString() ?? '');
      if (range.length >= 2 && range.first == startMinutes) {
        latestEnd = latestEnd == null
            ? range[1]
            : (range[1] > latestEnd! ? range[1] : latestEnd);
      }
    }

    if (latestEnd != null && latestEnd! > startMinutes) {
      return '${_formatHour(startMinutes)} - ${_formatHour(latestEnd!)}';
    }

    // Some timetable exports contain only the start time. In that case
    // use the next timetable slot as the end; the final slot is one hour.
    int endMinutes = startMinutes + 60;
    for (final slot in slots) {
      if (slot > startMinutes) {
        endMinutes = slot;
        break;
      }
    }

    return '${_formatHour(startMinutes)} - ${_formatHour(endMinutes)}';
  }

  bool _dayHasClassAtStart(
    List<Map<String, dynamic>> allClasses,
    String fullDay,
    int startMinutes,
  ) {
    return allClasses.any((item) {
      final itemDay = item['day']?.toString().trim().toLowerCase() ?? '';
      if (itemDay != fullDay.toLowerCase()) return false;
      final range = _extractTimes(item['time']?.toString() ?? '');
      return range.isNotEmpty && range.first == startMinutes;
    });
  }

  int _lunchBreakStartForDay(
    List<Map<String, dynamic>> allClasses,
    String fullDay,
    List<int> slots,
  ) {
    final lunch = _lunchBreakForDay(allClasses, fullDay);
    if (lunch == null) return 840;
    final times = _extractTimes(lunch['time']?.toString() ?? '');
    return times.isNotEmpty ? times.first : 840;
  }

  Widget _buildGrid(
    List<Map<String, dynamic>> selectedClasses,
    bool isDark,
  ) {
    final allClasses = timetable;

    final slotStarts = <int>{};
    for (final item in allClasses) {
      final range = _extractTimes(item['time']?.toString() ?? '');
      if (range.isNotEmpty) {
        slotStarts.add(range.first);
      }
    }

    final lunchBreakStarts = <String, int>{
      for (final day in days)
        day: _lunchBreakStartForDay(
          allClasses,
          dayNameMap[day] ?? '',
          slotStarts.toList()..sort(),
        ),
    };

    for (final start in lunchBreakStarts.values) {
      slotStarts.add(start);
    }

    final slots = slotStarts.toList()..sort();

    if (slots.isEmpty) {
      final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
      return Padding(
        padding: const EdgeInsets.only(top: 42),
        child: Center(
          child: Text(
            'No timetable data found.',
            style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    const dayWidth = 132.0;
    const timeWidth = 92.0;
    const cellGap = 5.0;
    const headerHeight = 48.0;
    const rowHeight = 145.0;

    // The width includes every right-side gap exactly once.
    const gridWidth =
        timeWidth + cellGap + (5 * (dayWidth + cellGap));

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;

        return SizedBox(
          width: viewportWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.hardEdge,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: gridWidth,
                      height: headerHeight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _gridHeaderCell(
                            'TIME',
                            isDark,
                            width: timeWidth,
                          ),
                          ...days.map(
                            (day) => _gridHeaderCell(
                              fullDayLabels[day] ?? day,
                              isDark,
                              width: dayWidth,
                              selected: day == selectedDay,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...slots.map(
                      (startMinutes) {
                        return SizedBox(
                          width: gridWidth,
                          height: rowHeight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _gridTimeCell(
                                _gridTimeRange(
                                  allClasses,
                                  startMinutes,
                                  slots,
                                ),
                                isDark,
                                width: timeWidth,
                              ),
                              ...days.map(
                                (day) {
                                  final fullDay =
                                      dayNameMap[day] ?? '';

                                  final matching = allClasses.where(
                                    (item) {
                                      final itemDay =
                                          item['day']
                                                  ?.toString()
                                                  .trim()
                                                  .toLowerCase() ??
                                              '';

                                      if (itemDay !=
                                          fullDay.toLowerCase()) {
                                        return false;
                                      }

                                      final range = _extractTimes(
                                        item['time']
                                                ?.toString() ??
                                            '',
                                      );

                                      return range.isNotEmpty &&
                                          range.first ==
                                              startMinutes;
                                    },
                                  ).toList();

                                  final isLunchBreak =
                                      matching.isEmpty &&
                                      lunchBreakStarts[day] == startMinutes;

                                  return _gridClassCell(
                                    matching.isEmpty
                                        ? null
                                        : matching.first,
                                    isDark,
                                    width: dayWidth,
                                    height: rowHeight,
                                    isLunchBreak: isLunchBreak,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _gridHeaderCell(
    String text,
    bool isDark, {
    required double width,
    bool selected = false,
  }) {
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final surface = isDark ? darkSurface : lightSurface;

    return Container(
      width: width,
      height: 48,
      margin: const EdgeInsets.only(right: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? accent : surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected
              ? accent.withOpacity(0.35)
              : isDark
                  ? Colors.white.withOpacity(0.055)
                  : Colors.black.withOpacity(0.055),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _gridTimeCell(
    String text,
    bool isDark, {
    required double width,
  }) {
    final parts = text.split(' - ');
    final start = parts.isNotEmpty ? parts.first : text;
    final end = parts.length > 1 ? parts.last : '';
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);

    return Container(
      width: width,
      height: 139,
      margin: const EdgeInsets.only(right: 5, bottom: 6),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: isDark ? darkSecondary : lightSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(start, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('TO', style: TextStyle(color: muted.withOpacity(0.55), fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(end, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _gridClassCell(
    Map<String, dynamic>? item,
    bool isDark, {
    required double width,
    required double height,
    bool isLunchBreak = false,
  }) {
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final surface = isDark ? darkSurface : lightSurface;
    final border = isDark ? Colors.white.withOpacity(0.055) : Colors.black.withOpacity(0.055);

    if (item == null && !isLunchBreak) {
      return Container(
        width: width,
        height: height - 6,
        margin: const EdgeInsets.only(right: 5, bottom: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.018) : Colors.black.withOpacity(0.018),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
      );
    }

    if (isLunchBreak) {
      return Container(
        width: width,
        height: height - 6,
        margin: const EdgeInsets.only(right: 5, bottom: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.025) : Colors.black.withOpacity(0.025),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Text(
          'LUNCH BREAK',
          style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0),
        ),
      );
    }

    final rawTime = item!['time']?.toString() ?? '';
    final details = _parseDetails(
      item['subject']?.toString() ?? '',
      rawTime,
      rawRoom: _roomFromItem(item),
    );
    return Container(
      width: width,
      height: height - 6,
      margin: const EdgeInsets.only(right: 5, bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 11, 8, 9),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  details['subject'] ?? 'Unknown Subject',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: primary, fontSize: 11.5, height: 1.12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if ((details['faculty'] ?? '').isNotEmpty && details['faculty'] != 'Faculty Name')
            Text(
              details['faculty']!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 8, height: 1.1, fontWeight: FontWeight.w600),
            ),
          const Spacer(),
          if (details['room'] != 'N/A')
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 13, color: muted),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    _displayRoom(details['room'] ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWeekendEmptyState(bool isDark) {
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? darkSurface : lightSurface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.055) : Colors.black.withOpacity(0.055),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.weekend_rounded, size: 28, color: muted),
          const SizedBox(height: 10),
          Text('No regular classes', style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Your timetable is up to date for today.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? darkBackground : lightBackground;
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);

    final holidayName = _getHolidayForSelectedDate();
    final selectedDayIndex = days.indexOf(selectedDay);

    final filteredClasses = timetable.where((item) {
      final value = item['day']?.toString().toLowerCase().trim() ?? '';
      switch (selectedDayIndex) {
        case 0:
          return value.startsWith('mon') || value == 'm';
        case 1:
          return value.startsWith('tue') || value == 't';
        case 2:
          return value.startsWith('wed') || value == 'w';
        case 3:
          return value.startsWith('thu') || value == 'th';
        case 4:
          return value.startsWith('fri') || value == 'f';
        default:
          return false;
      }
    }).toList();

    filteredClasses.sort(
      (a, b) => _timeToMinutes(a['time']?.toString() ?? '').compareTo(
        _timeToMinutes(b['time']?.toString() ?? ''),
      ),
    );

    return Scaffold(
      backgroundColor: background,
      body: isLoading
          ? Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: accent,
                  strokeWidth: 2.2,
                ),
              ),
            )
          : SafeArea(
              bottom: false,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                children: [
                  _buildHeader(isDark),
                  if (isGridView) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          'WEEK VIEW',
                          style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6),
                        ),
                        const Spacer(),
                        Text(
                          '5 DAYS',
                          style: TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGrid(timetable, isDark),
                  ] else if (holidayName != null) ...[
                    _buildHolidayCard(holidayName),
                  ] else if (!_isWeekday(selectedDate)) ...[
                    _buildWeekendEmptyState(isDark),
                  ] else ...[
                    _buildNextClassCard(filteredClasses, isDark),
                    _buildTimeline(filteredClasses, isDark),
                  ],
                ],
              ),
            ),
    );
  }
}
