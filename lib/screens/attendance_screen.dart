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
    setState(() {
      subjects = cachedAttendance;
      targetAttendance = (savedTarget <= 0) ? 75 : savedTarget;
      isLoading = false;
    });
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

  void _showTargetPicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Attendance Target',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...targetOptions.map((opt) {
                bool isSelected = opt == targetAttendance;
                return ListTile(
                  title: Text('$opt%', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFFFF3B30) : null)),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFFF3B30)) : null,
                  onTap: () async {
                    setState(() => targetAttendance = opt);
                    await SessionManager.saveTarget(opt);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color boxColor = isDark ? const Color(0xFF161618) : const Color(0xFFF2F2F7);
    Color borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () => _showTargetPicker(context, isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Target: $targetAttendance%',
                        style: const TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFFFF3B30), size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: subjects.isEmpty
                            ? const Center(
                                child: Text(
                                  'No attendance data found.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 120),
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
                      ),
                    ],
                  ),
                ),
          
          // Floating Sync Button on bottom right
          Positioned(
            right: 20,
            bottom: 90,
            child: FloatingActionButton(
              heroTag: 'sync_button',
              shape: const CircleBorder(),
              backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
              elevation: 4,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PortalWebViewScreen()),
                );
                if (result == true) {
                  _loadData();
                }
              },
              child: Icon(
                Icons.sync_rounded,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}