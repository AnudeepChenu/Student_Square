import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String keyName = 'student_name';
  static const String keyHallTicket = 'student_hall_ticket';

  static Future<void> saveSession(String name, String hallTicket) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyName, name.trim());
    await prefs.setString(keyHallTicket, hallTicket.trim());
  }

  static Future<Map<String, String?>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(keyName),
      'hallTicket': prefs.getString(keyHallTicket),
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyName);
    await prefs.remove(keyHallTicket);
  }
}