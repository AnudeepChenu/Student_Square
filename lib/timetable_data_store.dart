import 'package:flutter/foundation.dart';
import 'session_manager.dart';

/// Single live source of timetable class data used by the UI.
///
/// SessionManager is only used here to restore the last valid timetable when
/// the application starts. Home and Timetable UI do not read the
/// timetable cache directly.
class TimetableDataStore {
  TimetableDataStore._();

  static final TimetableDataStore instance = TimetableDataStore._();

  List<Map<String, dynamic>> _classes = <Map<String, dynamic>>[];
  bool _loaded = false;

  List<Map<String, dynamic>> get classes =>
      List<Map<String, dynamic>>.unmodifiable(_classes);

  bool get hasClasses => _classes.isNotEmpty;

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    final cached = await SessionManager.getTimetable();
    setClasses(cached);
  }

  void setClasses(List<Map<String, dynamic>> classes) {
    _classes = classes
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _loaded = true;

    debugPrint(
      'TimetableDataStore -> ${_classes.length} live classes loaded',
    );
  }

  void clear() {
    _classes = <Map<String, dynamic>>[];
    _loaded = true;
  }
}
