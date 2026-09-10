import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  int targetAttendance = 75; // Default target

  final List<Map<String, dynamic>> subjects = [
    {'name': 'Data Structures', 'present': 43, 'held': 50},
    {'name': 'DBMS', 'present': 39, 'held': 50},
    {'name': 'Operating Systems', 'present': 46, 'held': 50},
    {'name': 'Computer Networks', 'present': 41, 'held': 50},
  ];

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Semester Selector Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Semester 5', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Target Attendance Slider / Increment Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Target Attendance:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                Text('$targetAttendance%', style: const TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            Slider(
              value: targetAttendance.toDouble(),
              min: 65,
              max: 95,
              divisions: 6,
              activeColor: const Color(0xFFFF3B30),
              inactiveColor: const Color(0xFF1E1E1E),
              onChanged: (value) {
                setState(() {
                  targetAttendance = value.toInt();
                });
              },
            ),
            const SizedBox(height: 10),

            // Subject Attendance List
            Expanded(
              child: ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final sub = subjects[index];
                  int present = sub['present'];
                  int held = sub['held'];
                  double percentage = (present / held) * 100;
                  int skippable = _calculateSkippable(present, held);
                  int needed = _calculateNeeded(present, held);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(sub['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${percentage.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.black,
                          color: percentage >= targetAttendance ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Present: $present   Held: $held', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                skippable > 0 
                                  ? 'You can skip up to $skippable classes.' 
                                  : 'Need to attend $needed classes.',
                                style: TextStyle(
                                  color: skippable > 0 ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
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