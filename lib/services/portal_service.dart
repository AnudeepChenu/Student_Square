import 'dart:convert';
import 'package:http/http.dart' as http;

class PortalService {
  // Use localhost for local emulator/Chrome testing. 
  // If testing on a physical Android device, replace with your Mac's local IP address (e.g., http://192.168.x.x:3000)
  static const String backendUrl = 'http://localhost:3000/api/scrape-attendance';

  static Future<List<Map<String, dynamic>>> fetchAttendanceFromBackend(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          List data = decoded['data'];
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      return [];
    } catch (e) {
      // Network or connection error fallback
      return [];
    }
  }
}