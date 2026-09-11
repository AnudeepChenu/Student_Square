import 'package:flutter/material.dart';
import '../session_manager.dart';
import 'portal_webview_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  int targetAttendance = 75;
  List<Map<String, dynamic>> subjects = [];
  bool isLoading = true;

  final List<int> targetOptions = [65, 75, 80, 85, 90, 95];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final cachedAttendance = await SessionManager.getAttendance();
    final savedTarget = await SessionManager.getTarget();
    if (mounted) {
      setState(() {
        subjects = cachedAttendance;
        targetAttendance = (savedTarget <= 0) ? 75 : savedTarget;
        isLoading = false;
      });
    }
  }

  void _changeTarget(int direction) async {
    int currentIndex = targetOptions.indexOf(targetAttendance);
    if (currentIndex == -1) currentIndex = 1; // default to 75 if not found
    
    int newIndex = currentIndex + direction;
    if (newIndex >= 0 && newIndex < targetOptions.length) {
      setState(() {
        targetAttendance = targetOptions[newIndex];
      });
      await SessionManager.saveTarget(targetAttendance);
    }
  }

  int _calculateSkippable(int present, int held) {
    double target = targetAttendance / 100.0;
    int skipCount = 0;
    while ((present / (held + skipCount + 1)) >= target) {
      skipCount++;
    }
    return skipCount;
  }

  int _calculateNeeded(int present, int held) {
    double target = targetAttendance / 100.0;
    if ((present / held) >= target) return 0;
    int needed = 0;
    while (((present + needed) / (held + needed)) < target) {
      needed++;
    }
    return needed;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color boxColor = isDark ? const Color(0xFF161618) : const Color(0xFFF2F2F7);
    Color borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return Scaffold(
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
          : ListView(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 120),
              children: [
                // Top Header Row with Title, Target Changer, and Sync Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      ' Attendance',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        // Target Selector Box: < 75% >
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _changeTarget(-1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black87, size: 18),
                                ),
                              ),
                              Text(
                                '$targetAttendance%',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _changeTarget(1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black87, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sync Button
                        GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PortalWebViewScreen()),
                            );
                            if (result == true) {
                              _loadData();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.sync_rounded, color: isDark ? Colors.white : Colors.black87, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Subject List
                subjects.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 100),
                        child: Center(
                          child: Text(
                            'No attendance data found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: subjects.length,
                        itemBuilder: (context, index) {
                          final sub = subjects[index];
                          int present = int.tryParse(sub['present']?.toString() ?? '0') ?? 0;
                          int held = int.tryParse(sub['held']?.toString() ?? '0') ?? 0;
                          double percentage = held == 0 ? 0 : (present / held) * 100;
                          int skippable = _calculateSkippable(present, held);
                          int needed = _calculateNeeded(present, held);

                          bool isSafe = percentage >= targetAttendance;
                          Color statusColor = isSafe ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: boxColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Text(
                                        sub['name']?.toString() ?? 'Subject',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 4,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Present: $present | Held: $held',
                                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    skippable > 0 ? 'Can skip $skippable classes' : 'Need to attend $needed classes',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
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