import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../session_manager.dart';

class PortalWebViewScreen extends StatefulWidget {
  final String initialUrl;
  const PortalWebViewScreen({super.key, this.initialUrl = 'https://sraap.in'});

  @override
  State<PortalWebViewScreen> createState() => _PortalWebViewScreenState();
}

class _PortalWebViewScreenState extends State<PortalWebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => isLoading = true),
          onPageFinished: (String url) => setState(() => isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _extractAndSaveAttendance() async {
    try {
      final String script = '''
        (function() {
          const rows = document.querySelectorAll('tr');
          if (rows.length === 0) return JSON.stringify([]);
          let subjectList = [];
          rows.forEach(row => {
            const cells = row.children;
            if (cells.length >= 5) {
              const courseLink = cells[1].querySelector('a');
              if (courseLink && courseLink.href.includes('attendance')) {
                const name = courseLink.innerText.trim();
                const held = parseInt(cells[3].innerText.trim(), 10) || 0;
                const pr = parseInt(cells[4].innerText.trim(), 10) || 0;
                if (held > 0) {
                  subjectList.push({ name: name, held: held, present: pr });
                }
              }
            }
          });
          return JSON.stringify(subjectList);
        })();
      ''';

      final result = await controller.runJavaScriptReturningResult(script);
      if (result != null) {
        String rawJson = result.toString();
        if (rawJson.startsWith('"') && rawJson.endsWith('"')) {
          rawJson = rawJson.substring(1, rawJson.length - 1);
          rawJson = rawJson.replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
        }

        List<dynamic> decodedData = jsonDecode(rawJson);
        List<Map<String, dynamic>> parsedSubjects = [];

        for (var item in decodedData) {
          if (item is Map) {
            parsedSubjects.add({
              'name': item['name']?.toString() ?? 'Subject',
              'present': int.tryParse(item['present'].toString()) ?? 0,
              'held': int.tryParse(item['held'].toString()) ?? 0,
            });
          }
        }

        if (parsedSubjects.isNotEmpty) {
          await SessionManager.saveAttendance(parsedSubjects);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attendance synced successfully!')),
            );
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No attendance table found. Please select batch/course.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Attendance Scraping Error: $e');
    }
  }

  Future<void> _extractAndSaveTimetable() async {
    try {
      final String script = '''
        (function() {
          const table = document.querySelector('table');
          if (!table) return JSON.stringify([]);
          
          const rows = table.querySelectorAll('tr');
          if (rows.length === 0) return JSON.stringify([]);
          
          const headerCells = rows[0].querySelectorAll('th, td');
          let dayMap = {};
          
          headerCells.forEach((cell, index) => {
            const text = cell.innerText.trim().toLowerCase();
            if (text.includes('monday')) dayMap[index] = 'Monday';
            else if (text.includes('tuesday')) dayMap[index] = 'Tuesday';
            else if (text.includes('wednesday')) dayMap[index] = 'Wednesday';
            else if (text.includes('thursday')) dayMap[index] = 'Thursday';
            else if (text.includes('friday')) dayMap[index] = 'Friday';
            else if (text.includes('saturday')) dayMap[index] = 'Saturday';
            else if (text.includes('sunday')) dayMap[index] = 'Sunday';
          });
          
          let scheduleList = [];
          
          for (let i = 1; i < rows.length; i++) {
            const cells = rows[i].querySelectorAll('td, th');
            if (cells.length > 0) {
              const timeSlot = cells[0].innerText.trim();
              
              for (let j = 1; j < cells.length; j++) {
                if (dayMap[j]) {
                  const subjectText = cells[j].innerText.trim();
                  if (subjectText.length > 0) {
                    scheduleList.push({
                      day: dayMap[j],
                      subject: subjectText,
                      time: timeSlot
                    });
                  }
                }
              }
            }
          }
          
          return JSON.stringify(scheduleList);
        })();
      ''';

      final result = await controller.runJavaScriptReturningResult(script);
      if (result != null) {
        String rawJson = result.toString();
        if (rawJson.startsWith('"') && rawJson.endsWith('"')) {
          rawJson = rawJson.substring(1, rawJson.length - 1);
          rawJson = rawJson.replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
        }

        List<dynamic> decodedData = jsonDecode(rawJson);
        List<Map<String, dynamic>> parsedTimetable = [];

        for (var item in decodedData) {
          if (item is Map) {
            parsedTimetable.add({
              'day': item['day']?.toString() ?? 'Monday',
              'subject': item['subject']?.toString() ?? '',
              'time': item['time']?.toString() ?? '',
            });
          }
        }

        if (parsedTimetable.isNotEmpty) {
          await SessionManager.saveTimetable(parsedTimetable);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Timetable synced and ordered successfully!')),
            );
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No entries found in the table grid.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Timetable Scraping Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _extractAndSaveAttendance,
                child: const Text('Sync Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _extractAndSaveTimetable,
                child: const Text('Sync Timetable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}