import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keySession = 'user_session';
  static const String _keyAttendance = 'cached_attendance';
  static const String _keyTimetable = 'cached_timetable';
  static const String _keyTarget = 'target_attendance';
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyNotifications = 'notifications_enabled';

  static Future<void> saveSession(String name, String hallTicket) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySession, jsonEncode({'name': name, 'hallTicket': hallTicket}));
  }

  static Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keySession);
    if (data == null) return {};
    return jsonDecode(data);
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySession, jsonEncode(profile));
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keySession);
    if (data == null) return {};
    return jsonDecode(data);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
    await prefs.remove(_keyAttendance);
    await prefs.remove(_keyTimetable);
  }

  static Future<void> saveAttendance(List<Map<String, dynamic>> attendanceData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAttendance, jsonEncode(attendanceData));
  }

  static Future<List<Map<String, dynamic>>> getAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyAttendance);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  static Future<void> saveTimetable(List<Map<String, dynamic>> timetableData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimetable, jsonEncode(timetableData));
  }

  static Future<List<Map<String, dynamic>>> getTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyTimetable);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  static Future<void> saveTarget(int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTarget, target);
  }

  static Future<int> getTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTarget) ?? 75;
  }

  static Future<void> saveDarkModePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, isDark);
  }

  static Future<bool> getDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? true;
  }

  static Future<void> saveNotificationPreference(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, isEnabled);
  }

  static Future<bool> getNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifications) ?? false; // Defaults to false (off initially)
  }
}