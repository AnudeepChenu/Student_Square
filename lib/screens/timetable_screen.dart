import 'package:flutter/material.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  String selectedDay = 'Mon';
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  final Map<String, List<Map<String, String>>> timetableData = {
    'Mon': [
      {'time': '09:00 - 09:50', 'subject': 'Design and Analysis of Algorithms', 'room': 'Room C-201'},
      {'time': '10:30 - 11:20', 'subject': 'Data Structures', 'room': 'Room C-204'},
      {'time': '11:30 - 12:20', 'subject': 'DBMS', 'room': 'Room C-302'},
      {'time': '01:30 - 02:20', 'subject': 'Operating Systems', 'room': 'Room C-201'},
      {'time': '02:30 - 03:20', 'subject': 'Computer Networks', 'room': 'Room C-404'},
    ],
    'Tue': [
      {'time': '09:00 - 09:50', 'subject': 'Information Management System', 'room': 'Room C-202'},
      {'time': '10:30 - 11:20', 'subject': 'Web Technologies', 'room': 'Room C-205'},
    ],
    'Wed': [],
    'Thu': [],
    'Fri': [],
    'Sat': [],
  };

  @override
  Widget build(BuildContext context) {
    final currentSlots = timetableData[selectedDay] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day Selector Tabs
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                itemBuilder: (context, index) {
                  String day = days[index];
                  bool isSelected = day == selectedDay;
                  return GestureDetector(
                    onTap: () => setState(() => selectedDay = day),
                    child: Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Timetable Slot List
            Expanded(
              child: currentSlots.isEmpty
                  ? const Center(
                      child: Text(
                        'No classes scheduled for today',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: currentSlots.length,
                      itemBuilder: (context, index) {
                        final slot = currentSlots[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot['time']!,
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot['subject']!,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      slot['room']!,
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
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

            // Manual Timetable Update / PDF Upload Button
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: const Text(
                  'Upload New Timetable (PDF)',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  // Trigger local file picker / cache refresh for 30 days
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}