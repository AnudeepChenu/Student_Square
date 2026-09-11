import 'package:flutter/material.dart';
import '../session_manager.dart';
import 'portal_webview_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> timetable = [];
  bool isLoading = true;
  String selectedDay = 'M';

  final List<String> days = ['M', 'T', 'W', 'Th', 'F'];

  final Map<String, String> dayNameMap = {
    'M': 'Monday',
    'T': 'Tuesday',
    'W': 'Wednesday',
    'T': 'Thursday',
    'F': 'Friday',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    final now = DateTime.now();
    final daysMap = {
      DateTime.monday: 'M',
      DateTime.tuesday: 'T',
      DateTime.wednesday: 'W',
      DateTime.thursday: 'T',
      DateTime.friday: 'F',
      DateTime.saturday: 'M',
      DateTime.sunday: 'M',
    };
    selectedDay = daysMap[now.weekday] ?? 'M';
  }

  void _loadData() async {
    final cachedTimetable = await SessionManager.getTimetable();
    if (mounted) {
      setState(() {
        timetable = cachedTimetable;
        isLoading = false;
      });
    }
  }

  Map<String, String> _parseDetails(String rawSubject, String rawTime) {
    String subject = rawSubject;
    String room = '';
    String faculty = '';
    String batch = '';

    try {
      if (rawSubject.contains(':')) {
        var parts = rawSubject.split(':');
        subject = parts[0].trim();

        if (parts.length > 1) {
          String secondPart = parts[1].trim();
          
          RegExp roomReg = RegExp(r'\(([^)]+)\)');
          var match = roomReg.firstMatch(secondPart);
          if (match != null) {
            String roomBlock = match.group(1) ?? '';
            room = roomBlock.split('-').first.trim();
            secondPart = secondPart.replaceAll(match.group(0)!, '').trim();
          }
          faculty = secondPart;
        }

        if (parts.length > 2) {
          batch = parts[2].replaceAll(RegExp(r'[()]'), '').trim();
        }
      }
    } catch (_) {
      subject = rawSubject;
    }

    return {
      'subject': subject,
      'faculty': faculty.isEmpty ? 'Faculty Name' : faculty,
      'batch': batch,
      'room': room.isEmpty ? 'N/A' : room,
      'time': rawTime,
    };
  }

  bool _isOngoingClass(String timeStr, String itemDay) {
    final now = DateTime.now();
    final daysMap = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    final todayFull = daysMap[now.weekday] ?? '';
    if (itemDay.toLowerCase() != todayFull.toLowerCase()) {
      return false;
    }

    try {
      var parts = timeStr.split('-');
      if (parts.length != 2) return false;

      DateTime startTime = _parseTimeString(parts[0].trim());
      DateTime endTime = _parseTimeString(parts[1].trim());

      final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      final startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
      final endDateTime = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);

      return currentTime.isAtSameMomentAs(startDateTime) ||
          (currentTime.isAfter(startDateTime) && currentTime.isBefore(endDateTime));
    } catch (_) {
      return false;
    }
  }

  DateTime _parseTimeString(String t) {
    final upper = t.toUpperCase();
    bool isPM = upper.contains('PM');
    bool isAM = upper.contains('AM');

    String clean = upper.replaceAll('AM', '').replaceAll('PM', '').trim();
    var timeParts = clean.split(':');
    int hour = int.parse(timeParts[0]);
    int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

    if (isPM && hour < 12) hour += 12;
    if (isAM && hour == 12) hour = 0;

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color boxColor = isDark ? const Color(0xFF161618) : const Color(0xFFF2F2F7);
    Color borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    final fullSelectedDay = dayNameMap[selectedDay] ?? 'Monday';
    final filteredClasses = timetable.where((item) {
      final itemDay = item['day']?.toString().trim().toLowerCase() ?? '';
      return itemDay == fullSelectedDay.toLowerCase();
    }).toList();

    return Scaffold(
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
          : ListView(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 120),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      ' Timetable',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PortalWebViewScreen(
                              initialUrl: 'https://timetable.sruniv.com/batchReport',
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadData();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync_rounded, color: isDark ? Colors.white : Colors.black87, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Update',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121212) : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: days.map((day) {
                          bool isSelected = selectedDay == day;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedDay = day;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFFF3B30) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.black87),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                filteredClasses.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 100),
                        child: Center(
                          child: Text(
                            'No classes scheduled for this day.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredClasses.length,
                        itemBuilder: (context, index) {
                          final item = filteredClasses[index];
                          final details = _parseDetails(
                            item['subject']?.toString() ?? '',
                            item['time']?.toString() ?? '',
                          );

                          bool isOngoing = _isOngoingClass(
                            details['time']!,
                            item['day']?.toString() ?? '',
                          );
                          Color currentBorderColor = isOngoing ? const Color(0xFFFF3B30) : borderColor;
                          double currentBorderWidth = isOngoing ? 2.0 : 1.0;

                          return Container(
                            constraints: const BoxConstraints(minHeight: 120),
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: boxColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: currentBorderColor, width: currentBorderWidth),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        details['subject']!,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        details['faculty']!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (details['batch']!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '(${details['batch']})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        details['time']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        textAlign: TextAlign.right,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          details['room']!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}