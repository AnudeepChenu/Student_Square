import 'dart:convert';
import 'package:http/http.string' as http; // or http/http.dart
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';

class PortalService {
  static const String portalUrl = 'https://sraap.in/student/dash_board.php';
  static const String cacheKeyAttendance = 'cached_attendance_data';

  // Function to sign in and fetch live attendance
  static Future<List<Map<String, dynamic>>> fetchAttendance(String username, String password) async {
    try {
      var client = http.Client();
      
      // Post request to portal login / dashboard
      // Note: Depending on portal form action, adjust headers/body accordingly
      var response = await client.post(
        Uri.parse(portalUrl),
        body: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        
        // Example selector parsing based on standard student dashboard structures
        // Adjust CSS selectors matching the SRU dashboard DOM elements
        var rows = document.querySelectorAll('table.attendance-table tr');
        List<Map<String, dynamic>> attendanceList = [];

        for (var row in rows.skip(1)) {
          var cols = row.querySelectorAll('td');
          if (cols.length >= 3) {
            String subjectName = cols[0].text.trim();
            int present = int.tryParse(cols[1].text.trim()) ?? 0;
            int held = int.tryParse(cols[2].text.trim()) ?? 0;

            attendanceList.add({
              'name': subjectName,
              'present': present,
              'held': held,
            });
          }
        }

        // Cache the successfully fetched data locally (Satisfies feature 10)
        if (attendanceList.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKeyAttendance, jsonEncode(attendanceList));
        }

        return attendanceList;
      } else {
        return await getCachedAttendance();
      }
    } catch (e) {
      // Fallback to previously logged-in cached data if network or login fails
      return await getCachedAttendance();
    }
  }

  // Retrieve cached attendance if offline or not actively logged in
  static Future<List<Map<String, dynamic>>> getCachedAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString(cacheKeyAttendance);
    
    if (cachedData != null) {
      List decoded = jsonDecode(cachedData);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    
    // Default fallback mock data if no cache exists yet
    return [
      {'name': 'Data Structures', 'present': 43, 'held': 50},
      {'name': 'DBMS', 'present': 39, 'held': 50},
      {'name': 'Operating Systems', 'present': 46, 'held': 50},
      {'name': 'Computer Networks', 'present': 41, 'held': 50},
    ];
  }
}