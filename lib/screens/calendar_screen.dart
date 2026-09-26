import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../session_manager.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with WidgetsBindingObserver {
  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> calendarEvents = [];
  List<Map<String, dynamic>> timetable = [];

  bool isLoading = true;
  bool isParsing = false;

  late DateTime currentMonth;
  late DateTime selectedDate;

  // Years that actually occur in the uploaded academic calendar.
  // Timetable rows are never applied to dates outside these years.
  final Set<int> _calendarYears = <int>{};

  static const List<String> _calendarAudiences = [
    'For UG Students',
    'For PG Students',
    'For UG/PG Final Year Students',
    'For PhD Scholars',
  ];

  String _selectedAudience = 'For UG Students';

  // Years are collected from every date row, including ordinary working
  // days, so timetable data is never reused outside the actual PDF years.
  final Set<int> _detectedCalendarYears = <int>{};

  final List<String> weekDays = const [
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
  ];

  // StudentSquare unified visual system — shared with Attendance + Timetable.
  static const Color _accent = Color(0xFF6376F5);
  static const Color _healthy = Color(0xFF55C98A);
  static const Color _warning = Color(0xFFE0B84F);
  static const Color _danger = Color(0xFFE86B6B);

  static const Color _darkBackground = Color(0xFF090A0B);
  static const Color _darkSurface = Color(0xFF111315);
  static const Color _darkSecondary = Color(0xFF181A1D);
  static const Color _lightBackground = Color(0xFFF6F6F3);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSecondary = Color(0xFFEEEEEA);

  // ============================================================
  // PDF COLOR TERMINOLOGY
  //
  // These are the colors used by the supplied academic-calendar
  // template. The parser does NOT classify from words such as
  // "exam" or "holiday". It samples the actual background color
  // of the selected audience table cell.
  //
  // Small RGB variations are accepted so another PDF exported with
  // the same color terminology still works.
  // ============================================================

  static const List<_PdfColorPrototype> _pdfColors = [
    _PdfColorPrototype(
      type: 'Holiday',
      rgb: [255, 255, 0],
    ),

    _PdfColorPrototype(
      type: 'Club',
      rgb: [196, 228, 237],
    ),

    // The calendar uses more than one light-blue shade for exams.
    _PdfColorPrototype(
      type: 'Exam',
      rgb: [218, 237, 242],
    ),

    _PdfColorPrototype(
      type: 'Exam',
      rgb: [182, 221, 232],
    ),

    _PdfColorPrototype(
      type: 'Weekend',
      rgb: [246, 149, 70],
    ),

    _PdfColorPrototype(
      type: 'Weekend',
      rgb: [216, 216, 216],
    ),
  ];

  static const double _pdfColorTolerance = 18.0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final DateTime now = DateTime.now();

    currentMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    final now = DateTime.now();
    final todayMonth = DateTime(now.year, now.month, 1);
    final changed =
        selectedDate.year != now.year ||
        selectedDate.month != now.month ||
        selectedDate.day != now.day;

    if (changed) {
      setState(() {
        selectedDate = DateTime(now.year, now.month, now.day);
        currentMonth = todayMonth;
      });
    }
  }

  // ============================================================
  // LOAD SAVED DATA
  // ============================================================

  Future<void> _loadData() async {
    try {
      final cachedEvents = await SessionManager.getHolidays();
      final cachedTimetable = await SessionManager.getTimetable();

      if (!mounted) return;

      final Set<int> cachedYears = <int>{};
      for (final Map<String, dynamic> event in cachedEvents) {
        final String value = event['date']?.toString() ?? '';
        final DateTime? parsed = DateTime.tryParse(value);
        if (parsed != null) cachedYears.add(parsed.year);
      }

      setState(() {
        calendarEvents = cachedEvents;
        timetable = cachedTimetable;
        _calendarYears
          ..clear()
          ..addAll(cachedYears);
        isLoading = false;
      });

      if (cachedEvents.isEmpty) {
        await _parseBundledPdf(showMessage: false);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // UPLOAD ANOTHER PDF
  // ============================================================

  Future<void> _pickAndParsePdf() async {
    if (isParsing) return;

    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (file == null) return;

      final Uint8List bytes = await file.readAsBytes();

      await _parsePdfBytes(
        bytes,
        sourceName: file.name,
        showMessage: true,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open PDF: $e'),
        ),
      );
    }
  }

  // ============================================================
  // LOAD THE DEFAULT BUNDLED PDF
  // ============================================================

  Future<void> _parseBundledPdf({
    bool showMessage = true,
  }) async {
    try {
      final ByteData data = await rootBundle.load(
        'assets/3_1 calendar.pdf',
      );

      await _parsePdfBytes(
        data.buffer.asUint8List(),
        sourceName: '3_1 calendar.pdf',
        showMessage: showMessage,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isParsing = false;
      });

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading bundled calendar PDF: $e'),
          ),
        );
      }
    }
  }

  // ============================================================
  // MAIN PDF PIPELINE
  //
  // This version does NOT use pdf_render or pdf_render_maintained.
  // It reads the PDF content streams directly and finds filled
  // rectangles in the actual PDF drawing commands.
  //
  // Classification source of truth:
  //   - ONLY the currently selected audience column
  //   - ONLY the cell background fill color
  //   - Text such as "exam" or "holiday" is never used to decide
  //     the event type.
  // ============================================================

  Future<void> _parsePdfBytes(
    Uint8List bytes, {
    required String sourceName,
    bool showMessage = true,
  }) async {
    if (isParsing) return;

    if (mounted) {
      setState(() {
        isParsing = true;
      });
    }

    PdfDocument? document;

    try {
      document = PdfDocument(inputBytes: bytes);

      // Parse the PDF drawing streams once. This replaces the old
      // raster renderer and therefore does not require any native
      // PDF-rendering plugin.
      final _PdfColorStreamParser colorParser =
          _PdfColorStreamParser(bytes);

      final List<Map<String, dynamic>> parsedEvents = [];
      _detectedCalendarYears.clear();
      final int pageCount = document.pages.count;

      for (int pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        final List<Map<String, dynamic>> pageEvents =
            _parseCalendarPage(
          document,
          colorParser,
          pageIndex,
        );

        parsedEvents.addAll(pageEvents);
      }

      // Keep one event per date. If a PDF accidentally contains the
      // same date more than once, the later table occurrence wins.
      final Map<String, Map<String, dynamic>> uniqueEvents = {};

      for (final Map<String, dynamic> event in parsedEvents) {
        final String eventAudience =
            event['audience']?.toString() ?? 'For UG Students';
        final String eventDate = event['date'].toString();
        uniqueEvents['$eventAudience|$eventDate'] = event;
      }

      final List<Map<String, dynamic>> finalEvents =
          uniqueEvents.values.toList()
            ..sort(
              (a, b) => a['date']
                  .toString()
                  .compareTo(b['date'].toString()),
            );

      await SessionManager.saveHolidays(finalEvents);

      final Set<int> parsedYears = <int>{..._detectedCalendarYears};
      // Fallback for legacy parser output/cached data.
      for (final Map<String, dynamic> event in finalEvents) {
        final String value = event['date']?.toString() ?? '';
        final DateTime? parsed = DateTime.tryParse(value);
        if (parsed != null) parsedYears.add(parsed.year);
      }

      if (!mounted) return;

      setState(() {
        calendarEvents = finalEvents;
        _calendarYears
          ..clear()
          ..addAll(parsedYears);
        isParsing = false;
      });

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalEvents.isEmpty
                  ? 'No coloured calendar dates found in $sourceName.'
                  : '${finalEvents.length} calendar dates synced from $sourceName.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isParsing = false;
      });

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading calendar PDF: $e'),
          ),
        );
      }
    } finally {
      document?.dispose();
    }
  }

  // ============================================================
  // PARSE ONE PAGE
  // ============================================================

  List<Map<String, dynamic>> _parseCalendarPage(
    PdfDocument document,
    _PdfColorStreamParser colorParser,
    int pageIndex,
  ) {
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final List<TextLine> lines = extractor.extractTextLines(
      startPageIndex: pageIndex,
      endPageIndex: pageIndex,
    );
    if (lines.isEmpty) return [];

    final _PdfPageInfo pageInfo = colorParser.pageInfo(pageIndex);
    if (pageInfo.filledRects.isEmpty) return [];

    final double pageHeight = document.pages[pageIndex].size.height;
    final double pageWidth = document.pages[pageIndex].size.width;
    final RegExp dateRegex = RegExp(
      r'^\s*(\d{1,2})[-/.](\d{1,2})[-/.](20\d{2})\b',
    );
    final List<TextLine> dateLines = lines
        .where((line) => dateRegex.hasMatch(line.text))
        .toList();
    final List<Map<String, dynamic>> events = [];

    for (final TextLine dateLine in dateLines) {
      final Match? match = dateRegex.firstMatch(dateLine.text);
      if (match == null) continue;
      final DateTime? date = _parseDate(
        match.group(1)!, match.group(2)!, match.group(3)!,
      );
      if (date == null) continue;
      _detectedCalendarYears.add(date.year);
      if (date.weekday == DateTime.sunday) continue;
      final double dateY = dateLine.bounds.center.dy;

      for (final String audience in _calendarAudiences) {
        final _CalendarColumnBounds bounds =
            _findCalendarColumnBounds(audience, pageWidth);
        final _PdfFilledRect? cell = _findBestCalendarBackgroundRect(
          pageInfo.filledRects, bounds, dateY, pageHeight,
        );
        if (cell == null) continue;
        final String colorType = _classifyPdfRgb(
          cell.red, cell.green, cell.blue,
        );
        if (colorType == 'Regular') continue;
        final String name = _extractCalendarTextForPdfRow(
          lines, bounds, dateY, cell, pageHeight,
        );
        events.add({
          'date': _formatDate(date),
          'name': name.isEmpty ? _defaultEventName(colorType) : name,
          'type': colorType,
          'audience': audience,
          'rgb': [cell.red, cell.green, cell.blue],
        });
      }
    }
    return events;
  }

  _PdfFilledRect? _findBestCalendarBackgroundRect(
    List<_PdfFilledRect> rects,
    _CalendarColumnBounds bounds,
    double dateY,
    double pageHeight,
  ) {
    _PdfFilledRect? best;
    double bestScore = double.negativeInfinity;
    for (final _PdfFilledRect rect in rects) {
      if (rect.width < 20 || rect.height < 5) continue;
      final double overlapLeft = rect.left > bounds.left ? rect.left : bounds.left;
      final double overlapRight = rect.right < bounds.right ? rect.right : bounds.right;
      if (overlapRight <= overlapLeft) continue;
      final double top = pageHeight - rect.topPdf;
      final double bottom = pageHeight - rect.bottomPdf;
      if (dateY < top - 3 || dateY > bottom + 3) continue;
      final String type = _classifyPdfRgb(rect.red, rect.green, rect.blue);
      if (type == 'Regular') continue;
      final double centerDistance = (dateY - ((top + bottom) / 2)).abs();
      final double horizontalOverlap = overlapRight - overlapLeft;
      final double area = rect.width * rect.height;
      final double sizePenalty = area > 12000 ? (area - 12000) * 0.001 : 0;
      final double score = 100000 - centerDistance * 140 + horizontalOverlap * 3 - sizePenalty;
      if (score > bestScore) {
        bestScore = score;
        best = rect;
      }
    }
    return best;
  }

  String _classifyPdfRgb(int r, int g, int b) {
    double distanceTo(List<int> rgb) {
      final double dr = (r - rgb[0]).toDouble();
      final double dg = (g - rgb[1]).toDouble();
      final double db = (b - rgb[2]).toDouble();
      return (dr * dr + dg * dg + db * db) / 3.0;
    }
    String bestType = 'Regular';
    double bestDistance = double.infinity;
    for (final _PdfColorPrototype prototype in _pdfColors) {
      final double distance = distanceTo(prototype.rgb);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestType = prototype.type;
      }
    }
    return bestDistance <= _pdfColorTolerance * _pdfColorTolerance
        ? bestType : 'Regular';
  }

  _CalendarColumnBounds _findCalendarColumnBounds(String audience, double pageWidth) {
    final Map<String, List<double>> columns = {
      'For UG Students': [186.60, 335.76],
      'For PG Students': [335.76, 474.48],
      'For UG/PG Final Year Students': [474.48, 570.84],
      'For PhD Scholars': [570.84, 717.36],
    };
    final List<double> x = columns[audience] ?? columns['For UG Students']!;
    return _CalendarColumnBounds(
      left: pageWidth >= 700 ? x[0] : pageWidth * x[0] / 792.0,
      right: pageWidth >= 700 ? x[1] : pageWidth * x[1] / 792.0,
    );
  }

  String _extractCalendarTextForPdfRow(
    List<TextLine> lines,
    _CalendarColumnBounds bounds,
    double dateY,
    _PdfFilledRect cell,
    double pageHeight,
  ) {
    final double rowTop = pageHeight - cell.topPdf - 2;
    final double rowBottom = pageHeight - cell.bottomPdf + 2;
    final List<String> parts = [];
    for (final TextLine line in lines) {
      final Rect b = line.bounds;
      if (b.center.dx < bounds.left || b.center.dx > bounds.right) continue;
      if (b.center.dy < rowTop || b.center.dy > rowBottom) continue;
      if (RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]20\d{2}\b').hasMatch(line.text)) continue;
      final String text = line.text.trim();
      if (text.isNotEmpty) parts.add(text);
    }
    return _normalizeText(parts.join(' '));
  }

  String _defaultEventName(String type) {
    switch (type) {
      case 'Holiday':
        return 'Holiday';
      case 'Club':
        return 'Club Activity';
      case 'Exam':
        return 'Examination';
      case 'Weekend':
        return 'Weekend Break';
      default:
        return 'Academic Calendar Event';
    }
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _parseDate(
    String day,
    String month,
    String year,
  ) {
    try {
      final int d = int.parse(day);
      final int m = int.parse(month);
      final int y = int.parse(year);

      final DateTime date = DateTime(y, m, d);

      if (date.year != y ||
          date.month != m ||
          date.day != d) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _normalizeText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _getMonthName(int month) {
    const List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return days[weekday - 1];
  }

  // ============================================================
  // EVENT LOOKUP
  // ============================================================

  Map<String, dynamic>? _getEventForDate(
    DateTime date,
  ) {
    final String dateString =
        _formatDate(date);

    for (final Map<String, dynamic> event
        in calendarEvents) {
      final String audience = event['audience']?.toString() ?? 'For UG Students';
      if (event['date'] == dateString && audience == _selectedAudience) {
        return event;
      }
    }

    return null;
  }

  String _getEventType(
    DateTime date,
  ) {
    if (_isSunday(date)) {
      return 'Sunday';
    }

    final Map<String, dynamic>? event =
        _getEventForDate(date);

    return event?['type']?.toString() ??
        'Regular';
  }

  String? _getEventNameForDate(
    DateTime date,
  ) {
    final Map<String, dynamic>? event =
        _getEventForDate(date);

    if (event != null) {
      return event['name']?.toString();
    }

    if (_isSunday(date)) {
      return 'Sunday';
    }

    return null;
  }

  bool _isSunday(
    DateTime date,
  ) {
    return date.weekday ==
        DateTime.sunday;
  }

  bool _isHoliday(
    DateTime date,
  ) {
    return _getEventType(date) ==
        'Holiday';
  }

  bool _isExam(
    DateTime date,
  ) {
    return _getEventType(date) ==
        'Exam';
  }

  bool _isClub(
    DateTime date,
  ) {
    return _getEventType(date) ==
        'Club';
  }

  bool _isWeekend(
    DateTime date,
  ) {
    return _getEventType(date) ==
        'Weekend';
  }

  // ============================================================
  // MONTH NAVIGATION
  // ============================================================

  void _previousMonth() {
    setState(() {
      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      currentMonth = DateTime(
        currentMonth.year,
        currentMonth.month + 1,
        1,
      );
    });
  }

  // ============================================================
  // TIMETABLE DETAILS
  // ============================================================

  Map<String, String> _parseDetails(
    String rawSubject,
    String rawTime,
  ) {
    String subject = rawSubject;
    String room = '';
    String faculty = '';

    try {
      if (rawSubject.contains(':')) {
        final List<String> parts =
            rawSubject.split(':');

        subject = parts[0].trim();

        if (parts.length > 1) {
          String secondPart =
              parts[1].trim();

          final RegExp roomReg =
              RegExp(r'\(([^)]+)\)');

          final Match? match =
              roomReg.firstMatch(
            secondPart,
          );

          if (match != null) {
            final String roomBlock =
                match.group(1) ?? '';

            room = roomBlock
                .split('-')
                .first
                .trim();

            secondPart =
                secondPart.replaceAll(
              match.group(0)!,
              '',
            ).trim();
          }

          faculty = secondPart;
        }
      }
    } catch (_) {
      subject = rawSubject;
    }

    return {
      'subject': subject,
      'faculty': faculty.isEmpty
          ? 'Faculty Name'
          : faculty,
      'room': room.isEmpty
          ? 'N/A'
          : room,
      'time': rawTime,
    };
  }

  // ============================================================
  // SETTINGS POPUP
  // ============================================================

  Future<void> _showCalendarSettings() async {
    String draftAudience = _selectedAudience;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final ThemeData dialogTheme = Theme.of(dialogContext);
        final bool dark = dialogTheme.brightness == Brightness.dark;
        final Color surface = dark
            ? const Color(0xFF171718)
            : Colors.white;
        final Color primary = dark
            ? const Color(0xFFF0F0F0)
            : const Color(0xFF171717);
        final Color secondary = dark
            ? const Color(0xFF96969B)
            : const Color(0xFF6F6F73);
        final Color divider = dark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.08);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              title: Row(
                children: [
                  Icon(Icons.settings_rounded, color: _accent, size: 21),
                  const SizedBox(width: 10),
                  Text(
                    'Calendar Settings',
                    style: TextStyle(
                      color: primary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calendar is for',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF101011)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: divider),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: draftAudience,
                        isExpanded: true,
                        dropdownColor: surface,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: secondary,
                        ),
                        style: TextStyle(
                          color: primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _calendarAudiences
                            .map(
                              (audience) => DropdownMenuItem<String>(
                                value: audience,
                                child: Text(audience),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => draftAudience = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: divider),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _healthy.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.upload_file_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Upload calendar PDF',
                      style: TextStyle(
                        color: primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Import a new academic calendar',
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      await _pickAndParsePdf();
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: secondary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedAudience = draftAudience);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(color: _accent, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================

  // ============================================================
  // MODERN UI
  // ============================================================

  Widget _iconAction({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required bool isDark,
    bool active = false,
    String? tooltip,
  }) {
    final background = active
        ? _accent
        : isDark
            ? _darkSecondary
            : _lightSecondary;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              border: Border.all(
                color: active
                    ? _accent.withOpacity(0.35)
                    : isDark
                        ? Colors.white.withOpacity(0.055)
                        : Colors.black.withOpacity(0.055),
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: active
                  ? Colors.white
                  : onPressed == null
                      ? color.withOpacity(0.35)
                      : color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label, {
    required Color secondary,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: secondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader(
    Color primary,
    Color secondary,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACADEMIC CALENDAR',
                style: TextStyle(
                  color: secondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Calendar',
                style: TextStyle(
                  color: primary,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_getMonthName(currentMonth.month)} ${currentMonth.year}',
                style: TextStyle(
                  color: secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _iconAction(
          icon: Icons.sync_rounded,
          onPressed: isParsing ? null : _parseBundledPdf,
          color: _accent,
          isDark: isDark,
          tooltip: 'Update calendar',
        ),
        const SizedBox(width: 6),
        _iconAction(
          icon: Icons.tune_rounded,
          onPressed: isParsing ? null : _showCalendarSettings,
          color: secondary,
          isDark: isDark,
          tooltip: 'Calendar settings',
        ),
      ],
    );
  }

  Widget _buildMonthNavigation(
    Color primary,
    Color secondary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
      decoration: BoxDecoration(
        color: isDark ? _darkSurface : _lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.055)
              : Colors.black.withOpacity(0.055),
        ),
      ),
      child: Row(
        children: [
          _monthButton(
            Icons.chevron_left_rounded,
            _previousMonth,
            secondary,
            isDark,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _getMonthName(currentMonth.month),
                  style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${currentMonth.year}',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _monthButton(
            Icons.chevron_right_rounded,
            _nextMonth,
            secondary,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _monthButton(
    IconData icon,
    VoidCallback action,
    Color color,
    bool isDark,
  ) {
    return Material(
      color: isDark ? _darkSecondary : _lightSecondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildMonthGrid(
    Color primaryText,
    Color secondaryText,
    bool isDark,
  ) {
    final int daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final int firstWeekday =
        DateTime(currentMonth.year, currentMonth.month, 1).weekday % 7;

    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: isDark ? _darkSurface : _lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.055)
              : Colors.black.withOpacity(0.055),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: weekDays.asMap().entries.map((entry) {
              final bool sunday = entry.key == 0 || entry.key == 6;
              return Expanded(
                child: Center(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: sunday
                          ? _danger.withOpacity(0.82)
                          : secondaryText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 3,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox();

              final int day = index - firstWeekday + 1;
              final date =
                  DateTime(currentMonth.year, currentMonth.month, day);
              final type = _getEventType(date);
              final eventName = _getEventNameForDate(date);

              final bool selected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;

              final bool isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              final bool sunday = _isSunday(date);

              Color? eventFill;
              Color dayColor = primaryText;
              Color eventColor = secondaryText;

              switch (type) {
                case 'Holiday':
                  eventColor = _warning;
                  eventFill = _warning.withOpacity(0.12);
                  dayColor = _warning;
                  break;
                case 'Exam':
                  eventColor = _accent;
                  eventFill = _accent.withOpacity(0.10);
                  dayColor = _accent;
                  break;
                case 'Club':
                  eventColor = _healthy;
                  eventFill = _healthy.withOpacity(0.10);
                  dayColor = _healthy;
                  break;
                case 'Weekend':
                  eventColor = secondaryText;
                  eventFill = secondaryText.withOpacity(0.07);
                  dayColor = secondaryText;
                  break;
                case 'Sunday':
                  eventColor = _danger;
                  dayColor = _danger;
                  break;
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => selectedDate = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: selected
                        ? _accent.withOpacity(0.15)
                        : eventFill ?? Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isToday
                          ? _accent
                          : selected
                              ? _accent.withOpacity(0.75)
                              : Colors.transparent,
                      width: isToday ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: dayColor,
                          fontSize: 14,
                          fontWeight: selected ||
                                  isToday ||
                                  type != 'Regular'
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (type != 'Regular')
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: selected ? 6 : 5,
                          height: selected ? 6 : 5,
                          decoration: BoxDecoration(
                            color: eventColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      else if (sunday)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: _danger,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateHeader(
    Color primary,
    Color secondary,
    String type,
    bool isDark,
  ) {
    final date = selectedDate;
    final String eventName = _getEventNameForDate(date) ?? '';

    Color eventColor = _accent;
    if (type == 'Sunday') {
      eventColor = _danger;
    } else if (type == 'Holiday') {
      eventColor = _warning;
    } else if (type == 'Exam') {
      eventColor = _accent;
    } else if (type == 'Club') {
      eventColor = _healthy;
    } else if (type == 'Weekend') {
      eventColor = secondary;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECTED DATE',
                style: TextStyle(
                  color: secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${date.day} ${_getMonthName(date.month)}',
                style: TextStyle(
                  color: primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _getWeekdayName(date.weekday),
                style: TextStyle(
                  color: secondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (type != 'Regular')
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: eventColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: eventColor.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: eventColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    eventName.isEmpty ? type : eventName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: eventColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTimetable(
    List<Map<String, dynamic>> classes,
    bool isDark,
    Color calendarBackground,
    Color borderColor,
    Color primaryText,
    Color secondaryText,
  ) {
    return Column(
      children: List.generate(classes.length, (index) {
        final item = classes[index];
        final details = _parseDetails(
          item['subject']?.toString() ?? '',
          item['time']?.toString() ?? '',
        );

        return Container(
          margin: EdgeInsets.only(
            bottom: index == classes.length - 1 ? 0 : 10,
          ),
          padding: const EdgeInsets.fromLTRB(16, 15, 14, 14),
          decoration: BoxDecoration(
            color: calendarBackground,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 58,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details['subject']!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 16,
                        height: 1.10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (details['faculty'] != 'Faculty Name') ...[
                      const SizedBox(height: 5),
                      Text(
                        details['faculty']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      details['time']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (details['room'] != 'N/A') ...[
                      const SizedBox(height: 7),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: secondaryText,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              details['room']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEventCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color primary,
    required Color secondary,
  }) {
    final surface = isDark ? _darkSurface : _lightSurface;
    final border = isDark
        ? Colors.white.withOpacity(0.055)
        : Colors.black.withOpacity(0.055);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSelectedContent(
    String type,
    bool isDark,
    Color calendarBackground,
    Color borderColor,
    Color primaryText,
    Color secondaryText,
    List<Map<String, dynamic>> classes,
  ) {
    if (type == 'Sunday') {
      return _buildEventCard(
        color: _danger,
        icon: Icons.wb_sunny_outlined,
        title: 'Sunday',
        subtitle: 'Non-working day',
        isDark: isDark,
        primary: primaryText,
        secondary: secondaryText,
      );
    }

    if (type == 'Holiday') {
      return _buildEventCard(
        color: _warning,
        icon: Icons.celebration_rounded,
        title: 'Holiday',
        subtitle: _getEventNameForDate(selectedDate) ?? 'Holiday',
        isDark: isDark,
        primary: primaryText,
        secondary: secondaryText,
      );
    }

    if (type == 'Exam') {
      return _buildEventCard(
        color: _accent,
        icon: Icons.menu_book_rounded,
        title: 'Examination',
        subtitle: _getEventNameForDate(selectedDate) ?? 'Examination',
        isDark: isDark,
        primary: primaryText,
        secondary: secondaryText,
      );
    }

    if (type == 'Club') {
      return _buildEventCard(
        color: _healthy,
        icon: Icons.groups_rounded,
        title: 'Club Activity',
        subtitle: _getEventNameForDate(selectedDate) ?? 'Club activity',
        isDark: isDark,
        primary: primaryText,
        secondary: secondaryText,
      );
    }

    if (type == 'Weekend') {
      return _buildEventCard(
        color: secondaryText,
        icon: Icons.weekend_rounded,
        title: 'Weekend Break',
        subtitle: _getEventNameForDate(selectedDate) ?? 'Weekend break',
        isDark: isDark,
        primary: primaryText,
        secondary: secondaryText,
      );
    }

    if (classes.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
        decoration: BoxDecoration(
          color: calendarBackground,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.09),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: _accent,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No classes scheduled',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildTimetable(
      classes,
      isDark,
      calendarBackground,
      borderColor,
      primaryText,
      secondaryText,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color background =
        isDark ? _darkBackground : _lightBackground;
    final Color primaryText =
        isDark ? Colors.white : const Color(0xFF111111);
    final Color secondaryText =
        isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final Color calendarBackground =
        isDark ? _darkSurface : _lightSurface;
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.055)
        : Colors.black.withOpacity(0.055);

    final String selectedType = _getEventType(selectedDate);
    final String selectedDayName = _getWeekdayName(selectedDate.weekday);

    final List<Map<String, dynamic>> filteredClasses = [];

    final bool selectedDateBelongsToCalendar =
        _calendarYears.contains(selectedDate.year);

    if (selectedType == 'Regular' && selectedDateBelongsToCalendar) {
      filteredClasses.addAll(
        timetable.where(
          (item) =>
              item['day']?.toString().trim().toLowerCase() ==
              selectedDayName.toLowerCase(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: isLoading || isParsing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isParsing
                        ? 'Updating calendar'
                        : 'Loading calendar',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              bottom: false,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                children: [
                  _buildCalendarHeader(
                    primaryText,
                    secondaryText,
                    isDark,
                  ),
                  const SizedBox(height: 20),

                  _buildMonthNavigation(
                    primaryText,
                    secondaryText,
                    isDark,
                  ),
                  const SizedBox(height: 10),

                  _buildMonthGrid(
                    primaryText,
                    secondaryText,
                    isDark,
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 15,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem(
                        _accent,
                        'Today',
                        secondary: secondaryText,
                      ),
                      _buildLegendItem(
                        _warning,
                        'Holiday',
                        secondary: secondaryText,
                      ),
                      _buildLegendItem(
                        _accent,
                        'Exam',
                        secondary: secondaryText,
                      ),
                      _buildLegendItem(
                        _healthy,
                        'Club',
                        secondary: secondaryText,
                      ),
                      _buildLegendItem(
                        _danger,
                        'Sunday',
                        secondary: secondaryText,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  _buildSelectedDateHeader(
                    primaryText,
                    secondaryText,
                    selectedType,
                    isDark,
                  ),

                  const SizedBox(height: 12),

                  _buildModernSelectedContent(
                    selectedType,
                    isDark,
                    calendarBackground,
                    borderColor,
                    primaryText,
                    secondaryText,
                    filteredClasses,
                  ),
                ],
              ),
            ),
    );
  }
}

// LIGHTWEIGHT PDF CONTENT-STREAM COLOR READER
//
// The supplied academic calendar is a digital PDF. Its colored
// calendar cells are drawn as PDF rectangles followed by fill
// commands such as:
//
//   1 1 0 sc
//   20.52 249.12 697.32 -11.76 re
//   f*
//
// This reader extracts those actual drawing commands without
// depending on an Android PDF-rendering plugin.
// ================================================================

class _PdfColorStreamParser {
  _PdfColorStreamParser(Uint8List bytes) {
    _parse(bytes);
  }

  final List<_PdfPageInfo> _pages = [];

  _PdfPageInfo pageInfo(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _pages.length) {
      return const _PdfPageInfo(filledRects: []);
    }
    return _pages[pageIndex];
  }

  void _parse(Uint8List bytes) {
    final String source = latin1.decode(
      bytes,
      allowInvalid: true,
    );

    final RegExp objectPattern = RegExp(
      r'(\d+)\s+(\d+)\s+obj\b',
    );

    final List<_PdfRawObject> objects = [];

    for (final Match match in objectPattern.allMatches(source)) {
      final int objectNumber = int.parse(match.group(1)!);
      final int generation = int.parse(match.group(2)!);
      final int bodyStart = match.end;
      final int end = source.indexOf('endobj', bodyStart);

      if (end < 0) continue;

      final String body = source.substring(bodyStart, end);

      objects.add(
        _PdfRawObject(
          number: objectNumber,
          generation: generation,
          body: body,
        ),
      );
    }

    objects.sort((a, b) => a.number.compareTo(b.number));

    final Map<int, _PdfRawObject> byNumber = {
      for (final _PdfRawObject object in objects)
        object.number: object,
    };

    final List<_PdfRawObject> pageObjects = objects.where((object) {
      final String body = object.body;
      return RegExp(r'/Type\s*/Page(?:\s|/|>)')
          .hasMatch(body);
    }).toList();

    for (final _PdfRawObject page in pageObjects) {
      final List<int> contentRefs = _extractReferences(
        page.body,
        '/Contents',
      );

      final List<_PdfFilledRect> rects = [];

      for (final int ref in contentRefs) {
        final _PdfRawObject? streamObject = byNumber[ref];
        if (streamObject == null) continue;

        final Uint8List? decoded =
            _decodeStream(streamObject.body);

        if (decoded == null) continue;

        rects.addAll(
          _extractFilledRectangles(decoded),
        );
      }

      _pages.add(
        _PdfPageInfo(filledRects: rects),
      );
    }
  }

  List<int> _extractReferences(
    String body,
    String key,
  ) {
    final int keyIndex = body.indexOf(key);
    if (keyIndex < 0) return [];

    final String after = body.substring(keyIndex + key.length);

    final Match? arrayMatch = RegExp(
      r'^\s*\[([^\]]+)\]',
      dotAll: true,
    ).firstMatch(after);

    final String target =
        arrayMatch?.group(1) ?? after.substring(0, _safePrefixLength(after));

    final RegExp refPattern = RegExp(r'(\d+)\s+\d+\s+R');

    return refPattern
        .allMatches(target)
        .map((m) => int.parse(m.group(1)!))
        .toList();
  }

  int _safePrefixLength(String text) {
    final int streamIndex = text.indexOf('stream');
    final int closeIndex = text.indexOf('>>');

    if (streamIndex >= 0 &&
        closeIndex >= 0 &&
        closeIndex < streamIndex) {
      return closeIndex;
    }

    return text.length > 300 ? 300 : text.length;
  }

  Uint8List? _decodeStream(String body) {
    final int streamIndex = body.indexOf('stream');
    if (streamIndex < 0) return null;

    int dataStart = streamIndex + 'stream'.length;

    if (dataStart < body.length &&
        body.codeUnitAt(dataStart) == 13) {
      dataStart++;
      if (dataStart < body.length &&
          body.codeUnitAt(dataStart) == 10) {
        dataStart++;
      }
    } else if (dataStart < body.length &&
        body.codeUnitAt(dataStart) == 10) {
      dataStart++;
    }

    final int endStream = body.indexOf(
      'endstream',
      dataStart,
    );

    if (endStream < 0) return null;

    final String encoded = body.substring(
      dataStart,
      endStream,
    );

    final Uint8List raw = Uint8List.fromList(
      latin1.encode(encoded),
    );

    final bool flate = RegExp(
      r'/Filter\s*(?:\[\s*)?/FlateDecode\b',
    ).hasMatch(body);

    if (!flate) return raw;

    try {
      return Uint8List.fromList(
        ZLibDecoder().convert(raw),
      );
    } catch (_) {
      // A few PDF producers can use a raw DEFLATE stream.
      try {
        return Uint8List.fromList(
          ZLibDecoder(raw: true).convert(raw),
        );
      } catch (_) {
        return null;
      }
    }
  }

  List<_PdfFilledRect> _extractFilledRectangles(
    Uint8List bytes,
  ) {
    final String content = latin1.decode(
      bytes,
      allowInvalid: true,
    );

    final List<_PdfFilledRect> rectangles = [];
    final List<double> stack = [];
    final List<_PdfGraphicsState> states = [];

    _PdfGraphicsState state = const _PdfGraphicsState();
    final List<_PdfPathRect> pendingPath = [];

    final RegExp tokenPattern = RegExp(
      r'/[A-Za-z0-9_.+-]+|[-+]?(?:\d*\.\d+|\d+\.?\d*)|[A-Za-z][A-Za-z0-9*]*',
    );

    for (final Match tokenMatch
        in tokenPattern.allMatches(content)) {
      final String token = tokenMatch.group(0)!;

      if (_isNumber(token)) {
        stack.add(double.parse(token));
        continue;
      }

      if (token.startsWith('/')) {
        stack.clear();
        continue;
      }

      switch (token) {
        case 'q':
          states.add(state);
          stack.clear();
          break;

        case 'Q':
          if (states.isNotEmpty) {
            state = states.removeLast();
          }
          stack.clear();
          pendingPath.clear();
          break;

        case 'rg':
        case 'sc':
        case 'scn':
          if (stack.length >= 3) {
            final int n = stack.length;
            state = state.copyWith(
              red: _clamp01(stack[n - 3]),
              green: _clamp01(stack[n - 2]),
              blue: _clamp01(stack[n - 1]),
            );
          }
          stack.clear();
          break;

        case 'g':
          if (stack.isNotEmpty) {
            final double gray = _clamp01(stack.last);
            state = state.copyWith(
              red: gray,
              green: gray,
              blue: gray,
            );
          }
          stack.clear();
          break;

        case 'k':
          if (stack.length >= 4) {
            final int n = stack.length;
            final double c = _clamp01(stack[n - 4]);
            final double m = _clamp01(stack[n - 3]);
            final double y = _clamp01(stack[n - 2]);
            final double k = _clamp01(stack[n - 1]);

            state = state.copyWith(
              red: 1 - _min01(1, c + k),
              green: 1 - _min01(1, m + k),
              blue: 1 - _min01(1, y + k),
            );
          }
          stack.clear();
          break;

        case 'cm':
          if (stack.length >= 6) {
            final int n = stack.length;
            final _PdfMatrix transform = _PdfMatrix(
              stack[n - 6],
              stack[n - 5],
              stack[n - 4],
              stack[n - 3],
              stack[n - 2],
              stack[n - 1],
            );

            state = state.copyWith(
              matrix: state.matrix.multiply(transform),
            );
          }
          stack.clear();
          break;

        case 're':
          if (stack.length >= 4) {
            final int n = stack.length;
            final double x = stack[n - 4];
            final double y = stack[n - 3];
            final double w = stack[n - 2];
            final double h = stack[n - 1];

            pendingPath.add(
              _PdfPathRect(
                x: x,
                y: y,
                width: w,
                height: h,
                matrix: state.matrix,
              ),
            );
          }
          stack.clear();
          break;

        case 'f':
        case 'f*':
        case 'B':
        case 'B*':
        case 'b':
        case 'b*':
          for (final _PdfPathRect path in pendingPath) {
            final _PdfBounds bounds = path.transformedBounds();

            if (bounds.width > 0 && bounds.height > 0) {
              rectangles.add(
                _PdfFilledRect(
                  left: bounds.left,
                  right: bounds.right,
                  topPdf: bounds.top,
                  bottomPdf: bounds.bottom,
                  red: (state.red * 255).round(),
                  green: (state.green * 255).round(),
                  blue: (state.blue * 255).round(),
                ),
              );
            }
          }

          pendingPath.clear();
          stack.clear();
          break;

        case 'S':
        case 's':
          pendingPath.clear();
          stack.clear();
          break;

        default:
          // Text operators (TJ, Tj, Td, BT, ET, Tf, etc.) and all
          // other operators are irrelevant to color rectangles.
          stack.clear();
          break;
      }
    }

    return rectangles;
  }

  bool _isNumber(String token) {
    return RegExp(
      r'^[-+]?(?:\d*\.\d+|\d+\.?\d*)$',
    ).hasMatch(token);
  }

  double _clamp01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  double _min01(double a, double b) {
    return b < a ? b : a;
  }
}

class _PdfRawObject {
  const _PdfRawObject({
    required this.number,
    required this.generation,
    required this.body,
  });

  final int number;
  final int generation;
  final String body;
}

class _PdfPageInfo {
  const _PdfPageInfo({
    required this.filledRects,
  });

  final List<_PdfFilledRect> filledRects;
}

class _PdfFilledRect {
  const _PdfFilledRect({
    required this.left,
    required this.right,
    required this.topPdf,
    required this.bottomPdf,
    required this.red,
    required this.green,
    required this.blue,
  });

  final double left;
  final double right;
  final double topPdf;
  final double bottomPdf;
  final int red;
  final int green;
  final int blue;

  double get width => right - left;
  double get height => (topPdf - bottomPdf).abs();
}

class _PdfPathRect {
  const _PdfPathRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.matrix,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final _PdfMatrix matrix;

  _PdfBounds transformedBounds() {
    final List<_PdfPoint> points = [
      matrix.transform(x, y),
      matrix.transform(x + width, y),
      matrix.transform(x, y + height),
      matrix.transform(x + width, y + height),
    ];

    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final _PdfPoint point in points.skip(1)) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }

    return _PdfBounds(
      left: minX,
      right: maxX,
      top: maxY,
      bottom: minY,
    );
  }
}

class _PdfBounds {
  const _PdfBounds({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  final double left;
  final double right;
  final double top;
  final double bottom;

  double get width => right - left;
  double get height => top - bottom;
}

class _PdfPoint {
  const _PdfPoint(this.x, this.y);

  final double x;
  final double y;
}

class _PdfMatrix {
  const _PdfMatrix(
    this.a,
    this.b,
    this.c,
    this.d,
    this.e,
    this.f,
  );

  const _PdfMatrix.identity()
      : a = 1,
        b = 0,
        c = 0,
        d = 1,
        e = 0,
        f = 0;

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  _PdfPoint transform(double x, double y) {
    return _PdfPoint(
      a * x + c * y + e,
      b * x + d * y + f,
    );
  }

  _PdfMatrix multiply(_PdfMatrix other) {
    return _PdfMatrix(
      a * other.a + c * other.b,
      b * other.a + d * other.b,
      a * other.c + c * other.d,
      b * other.c + d * other.d,
      a * other.e + c * other.f + e,
      b * other.e + d * other.f + f,
    );
  }
}

class _PdfGraphicsState {
  const _PdfGraphicsState({
    this.red = 0,
    this.green = 0,
    this.blue = 0,
    this.matrix = const _PdfMatrix.identity(),
  });

  final double red;
  final double green;
  final double blue;
  final _PdfMatrix matrix;

  _PdfGraphicsState copyWith({
    double? red,
    double? green,
    double? blue,
    _PdfMatrix? matrix,
  }) {
    return _PdfGraphicsState(
      red: red ?? this.red,
      green: green ?? this.green,
      blue: blue ?? this.blue,
      matrix: matrix ?? this.matrix,
    );
  }
}

// ================================================================
// INTERNAL DATA CLASSES
// ================================================================

class _PdfColorPrototype {
  const _PdfColorPrototype({
    required this.type,
    required this.rgb,
  });

  final String type;
  final List<int> rgb;
}

class _CalendarColumnBounds {
  const _CalendarColumnBounds({
    required this.left,
    required this.right,
  });

  final double left;
  final double right;
}


