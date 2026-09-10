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
  String selectedDay = 'Monday';

  final List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    final now = DateTime.now();
    final daysMap = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Monday',
    };
    selectedDay = daysMap[now.weekday] ?? 'Monday';
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color boxColor = isDark ? const Color(0xFF161618) : const Color(0xFFF2F2F7);
    Color borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    final filteredClasses = timetable.where((item) {
      final itemDay = item['day']?.toString().trim().toLowerCase() ?? '';
      return itemDay == selectedDay.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
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
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: days.map((day) {
                        bool isSelected = selectedDay == day;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(day),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFF3B30),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: boxColor,
                            onSelected: (selected) {
                              setState(() {
                                selectedDay = day;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredClasses.isEmpty
                        ? const Center(
                            child: Text(
                              'No classes scheduled for this day.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 120),
                            itemCount: filteredClasses.length,
                            itemBuilder: (context, index) {
                              final item = filteredClasses[index];
                              final details = _parseDetails(
                                item['subject']?.toString() ?? '',
                                item['time']?.toString() ?? '',
                              );

                              return Container(
                                constraints: const BoxConstraints(minHeight: 120),
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: boxColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor, width: 1),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Left Side: Subject, Faculty, Batch
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
                                    // Right Side: Time & Room Code
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
                  ),
                ],
              ),
            ),
    );
  }
}