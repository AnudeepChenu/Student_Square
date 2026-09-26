
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../session_manager.dart';
import '../timetable_data_store.dart';

class PortalWebViewScreen extends StatefulWidget {
  final String initialUrl;

  const PortalWebViewScreen({
    super.key,
    this.initialUrl = 'https://sraap.in/student_login.php',
  });

  @override
  State<PortalWebViewScreen> createState() => _PortalWebViewScreenState();
}

class _PortalWebViewScreenState extends State<PortalWebViewScreen> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _isSaving = false;
  String _currentUrl = '';

  bool get _isTimetable {
    return widget.initialUrl.contains('timetable.sruniv.com');
  }

  bool _isSraapDashboard(String url) {
    return url.contains('sraap.in') &&
        url.contains('/student/dash_board.php');
  }

  bool get _canSyncAttendance {
    // Attendance can be present on multiple authenticated SRAAP
    // pages, including Dashboard and Attendance Report.
    return !_isTimetable &&
        _currentUrl.toLowerCase().contains('sraap.in');
  }

  @override
  void initState() {
    super.initState();

    _currentUrl = widget.initialUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;

            setState(() {
              _currentUrl = url;
              _isLoading = true;
            });
          },
          onPageFinished: (url) async {
            if (!mounted) return;

            setState(() {
              _currentUrl = url;
              _isLoading = false;
            });

            // IMPORTANT:
            // Login/session detection only.
            // Attendance is NOT fetched here.
            // It is fetched only when the user taps
            // "Sync Attendance" after reaching the dashboard.
            if (!_isTimetable && _isSraapDashboard(url)) {
              await SessionManager.setSraapLoggedIn(true);
            }
          },
          onWebResourceError: (error) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.initialUrl),
      );
  }

  // ============================================================
  // ATTENDANCE EXTRACTION
  // ============================================================

  // This method is NEVER called automatically.
  // It runs only from _syncAttendance().
  Future<bool> _extractAndSaveAttendance() async {
    try {
      // The SRAAP pages can populate the attendance table asynchronously.
      // Retry the exact extraction for a few seconds instead of assuming
      // the table is ready immediately.
      for (int attempt = 0; attempt < 6; attempt++) {
        if (attempt > 0) {
          await Future.delayed(
            const Duration(milliseconds: 700),
          );
        }

        final dynamic result =
            await _controller.runJavaScriptReturningResult(
          '''
          (function() {
            const tables = document.querySelectorAll('table');

            if (!tables || tables.length === 0) {
              return JSON.stringify([]);
            }

            const clean = (value) =>
              (value || '').replace(/\\\\s+/g, ' ').trim();

            const normal = (value) =>
              clean(value).toLowerCase();

            let allSubjects = [];

            tables.forEach(table => {
              const rows = table.querySelectorAll('tr');

              if (!rows || rows.length < 2) {
                return;
              }

              // --------------------------------------------------
              // Find column indexes from the table header.
              // This supports both the dashboard table and the
              // Attendance Report page shown by the user.
              // --------------------------------------------------
              let headerRow = null;
              let headers = [];

              for (let r = 0; r < Math.min(rows.length, 3); r++) {
                const cells = rows[r].children;

                if (!cells || cells.length < 2) {
                  continue;
                }

                const candidate = [];

                for (let c = 0; c < cells.length; c++) {
                  candidate.push(
                    normal(cells[c].innerText)
                  );
                }

                const hasCourse =
                  candidate.some(h =>
                    h.includes('course') ||
                    h.includes('subject')
                  );

                const hasPresent =
                  candidate.some(h =>
                    h.includes('present') ||
                    h === 'pr' ||
                    h.includes('attended')
                  );

                if (hasCourse || hasPresent) {
                  headerRow = r;
                  headers = candidate;
                  break;
                }
              }

              let courseIndex = -1;
              let ltpIndex = -1;
              let heldIndex = -1;
              let presentIndex = -1;

              if (headerRow !== null) {
                for (let c = 0; c < headers.length; c++) {
                  const h = headers[c];

                  if (
                    courseIndex === -1 &&
                    (h.includes('course') ||
                     h.includes('subject'))
                  ) {
                    courseIndex = c;
                  }

                  if (
                    ltpIndex === -1 &&
                    (h.includes('ltp') ||
                     h.includes('ltp cls'))
                  ) {
                    ltpIndex = c;
                  }

                  if (
                    heldIndex === -1 &&
                    (h.includes('held') ||
                     h.includes('conducted') ||
                     h.includes('total classes') ||
                     h === 'cls')
                  ) {
                    heldIndex = c;
                  }

                  if (
                    presentIndex === -1 &&
                    (h.includes('present') ||
                     h === 'pr' ||
                     h.includes('attended'))
                  ) {
                    presentIndex = c;
                  }
                }
              }

              // --------------------------------------------------
              // Process every row.
              // --------------------------------------------------
              for (
                let r = headerRow === null ? 0 : headerRow + 1;
                r < rows.length;
                r++
              ) {
                const cells = rows[r].children;

                if (!cells || cells.length < 3) {
                  continue;
                }

                // First choice: the same attendance_subwise link
                // used by the original working extension.
                let courseLink = null;

                for (let c = 0; c < cells.length; c++) {
                  const links =
                    cells[c].querySelectorAll('a');

                  for (const link of links) {
                    if (
                      link.href &&
                      link.href.includes('attendance_subwise')
                    ) {
                      courseLink = link;
                      break;
                    }
                  }

                  if (courseLink) break;
                }

                // The Attendance Report page also contains the
                // course name as a link, so if the URL pattern
                // differs, identify the course cell by its position
                // / header instead.
                let courseCellIndex = courseIndex;

                if (courseCellIndex < 0) {
                  courseCellIndex = courseLink
                    ? Array.from(cells).indexOf(
                        courseLink.parentElement
                      )
                    : 1;
                }

                if (
                  courseCellIndex < 0 ||
                  courseCellIndex >= cells.length
                ) {
                  courseCellIndex = 1;
                }

                const courseCell =
                    cells[courseCellIndex];

                if (!courseCell) {
                  continue;
                }

                let name = '';

                if (courseLink) {
                  name = clean(courseLink.innerText);
                }

                if (!name) {
                  const cellLink =
                      courseCell.querySelector('a');

                  if (cellLink) {
                    name = clean(cellLink.innerText);
                  }
                }

                if (!name) {
                  name = clean(courseCell.innerText);
                }

                // Ignore headings / non-course rows.
                if (
                  !name ||
                  normal(name) === 'course name' ||
                  normal(name) === 'subject'
                ) {
                  continue;
                }

                // --------------------------------------------------
                // Determine LTP / Held / Present.
                // First use detected header positions.
                // Then fall back to the original [2],[3],[4]
                // positions.
                // --------------------------------------------------
                const getNumber = (index) => {
                  if (
                    index < 0 ||
                    index >= cells.length
                  ) {
                    return null;
                  }

                  const value =
                      clean(cells[index].innerText);

                  const match =
                      value.match(/-?\\\\d+(?:\\\\.\\\\d+)?/);

                  if (!match) {
                    return null;
                  }

                  return parseInt(match[0], 10);
                };

                let ltp =
                    ltpIndex >= 0
                        ? getNumber(ltpIndex)
                        : null;

                let held =
                    heldIndex >= 0
                        ? getNumber(heldIndex)
                        : null;

                let present =
                    presentIndex >= 0
                        ? getNumber(presentIndex)
                        : null;

                // Original dashboard layout:
                // cells[1] = course
                // cells[2] = LTP
                // cells[3] = Held
                // cells[4] = Present
                if (cells.length >= 5) {
                  if (ltp === null) {
                    ltp = getNumber(2);
                  }

                  if (held === null) {
                    held = getNumber(3);
                  }

                  if (present === null) {
                    present = getNumber(4);
                  }
                }

                // --------------------------------------------------
                // Extra fallback for Attendance Report layouts:
                // after the course-name cell, use numeric cells.
                // The first numeric value is LTP; the next values
                // are Held and Present.
                // --------------------------------------------------
                if (
                  held === null ||
                  present === null
                ) {
                  const numbers = [];

                  for (
                    let c = courseCellIndex + 1;
                    c < cells.length;
                    c++
                  ) {
                    const value =
                        clean(cells[c].innerText);

                    const match =
                        value.match(/^\\s*(\\d+)\\s*\$/);

                    if (match) {
                      numbers.push(
                        parseInt(match[1], 10)
                      );
                    }
                  }

                  if (ltp === null && numbers.length >= 1) {
                    ltp = numbers[0];
                  }

                  if (held === null && numbers.length >= 2) {
                    held = numbers[1];
                  }

                  if (
                    present === null &&
                    numbers.length >= 3
                  ) {
                    present = numbers[2];
                  }
                }

                ltp = ltp || 0;
                held = held || 0;
                present = present || 0;

                if (
                  held > 0 &&
                  present >= 0 &&
                  present <= held
                ) {
                  allSubjects.push({
                    name: name,
                    ltp: ltp,
                    held: held,
                    pr: present
                  });
                }
              }
            });

            // Remove duplicate rows if the same table was found
            // through multiple structures.
            const unique = [];
            const seen = new Set();

            allSubjects.forEach(item => {
              const key =
                  item.name + '|' +
                  item.held + '|' +
                  item.pr;

              if (!seen.has(key)) {
                seen.add(key);
                unique.push(item);
              }
            });

            return JSON.stringify(unique);
          })();
          ''',
        );

        String jsonString =
            result is String
                ? result
                : result.toString();

        if (jsonString.startsWith('"') &&
            jsonString.endsWith('"')) {
          try {
            jsonString = jsonDecode(jsonString);
          } catch (_) {}
        }

        final dynamic decoded =
            jsonDecode(jsonString);

        if (decoded is! List) {
          continue;
        }

        final List<Map<String, dynamic>> attendance = [];

        for (final dynamic item in decoded) {
          if (item is! Map) {
            continue;
          }

          final String name =
              item['name']
                      ?.toString()
                      .trim() ??
                  '';

          final int ltp =
              int.tryParse(
                    item['ltp']
                            ?.toString() ??
                        '0',
                  ) ??
                  0;

          final int held =
              int.tryParse(
                    item['held']
                            ?.toString() ??
                        '0',
                  ) ??
                  0;

          final int pr =
              int.tryParse(
                    item['pr']
                            ?.toString() ??
                        '0',
                  ) ??
                  0;

          if (name.isEmpty ||
              held <= 0 ||
              pr < 0 ||
              pr > held) {
            continue;
          }

          attendance.add({
            'name': name,
            'ltp': ltp,
            'held': held,
            'pr': pr,
            'present': pr,
          });
        }

        debugPrint(
          'SRAAP attendance attempt ${attempt + 1}: '
          '${attendance.length} subjects found',
        );

        if (attendance.isNotEmpty) {
          await SessionManager.saveAttendance(
            attendance,
          );

          await SessionManager.setSraapLoggedIn(
            true,
          );

          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint(
        'Attendance extraction error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // TIMETABLE EXTRACTION
  // ============================================================

  Future<bool> _extractAndSaveTimetable() async {
    try {
      final result =
          await _controller.runJavaScriptReturningResult(
        '''
        (() => {
          const tables = document.querySelectorAll('table');

          if (!tables || tables.length === 0) {
            return JSON.stringify([]);
          }

          let table = null;

          for (const candidate of tables) {
            const rows = candidate.querySelectorAll('tr');

            if (rows.length >= 2) {
              const firstRow = rows[0];

              if (firstRow &&
                  firstRow.children.length >= 2) {
                table = candidate;
                break;
              }
            }
          }

          if (!table) {
            return JSON.stringify([]);
          }

          const rows = table.querySelectorAll('tr');

          if (rows.length < 2) {
            return JSON.stringify([]);
          }

          const headerCells = rows[0].children;

          let days = [];

          for (
            let i = 1;
            i < headerCells.length;
            i++
          ) {
            days.push(
              headerCells[i].innerText.trim()
            );
          }

          let timetable = [];

          for (
            let r = 1;
            r < rows.length;
            r++
          ) {
            const cells = rows[r].children;

            if (!cells || cells.length < 2) {
              continue;
            }

            const time =
                cells[0].innerText.trim();

            if (!time) {
              continue;
            }

            for (
              let c = 1;
              c < cells.length;
              c++
            ) {
              const cell = cells[c];

              const subject =
                  cell.innerText.trim();

              if (!subject) {
                continue;
              }

              const day =
                  days.length >= c
                      ? days[c - 1]
                      : '';

              if (!day) {
                continue;
              }

              let room = '';

              const cellText =
                  cell.innerText.trim();

              const labeledRoom = cellText.match(
                /\\b(?:room|classroom|venue|block)\\s*[:\\-]?\\s*([A-Za-z]{1,5}[-/ ]?\\d{2,4}[A-Za-z]?)\\b/i
              );

              if (labeledRoom) {
                room = labeledRoom[1].trim();
              }

              if (!room) {
                const parenthesizedRoom = cellText.match(
                  /\\(([A-Za-z]{1,5}[-/ ]?\\d{2,4}[A-Za-z]?)\\)/i
                );

                if (parenthesizedRoom) {
                  room = parenthesizedRoom[1].trim();
                }
              }

              if (!room) {
                const trailingRoom = cellText.match(
                  /(?:^|[\\s:;,\\-–—])([A-Za-z]{1,5}[-/ ]?\\d{2,4}[A-Za-z]?)/i
                );

                if (trailingRoom) {
                  room = trailingRoom[1].trim();
                }
              }

              if (!room) {
                const locationNode =
                    cell.querySelector(
                      '[class*="room"], [class*="location"], [class*="venue"], [title*="room" i], [data-room]'
                    );

                if (locationNode) {
                  room =
                      (
                        locationNode.getAttribute('data-room') ||
                        locationNode.innerText ||
                        ''
                      ).trim();
                }
              }

              timetable.push({
                day: day,
                time: time,
                subject: subject,
                room: room
              });
            }
          }

          return JSON.stringify(timetable);
        })()
        ''',
      );

      String jsonString =
          result is String ? result : result.toString();

      if (jsonString.startsWith('"') &&
          jsonString.endsWith('"')) {
        try {
          jsonString = jsonDecode(jsonString);
        } catch (_) {}
      }

      final decoded = jsonDecode(jsonString);

      if (decoded is! List) {
        return false;
      }

      final List<Map<String, dynamic>> timetable =
          decoded
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .where(
                (item) =>
                    (item['day'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty &&
                    (item['time'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty &&
                    (item['subject'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty,
              )
              .toList();

      if (timetable.isEmpty) {
        return false;
      }

      TimetableDataStore.instance.setClasses(timetable);
      await SessionManager.saveTimetable(timetable);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // MANUAL ATTENDANCE SYNC
  // ============================================================

  Future<void> _syncAttendance() async {
    if (_isSaving) return;

    if (!_canSyncAttendance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please open the SRAAP attendance page first.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // SRAAP can populate the attendance table shortly after the
    // dashboard itself finishes loading. The original working
    // AttendanceScreen waited before running the scraper.
    await Future.delayed(
      const Duration(milliseconds: 900),
    );

    if (!mounted) return;

    final success =
        await _extractAndSaveAttendance();

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Attendance synced'
              : 'Attendance data not found',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    if (success) {
      Navigator.pop(context, true);
    }
  }

  // ============================================================
  // MANUAL TIMETABLE SYNC
  // ============================================================

  Future<void> _syncTimetable() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final success =
        await _extractAndSaveTimetable();

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Timetable synced'
              : 'Timetable could not be updated',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    if (success) {
      Navigator.pop(context, true);
    }
  }

  // ============================================================
  // SYNC BUTTON
  // ============================================================

  Widget _buildSyncButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          16,
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildButton(
                label: 'Sync Attendance',
                onPressed:
                    _isSaving ? null : _syncAttendance,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildButton(
                label: 'Sync Timetable',
                onPressed:
                    _isSaving ? null : _syncTimetable,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16,
        ),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.sync_rounded,
                  ),
            label: Text(label),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isTimetable
              ? 'Timetable'
              : 'SRAAP',
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding:
                  EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: WebViewWidget(
              controller: _controller,
            ),
          ),

          // Both sync buttons stay visible everywhere.
          // Attendance extraction still uses the original scraper.
          // Timetable extraction still uses the existing timetable scraper.
          _buildSyncButton(),
        ],
      ),
    );
  }
}
