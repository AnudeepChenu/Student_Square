import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keySession = 'user_session';
  static const String _keyAttendance = 'cached_attendance';
  static const String _keyTimetable = 'cached_timetable';
  static const String _keyTarget = 'target_attendance';
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyHolidays = 'cached_holidays';
  static const String _keySraapLoggedIn = 'sraap_logged_in';

  // ============================================================
  // USER PROFILE / SESSION
  // ============================================================

  static Future<void> saveProfile(
    Map<String, dynamic> profile,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _keySession,
      jsonEncode(profile),
    );
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_keySession);

    if (data == null || data.isEmpty) {
      return {};
    }

    try {
      return Map<String, dynamic>.from(
        jsonDecode(data),
      );
    } catch (_) {
      return {};
    }
  }

  // ============================================================
  // CLEAR USER SESSION
  // ============================================================
  //
  // IMPORTANT:
  // Timetable is intentionally NOT removed here.
  //
  // Timetable is local application data and should survive:
  // - app restart
  // - app close
  // - SRAAP logout
  // - session expiry
  //
  // It is replaced ONLY when the user explicitly syncs a
  // new timetable.
  // ============================================================

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keySession);
    await prefs.remove(_keyAttendance);
    await prefs.remove(_keyHolidays);
    await prefs.remove(_keySraapLoggedIn);

    // DO NOT REMOVE:
    // await prefs.remove(_keyTimetable);
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  static Future<void> saveAttendance(
    List<Map<String, dynamic>> attendanceData,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _keyAttendance,
      jsonEncode(attendanceData),
    );
  }

  static Future<List<Map<String, dynamic>>> getAttendance() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_keyAttendance);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(data);

      return List<Map<String, dynamic>>.from(
        decoded.map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // TIMETABLE
  // ============================================================

  /// Saves the latest successfully synced timetable.
  ///
  /// This replaces the previous timetable.
  static Future<void> saveTimetable(
    List<Map<String, dynamic>> timetableData,
  ) async {
    // Never replace a valid timetable with empty data.
    if (timetableData.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _keyTimetable,
      jsonEncode(timetableData),
    );
  }

  /// Returns the timetable stored locally on the device.
  ///
  /// No internet request is made here.
  static Future<List<Map<String, dynamic>>> getTimetable() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_keyTimetable);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(data);

      return List<Map<String, dynamic>>.from(
        decoded.map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    } catch (_) {
      return [];
    }
  }

  /// Optional explicit method if you ever want to intentionally
  /// delete the locally stored timetable.
  static Future<void> clearTimetable() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyTimetable);
  }

  // ============================================================
  // HOLIDAYS
  // ============================================================

  static Future<void> saveHolidays(
    List<Map<String, dynamic>> holidayData,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _keyHolidays,
      jsonEncode(holidayData),
    );
  }

  static Future<List<Map<String, dynamic>>> getHolidays() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_keyHolidays);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(data);

      return List<Map<String, dynamic>>.from(
        decoded.map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // TARGET ATTENDANCE
  // ============================================================

  static Future<void> saveTarget(int target) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      _keyTarget,
      target,
    );
  }

  static Future<int> getTarget() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(_keyTarget) ?? 75;
  }

  // ============================================================
  // DARK MODE
  // ============================================================

  static Future<void> saveDarkModePreference(
    bool isDark,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _keyDarkMode,
      isDark,
    );
  }

  static Future<bool> getDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_keyDarkMode) ?? true;
  }

  // ============================================================
  // SRAAP LOGIN STATE
  // ============================================================

  static Future<void> setSraapLoggedIn(
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _keySraapLoggedIn,
      value,
    );
  }

  static Future<bool> isSraapLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_keySraapLoggedIn) ?? false;
  }

  static Future<void> clearSraapSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keySraapLoggedIn);
  }
}