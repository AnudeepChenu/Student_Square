import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../session_manager.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  final bool? isDarkMode;
  final Function(int)? onNavigate;

  const HomeScreen({super.key, this.onThemeChanged, this.isDarkMode, this.onNavigate});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? nextClass;
  String timeRemainingText = '';
  bool isCompleted = false;
  List<Map<String, dynamic>> attendanceList = [];
  bool isLoading = true;
  String studentName = 'Student';
  Timer? _timer;

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadDashboardData();

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadDashboardData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void refreshData() {
    _loadDashboardData();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showClassNotification(String className, String roomNumber, String classTime) async {
    final notificationsEnabled = await SessionManager.getNotificationPreference();
    if (!notificationsEnabled) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'student_square_class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes before 15 minutes',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'app_logo',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Next Class at $classTime',
      '$className (room : ${roomNumber.isEmpty ? "N/A" : roomNumber})',
      platformChannelSpecifics,
    );
  }

  int _parseTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.split('-')[0].trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        final hours = int.tryParse(parts[0].trim()) ?? 0;
        final minutes = int.tryParse(parts[1].trim()) ?? 0;
        return hours * 60 + minutes;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _loadDashboardData() async {
    final timetable = await SessionManager.getTimetable();
    final attendance = await SessionManager.getAttendance();
    final profile = await SessionManager.getProfile();

    if (profile.isNotEmpty && profile['name'] != null) {
      studentName = profile['name'];
    }

    if (timetable.isNotEmpty) {
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
      
      final currentDayName = daysMap[now.weekday] ?? 'Monday';
      final currentTotalMinutes = now.hour * 60 + now.minute;
      
      final todaysClasses = timetable.where((item) {
        final itemDay = item['day']?.toString().trim().toLowerCase() ?? '';
        return itemDay == currentDayName.toLowerCase();
      }).toList();

      if (todaysClasses.isNotEmpty) {
        Map<String, dynamic>? upcoming;
        int minDiff = 999999;
        bool allCompleted = true;

        for (var item in todaysClasses) {
          final timeStr = item['time']?.toString() ?? '';
          final classMinutes = _parseTimeToMinutes(timeStr);
          final diff = classMinutes - currentTotalMinutes;
          
          if (diff >= -50) {
            allCompleted = false;
          }

          if (diff >= -50 && diff <= 15 && diff < minDiff) {
            minDiff = diff;
            upcoming = item;
          }
        }

        if (upcoming == null) {
          for (var item in todaysClasses) {
            final classMinutes = _parseTimeToMinutes(item['time']?.toString() ?? '');
            final diff = classMinutes - currentTotalMinutes;
            if (diff > 15 && diff < minDiff) {
              minDiff = diff;
              upcoming = item;
            }
          }
        }

        if (allCompleted || upcoming == null) {
          upcoming = todaysClasses.first;
          setState(() {
            isCompleted = true;
            nextClass = upcoming;
            timeRemainingText = '';
          });
        } else {
          final classMinutes = _parseTimeToMinutes(upcoming['time']?.toString() ?? '');
          final diff = classMinutes - currentTotalMinutes;

          if (diff == 15) {
            final subName = _cleanSubjectAndFirmFaculty(upcoming['subject'] ?? '')['subject'] ?? 'Subject';
            final room = _extractRoomNumber(upcoming['subject'] ?? '');
            final timeStr = upcoming['time']?.toString() ?? '';
            _showClassNotification(subName, room, timeStr);
          }

          String timerText = '';
          if (diff > 0) {
            if (diff < 60) {
              timerText = 'in $diff min';
            } else {
              final h = diff ~/ 60;
              final m = diff % 60;
              timerText = 'in ${h}h ${m}m';
            }
          } else {
            timerText = 'Ongoing now';
          }

          setState(() {
            isCompleted = false;
            nextClass = upcoming;
            timeRemainingText = timerText;
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        attendanceList = attendance;
        isLoading = false;
      });
    }
  }

  String _extractRoomNumber(String subjectText) {
    try {
      final RegExp regExp = RegExp(r'\(([^)]+)\)');
      final Iterable<Match> matches = regExp.allMatches(subjectText);
      for (final match in matches) {
        final contentInsideBrackets = match.group(1) ?? '';
        if (contentInsideBrackets.contains('-')) {
          return contentInsideBrackets.split('-').first.trim();
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
        subject = subject.replaceAll(RegExp(r'\([^)]*-[^)]*\)'), '').trim();
      }

      if (parts.length > 1) {
        String possibleFaculty = parts[1].trim();
        possibleFaculty = possibleFaculty.replaceAll(RegExp(r'\([^)]*-[^)]*\)'), '').trim();
        
        if (possibleFaculty.contains('(')) {
          possibleFaculty = possibleFaculty.substring(0, possibleFaculty.indexOf('(')).trim();
        }
        if (possibleFaculty.isNotEmpty && !possibleFaculty.contains('8003') && !possibleFaculty.contains('1108')) {
          faculty = possibleFaculty;
        }
      }
      
      if (parts.length > 2 && faculty.isEmpty) {
        String possibleFaculty2 = parts[2].trim();
        possibleFaculty2 = possibleFaculty2.replaceAll(RegExp(r'\([^)]*-[^)]*\)'), '').trim();
        if (possibleFaculty2.contains('(')) {
          possibleFaculty2 = possibleFaculty2.substring(0, possibleFaculty2.indexOf('(')).trim();
        }
        faculty = possibleFaculty2;
      }
    }

    if (faculty.isEmpty) {
      final regex = RegExp(r'(Mr\.|Dr\.|Ms\.)\s+[a-zA-Z\s]+');
      final match = regex.firstMatch(text);
      if (match != null) {
        faculty = match.group(0)!.trim();
        subject = text.substring(0, text.indexOf(faculty)).replaceAll(':', '').replaceAll(RegExp(r'\([^)]*-[^)]*\)'), '').trim();
      }
    }

    return {
      'subject': subject,
      'faculty': faculty,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isDark = widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    Color boxColor = isDark ? const Color(0xFF161618) : const Color(0xFFF2F2F7);
    Color borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Student Square', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 2),
            Text('Welcome, $studentName', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Color(0xFF2C2C2E),
              child: Icon(Icons.person, color: Colors.white),
            ),
            onPressed: () {
              if (widget.onNavigate != null) {
                widget.onNavigate!(3);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
                  : nextClass == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text(
                              'No classes scheduled for today',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF3B30),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Next Class',
                                      style: TextStyle(
                                        color: Color(0xFFFF3B30),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isCompleted)
                                  Text(
                                    timeRemainingText,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _cleanSubjectAndFirmFaculty(nextClass!['subject'] ?? '')['subject'] ?? 'Subject',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((_cleanSubjectAndFirmFaculty(nextClass!['subject'] ?? '')['faculty'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _cleanSubjectAndFirmFaculty(nextClass!['subject'] ?? '')['faculty']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 15, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  nextClass!['time']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (_extractRoomNumber(nextClass!['subject'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 15, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Room ${_extractRoomNumber(nextClass!['subject'] ?? '')}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    if (widget.onNavigate != null) {
                      widget.onNavigate!(1);
                    }
                  },
                  child: const Text('View All', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            countdownBox(boxColor, borderColor),
          ],
        ),
      ),
    );
  }

  Widget countdownBox(Color boxColor, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: attendanceList.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Text(
                  'No attendance data synced yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                attendanceList.length > 5 ? 5 : attendanceList.length,
                (index) {
                  final subject = attendanceList[index];
                  final name = subject['name'] ?? 'Subject';
                  final held = subject['held'] ?? 0;
                  final present = subject['present'] ?? 0;
                  final percentage = held > 0 ? ((present / held) * 100).toStringAsFixed(1) : '0.0';
                  final bool isLast = index == (attendanceList.length > 5 ? 5 : attendanceList.length) - 1;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$percentage%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(color: Colors.white.withOpacity(0.06), height: 1),
                    ],
                  );
                },
              ),
            ),
    );
  }
}