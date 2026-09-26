import 'dart:async';

import 'package:flutter/material.dart';

import '../session_manager.dart';
import 'timetable_screen.dart';
import 'portal_webview_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  final bool? isDarkMode;
  final Function(int)? onNavigate;

  const HomeScreen({
    super.key,
    this.onThemeChanged,
    this.isDarkMode,
    this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? nextClass;
  Map<String, dynamic>? ongoingClass;

  String timeRemainingText = '';

  bool isCompleted = false;

  List<Map<String, dynamic>> timetable = [];
  List<Map<String, dynamic>> attendanceList = [];
  List<Map<String, dynamic>> calendarEvents = [];

  bool isLoading = true;


  String studentName = 'Student';

  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _loadDashboardData();

    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) {
        if (mounted) {
          _loadDashboardData();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // REFRESH HOME DATA
  // ============================================================

  void refreshData() {
    _loadDashboardData();
  }

  // ============================================================
  // TIME PARSER
  // ============================================================

  int _parseTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.split('-')[0].trim();

      final parts = clean.split(':');

      if (parts.length >= 2) {
        final hours =
            int.tryParse(parts[0].trim()) ?? 0;

        final minutes =
            int.tryParse(parts[1].trim()) ?? 0;

        return hours * 60 + minutes;
      }
    } catch (_) {}

    return 0;
  }

  // ============================================================
  // LOAD LOCAL DASHBOARD DATA
  // ============================================================

  // ============================================================
  // SUBJECT / FACULTY / ROOM HELPERS
  // ============================================================

  String _extractRoomNumber(String subjectText) {
    try {
      final regExp = RegExp(r'\(([^)]+)\)');
      final matches = regExp.allMatches(subjectText);

      for (final match in matches) {
        final content = match.group(1)?.trim() ?? '';
        if (content.contains('-')) {
          return content.split('-').first.trim();
        }
      }
    } catch (_) {}

    return '';
  }

  Map<String, String> _cleanSubjectAndFirmFaculty(String text) {
    if (text.contains(';')) {
      text = text.split(';').first.trim();
    }

    String subject = text;
    String faculty = '';

    if (text.contains(':')) {
      final parts = text.split(':');

      subject = parts[0].trim();

      if (subject.contains('(')) {
        subject = subject
            .replaceAll(RegExp(r'\([^)]*-[^)]*\)'), '')
            .trim();
      }

      if (parts.length > 1) {
        String possibleFaculty = parts[1].trim();

        possibleFaculty = possibleFaculty
            .replaceAll(RegExp(r'\([^)]*-[^)]*\)'), '')
            .trim();

        if (possibleFaculty.contains('(')) {
          possibleFaculty = possibleFaculty
              .substring(0, possibleFaculty.indexOf('('))
              .trim();
        }

        if (possibleFaculty.isNotEmpty &&
            !possibleFaculty.contains('8003') &&
            !possibleFaculty.contains('1108')) {
          faculty = possibleFaculty;
        }
      }

      if (parts.length > 2 && faculty.isEmpty) {
        String possibleFaculty2 = parts[2].trim();

        possibleFaculty2 = possibleFaculty2
            .replaceAll(RegExp(r'\([^)]*-[^)]*\)'), '')
            .trim();

        if (possibleFaculty2.contains('(')) {
          possibleFaculty2 = possibleFaculty2
              .substring(0, possibleFaculty2.indexOf('('))
              .trim();
        }

        faculty = possibleFaculty2;
      }
    }

    if (faculty.isEmpty) {
      final regex = RegExp(r'(Mr\.|Dr\.|Ms\.)\s+[a-zA-Z\s]+');
      final match = regex.firstMatch(text);

      if (match != null) {
        faculty = match.group(0)!.trim();

        subject = text
            .substring(0, text.indexOf(faculty))
            .replaceAll(':', '')
            .replaceAll(RegExp(r'\([^)]*-[^)]*\)'), '')
            .trim();
      }
    }

    return {
      'subject': subject,
      'faculty': faculty,
    };
  }

  // ============================================================
  // TIME / CLASS HELPERS
  // ============================================================

  int _dayToInt(String dayName) {
    switch (dayName.trim().toLowerCase()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  List<int> _parseTimeRange(String timeStr) {
    try {
      final parts = timeStr.split('-');
      if (parts.isEmpty) return [0, 0];

      int parsePart(String value) {
        final clean = value.trim().toLowerCase();
        final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(clean);
        if (match == null) return 0;
        final hour = int.tryParse(match.group(1)!) ?? 0;
        final minute = int.tryParse(match.group(2)!) ?? 0;
        return hour * 60 + minute;
      }

      final start = parsePart(parts[0]);
      final end = parts.length > 1 ? parsePart(parts[1]) : start + 50;
      return [start, end];
    } catch (_) {
      return [0, 0];
    }
  }

  String _displayRoom(String value) {
    final index = value.indexOf('-');
    return (index >= 0 ? value.substring(0, index) : value).trim();
  }

  // ============================================================
  // REFRESH DASHBOARD DATA
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _calendarEventForDate(DateTime date) {
    final dateString = _formatDate(date);
    for (final event in calendarEvents) {
      if (event['date']?.toString() == dateString) {
        return event;
      }
    }
    return null;
  }

  bool _isNonTeachingDate(DateTime date) {
    if (date.weekday == DateTime.sunday) return true;

    final event = _calendarEventForDate(date);
    if (event == null) return false;

    final type = event['type']?.toString().toLowerCase() ?? '';
    return type == 'holiday' ||
        type == 'weekend' ||
        type == 'exam';
  }

  String? _todayScheduleLabel(DateTime date) {
    final event = _calendarEventForDate(date);

    if (event != null) {
      final type = event['type']?.toString().toLowerCase() ?? '';
      final name = event['name']?.toString().trim() ?? '';

      if (type == 'holiday') return name.isNotEmpty ? name : 'Holiday';
      if (type == 'exam') return name.isNotEmpty ? name : 'Examination';
      if (type == 'club') return name.isNotEmpty ? name : 'Club Activity';
      if (type == 'weekend') return name.isNotEmpty ? name : 'Weekend Break';
    }

    if (date.weekday == DateTime.sunday) return 'Sunday';
    return null;
  }

  String _dayName(int weekday) {
    const names = <int, String>{
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return names[weekday] ?? 'Monday';
  }

  Future<void> _loadDashboardData() async {
    final timetableData = await SessionManager.getTimetable();
    final attendance = await SessionManager.getAttendance();
    final profile = await SessionManager.getProfile();
    final holidays = await SessionManager.getHolidays();

    if (profile.isNotEmpty && profile['name'] != null) {
      studentName = profile['name'].toString();
    }

    final now = DateTime.now();
    calendarEvents = holidays;

    Map<String, dynamic>? ongoing;
    Map<String, dynamic>? upcoming;
    DateTime? upcomingDateTime;

    // Calendar data has priority over the weekly timetable.
    if (!_isNonTeachingDate(now)) {
      final todayName = _dayName(now.weekday).toLowerCase();

      for (final item in timetableData) {
        final itemDay = item['day']?.toString().trim().toLowerCase() ?? '';
        if (itemDay != todayName) continue;

        final range = _parseTimeRange(item['time']?.toString() ?? '');
        final start = DateTime(
          now.year,
          now.month,
          now.day,
          range[0] ~/ 60,
          range[0] % 60,
        );
        final end = DateTime(
          now.year,
          now.month,
          now.day,
          range[1] ~/ 60,
          range[1] % 60,
        );

        if (!now.isBefore(start) && now.isBefore(end)) {
          ongoing = item;
          break;
        }
      }
    }

    // Find the next class using the actual calendar date. Calendar
    // holidays/weekends/exams override the repeating timetable.
    for (int offset = 0; offset <= 14 && upcoming == null; offset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: offset));

      if (_isNonTeachingDate(date)) continue;

      final dayName = _dayName(date.weekday).toLowerCase();
      DateTime? bestStart;
      Map<String, dynamic>? bestItem;

      for (final item in timetableData) {
        final itemDay = item['day']?.toString().trim().toLowerCase() ?? '';
        if (itemDay != dayName) continue;

        final range = _parseTimeRange(item['time']?.toString() ?? '');
        final start = DateTime(
          date.year,
          date.month,
          date.day,
          range[0] ~/ 60,
          range[0] % 60,
        );

        if (!start.isAfter(now)) continue;

        if (bestStart == null || start.isBefore(bestStart)) {
          bestStart = start;
          bestItem = item;
        }
      }

      if (bestItem != null) {
        upcoming = bestItem;
        upcomingDateTime = bestStart;
      }
    }

    String timerText = '';
    if (upcomingDateTime != null) {
      final minutes = upcomingDateTime.difference(now).inMinutes;

      if (minutes < 60) {
        timerText = 'in $minutes min';
      } else if (minutes < 1440) {
        final hours = minutes ~/ 60;
        final remaining = minutes % 60;
        timerText = remaining == 0
            ? 'in ${hours}h'
            : 'in ${hours}h ${remaining}m';
      } else {
        final days = minutes ~/ 1440;
        timerText = 'in $days day${days == 1 ? '' : 's'}';
      }
    }

    if (!mounted) return;

    setState(() {
      timetable = timetableData;
      attendanceList = attendance;
      calendarEvents = holidays;
      nextClass = upcoming;
      ongoingClass = ongoing;
      timeRemainingText = timerText;
      isLoading = false;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = widget.isDarkMode ??
        (Theme.of(context).brightness == Brightness.dark);

    final background = isDark
        ? const Color(0xFF090A0B)
        : const Color(0xFFF6F6F3);
    final surface = isDark
        ? const Color(0xFF111315)
        : Colors.white;
    final secondarySurface = isDark
        ? const Color(0xFF181A1D)
        : const Color(0xFFEEEEEA);
    final primaryText = isDark
        ? Colors.white
        : const Color(0xFF111111);
    final secondaryText = isDark
        ? const Color(0xFF92959A)
        : const Color(0xFF77797D);
    final border = isDark
        ? Colors.white.withOpacity(0.055)
        : Colors.black.withOpacity(0.055);
    const accent = Color(0xFF6376F5);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Square',
              style: TextStyle(
                color: primaryText,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome, $studentName',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Profile',
              onPressed: () => widget.onNavigate?.call(4),
              style: IconButton.styleFrom(
                backgroundColor: secondarySurface,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
              icon: Icon(
                Icons.person_outline_rounded,
                color: primaryText,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: accent,
        backgroundColor: surface,
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('OVERALL ATTENDANCE', secondaryText),
              const SizedBox(height: 10),
              _buildOverallAttendance(
                surface: surface,
                secondarySurface: secondarySurface,
                primaryText: primaryText,
                secondaryText: secondaryText,
                border: border,
                accent: accent,
              ),
              const SizedBox(height: 28),

              _sectionLabel('ONGOING', secondaryText),
              const SizedBox(height: 10),
              _buildClassCard(
                classData: ongoingClass,
                label: 'Ongoing Class',
                accent: const Color(0xFF55C98A),
                surface: surface,
                secondarySurface: secondarySurface,
                primaryText: primaryText,
                secondaryText: secondaryText,
                border: border,
                isOngoing: true,
              ),
              const SizedBox(height: 20),

              _sectionLabel('UP NEXT', secondaryText),
              const SizedBox(height: 10),
              _buildClassCard(
                classData: nextClass,
                label: 'Next Class',
                accent: accent,
                surface: surface,
                secondarySurface: secondarySurface,
                primaryText: primaryText,
                secondaryText: secondaryText,
                border: border,
                isOngoing: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.7,
      ),
    );
  }

  Widget _buildOverallAttendance({
    required Color surface,
    required Color secondarySurface,
    required Color primaryText,
    required Color secondaryText,
    required Color border,
    required Color accent,
  }) {
    double totalHeld = 0;
    double totalPresent = 0;

    for (final item in attendanceList) {
      totalHeld += (item['held'] as num?)?.toDouble() ?? 0;
      totalPresent += (item['present'] as num?)?.toDouble() ?? 0;
    }

    final percentage =
        totalHeld > 0 ? (totalPresent / totalHeld * 100) : 0.0;

    final statusColor = percentage >= 75
        ? const Color(0xFF55C98A)
        : percentage >= 65
            ? const Color(0xFFE0B84F)
            : const Color(0xFFE86B6B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.fromLTRB(24, 25, 24, 22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isLoading
          ? const SizedBox(
              height: 143,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : attendanceList.isEmpty
              ? SizedBox(
                  height: 143,
                  child: Center(
                    child: Text(
                      'No attendance data synced yet.',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: percentage),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Text(
                              '${value.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 50,
                                height: 0.92,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2.2,
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${totalPresent.toInt()} / ${totalHeld.toInt()}',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: percentage / 100),
                        duration: const Duration(milliseconds: 1250),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Stack(
                            children: [
                              Container(
                                height: 8,
                                width: double.infinity,
                                color: secondarySurface,
                              ),
                              FractionallySizedBox(
                                widthFactor: value.clamp(0.0, 1.0),
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 17),
                    Row(
                      children: [
                        Expanded(
                          child: _attendanceMetric(
                            label: 'PRESENT',
                            value: totalPresent.toInt().toString(),
                            color: statusColor,
                            secondaryText: secondaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _attendanceMetric(
                            label: 'HELD',
                            value: totalHeld.toInt().toString(),
                            color: accent,
                            secondaryText: secondaryText,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _attendanceMetric({
    required String label,
    required String value,
    required Color color,
    required Color secondaryText,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, _) {
            return Text(
              animatedValue.toStringAsFixed(0),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: secondaryText,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard({
    required Map<String, dynamic>? classData,
    required String label,
    required Color accent,
    required Color surface,
    required Color secondarySurface,
    required Color primaryText,
    required Color secondaryText,
    required Color border,
    required bool isOngoing,
  }) {
    if (classData == null) {
      final todayLabel = isOngoing
          ? _todayScheduleLabel(DateTime.now())
          : null;

      if (todayLabel != null) {
        final eventColor = todayLabel.toLowerCase().contains('exam')
            ? const Color(0xFFE0B84F)
            : const Color(0xFF55C98A);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 21),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: eventColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  todayLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: secondaryText.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isOngoing ? 'No class is ongoing' : 'No upcoming class',
              style: TextStyle(
                color: secondaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final rawSubject = classData['subject']?.toString() ?? '';
    final details = _cleanSubjectAndFirmFaculty(rawSubject);
    final subject = details['subject'] ?? 'Subject';
    final faculty = details['faculty'] ?? '';
    final room = _extractRoomNumber(rawSubject);
    final time = classData['time']?.toString() ?? '';
    final day = classData['day']?.toString() ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 21),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (!isOngoing && timeRemainingText.isNotEmpty)
                Text(
                  timeRemainingText,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryText,
              fontSize: 20,
              height: 1.13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (faculty.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              faculty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoPill(
                Icons.access_time_rounded,
                isOngoing ? time : '$day • $time',
                secondarySurface,
                secondaryText,
              ),
              if (room.isNotEmpty)
                _infoPill(
                  Icons.location_on_outlined,
                  'Room ${_displayRoom(room)}',
                  secondarySurface,
                  secondaryText,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoPill(
    IconData icon,
    String text,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
