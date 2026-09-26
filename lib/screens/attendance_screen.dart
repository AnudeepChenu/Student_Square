import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../session_manager.dart';

class AttendanceScreen extends StatefulWidget {
  final ValueChanged<bool>? onSraapVisibilityChanged;

  const AttendanceScreen({
    super.key,
    this.onSraapVisibilityChanged,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  // ==============================================================
  // COLORS
  // ==============================================================

  static const Color _accent = Color(0xFF6376F5);
  static const Color _success = Color(0xFF55C98A);
  static const Color _warning = Color(0xFFE0B84F);
  static const Color _danger = Color(0xFFE86B6B);

  static const Color _darkBackground = Color(0xFF090A0B);
  static const Color _darkSurface = Color(0xFF111315);
  static const Color _darkSurface2 = Color(0xFF181A1D);

  static const Color _lightBackground = Color(0xFFF6F6F3);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurface2 = Color(0xFFEEEEEA);

  // ==============================================================
  // ATTENDANCE DATA
  // ==============================================================

  int targetAttendance = 75;

  List<Map<String, dynamic>> subjects = [];

  bool isLoading = true;

  final List<int> targetOptions = [
    65,
    75,
    80,
    85,
    90,
    95,
  ];

  late AnimationController _animationController;

  // Only one subject can be expanded.
  int? _expandedSubjectIndex;

  // Changes whenever progress animations should restart.
  int _progressAnimationKey = 0;

  // ==============================================================
  // SRAAP / PORTAL SYNC
  // ==============================================================

  static const String _sraapHomeUrl =
      'https://sraap.in/student/dash_board.php';

  static const String _sraapLoginUrl =
      'https://sraap.in/student_login.php';

  bool _sraapSyncing = false;
  bool _sraapSessionActive = false;
  bool _showSyncSuccess = false;

  // One persistent WebView. It is visible only for login /
  // re-authentication. Normal syncs happen completely hidden.
  final WebViewController _sraapController = WebViewController();
  bool _showSraapWebView = false;
  String _currentSraapUrl = '';
  Timer? _syncTimeoutTimer;
  Timer? _syncSuccessTimer;

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initializeSraapWebView();
    _loadData();
  }

  // ==============================================================
  // SYNC
  // ==============================================================

  Future<void> _onSyncPressed() async {
    if (_sraapSyncing) return;

    final bool loggedIn =
        await SessionManager.isSraapLoggedIn();

    if (!mounted) return;

    setState(() {
      _sraapSyncing = true;
      _showSyncSuccess = false;
    });

    _startSyncTimeout();

    if (!loggedIn) {
      // First authentication: WebView is visible.
      setState(() {
        _showSraapWebView = true;
        _sraapSessionActive = false;
      });

      _setSraapVisibility(true);

      await _sraapController.loadRequest(
        Uri.parse(_sraapLoginUrl),
      );
      return;
    }

    // Existing session: NEVER show the WebView.
    // Reuse its cookies/session and refresh silently.
    setState(() {
      _showSraapWebView = false;
    });

    _setSraapVisibility(false);

    await _sraapController.loadRequest(
      Uri.parse(_sraapHomeUrl),
    );
  }

  void _startSyncTimeout() {
    _syncTimeoutTimer?.cancel();

    _syncTimeoutTimer = Timer(
      const Duration(seconds: 35),
      () {
        if (!mounted) return;

        if (_sraapSyncing) {
          setState(() {
            _sraapSyncing = false;
          });

          if (_sraapSessionActive) {
            _setSraapVisibility(false);
          }
        }
      },
    );
  }

  void _setSraapVisibility(bool visible) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSraapVisibilityChanged?.call(visible);
    });
  }

  bool _isSraapLoginUrl(String url) {
    return url.toLowerCase().contains(
      'sraap.in/student_login.php',
    );
  }

  bool _isSraapDomain(String url) {
    return url.toLowerCase().startsWith(
      'https://sraap.in',
    );
  }

  void _initializeSraapWebView() {
    _sraapController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) async {
            _currentSraapUrl = url;
            debugPrint('SRAAP page started: $url');

            if (_isSraapLoginUrl(url)) {
              await SessionManager.clearSraapSession();

              if (!mounted) return;

              setState(() {
                _sraapSessionActive = false;
                _showSraapWebView = true;
              });

              // Only an actual redirect to login exposes WebView again.
              _setSraapVisibility(true);
            }
          },
          onPageFinished: (url) async {
            _currentSraapUrl = url;
            debugPrint('SRAAP page finished: $url');

            if (!_sraapSyncing) return;

            if (_isSraapLoginUrl(url)) {
              // Wait for the user to complete login.
              return;
            }

            if (!_isSraapDomain(url)) return;

            await Future.delayed(
              const Duration(milliseconds: 900),
            );

            if (!mounted || !_sraapSyncing) return;

            final bool success =
                await _tryExtractAttendance();

            if (!mounted) return;

            if (success) {
              await SessionManager.setSraapLoggedIn(true);
              _syncTimeoutTimer?.cancel();

              setState(() {
                _sraapSessionActive = true;
                _sraapSyncing = false;
                _showSraapWebView = false;
                _showSyncSuccess = true;
              });

              _setSraapVisibility(false);

              _syncSuccessTimer?.cancel();
              _syncSuccessTimer = Timer(
                const Duration(milliseconds: 1800),
                () {
                  if (!mounted) return;
                  setState(() {
                    _showSyncSuccess = false;
                  });
                },
              );
            } else {
              _syncTimeoutTimer?.cancel();
              setState(() {
                _sraapSyncing = false;
              });

              if (_showSraapWebView) {
                _setSraapVisibility(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Attendance data not found on this page.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          },
          onWebResourceError: (error) {
            debugPrint(
              'SRAAP WebView error: ${error.description}',
            );
          },
        ),
      );
  }

  // ==============================================================
  // ATTENDANCE EXTRACTION
  // ==============================================================

  Future<bool> _tryExtractAttendance() async {
    try {
      for (int attempt = 0; attempt < 6; attempt++) {
        if (attempt > 0) {
          await Future.delayed(
            const Duration(milliseconds: 700),
          );
        }

        final dynamic result =
            await _sraapController
                .runJavaScriptReturningResult(
          r'''
          (function() {
            const tables = document.querySelectorAll('table');

            if (!tables || tables.length === 0) {
              return JSON.stringify([]);
            }

            const clean = (value) =>
              (value || '').replace(/\s+/g, ' ').trim();

            const normal = (value) =>
              clean(value).toLowerCase();

            const numberFrom = (value) => {
              const match = clean(value).match(/\d+/);
              return match ? parseInt(match[0], 10) : null;
            };

            let allSubjects = [];

            tables.forEach(table => {
              const rows = table.querySelectorAll('tr');
              if (!rows || rows.length < 2) return;

              let headerRow = -1;
              let headers = [];

              for (let r = 0; r < Math.min(rows.length, 4); r++) {
                const cells = rows[r].children;
                if (!cells || cells.length < 2) continue;

                const candidate = [];
                for (let c = 0; c < cells.length; c++) {
                  candidate.push(normal(cells[c].innerText));
                }

                const hasCourse = candidate.some(h =>
                  h.includes('course') || h.includes('subject')
                );
                const hasAttendance = candidate.some(h =>
                  h.includes('present') ||
                  h === 'pr' ||
                  h.includes('attended') ||
                  h.includes('held') ||
                  h.includes('conducted')
                );

                if (hasCourse || hasAttendance) {
                  headerRow = r;
                  headers = candidate;
                  break;
                }
              }

              let courseIndex = -1;
              let ltpIndex = -1;
              let heldIndex = -1;
              let presentIndex = -1;

              for (let c = 0; c < headers.length; c++) {
                const h = headers[c];

                if (courseIndex === -1 &&
                    (h.includes('course') || h.includes('subject'))) {
                  courseIndex = c;
                }
                if (ltpIndex === -1 &&
                    (h.includes('ltp') || h.includes('ltp cls'))) {
                  ltpIndex = c;
                }
                if (heldIndex === -1 &&
                    (h.includes('held') ||
                     h.includes('conducted') ||
                     h.includes('total classes') ||
                     h === 'cls')) {
                  heldIndex = c;
                }
                if (presentIndex === -1 &&
                    (h.includes('present') ||
                     h === 'pr' ||
                     h.includes('attended'))) {
                  presentIndex = c;
                }
              }

              for (
                let r = headerRow >= 0 ? headerRow + 1 : 0;
                r < rows.length;
                r++
              ) {
                const cells = rows[r].children;
                if (!cells || cells.length < 3) continue;

                let courseLink = null;

                for (let c = 0; c < cells.length; c++) {
                  const links = cells[c].querySelectorAll('a');
                  for (const link of links) {
                    if (link.href &&
                        link.href.includes('attendance_subwise')) {
                      courseLink = link;
                      break;
                    }
                  }
                  if (courseLink) break;
                }

                let courseCellIndex = courseIndex;

                if (courseCellIndex < 0 && courseLink) {
                  courseCellIndex = Array.from(cells).indexOf(
                    courseLink.parentElement
                  );
                }

                if (courseCellIndex < 0) courseCellIndex = 1;
                if (courseCellIndex >= cells.length) continue;

                const courseCell = cells[courseCellIndex];
                let name = courseLink
                    ? clean(courseLink.innerText)
                    : '';

                if (!name) {
                  const cellLink = courseCell.querySelector('a');
                  if (cellLink) name = clean(cellLink.innerText);
                }

                if (!name) name = clean(courseCell.innerText);

                if (!name ||
                    normal(name) === 'course name' ||
                    normal(name) === 'subject') {
                  continue;
                }

                const getNumber = (index) => {
                  if (index < 0 || index >= cells.length) return null;
                  return numberFrom(cells[index].innerText);
                };

                let ltp = ltpIndex >= 0 ? getNumber(ltpIndex) : null;
                let held = heldIndex >= 0 ? getNumber(heldIndex) : null;
                let present = presentIndex >= 0 ? getNumber(presentIndex) : null;

                if (cells.length >= 5) {
                  if (ltp === null) ltp = getNumber(2);
                  if (held === null) held = getNumber(3);
                  if (present === null) present = getNumber(4);
                }

                if (held === null || present === null) {
                  const numbers = [];

                  for (let c = courseCellIndex + 1; c < cells.length; c++) {
                    const n = numberFrom(cells[c].innerText);
                    if (n !== null) numbers.push(n);
                  }

                  if (ltp === null && numbers.length >= 1) ltp = numbers[0];
                  if (held === null && numbers.length >= 2) held = numbers[1];
                  if (present === null && numbers.length >= 3) present = numbers[2];
                }

                ltp = ltp || 0;
                held = held || 0;
                present = present || 0;

                if (held > 0 && present >= 0 && present <= held) {
                  allSubjects.push({
                    name: name,
                    ltp: ltp,
                    held: held,
                    pr: present
                  });
                }
              }
            });

            const unique = [];
            const seen = new Set();

            allSubjects.forEach(item => {
              const key = item.name + '|' + item.held + '|' + item.pr;
              if (!seen.has(key)) {
                seen.add(key);
                unique.push(item);
              }
            });

            return JSON.stringify(unique);
          })();
          ''',
        );

        String jsonString = result.toString();

        if (jsonString.startsWith('"') &&
            jsonString.endsWith('"')) {
          try {
            jsonString = jsonDecode(jsonString);
          } catch (_) {}
        }

        final dynamic decoded = jsonDecode(jsonString);
        if (decoded is! List) continue;

        final List<Map<String, dynamic>> extracted = [];

        for (final dynamic item in decoded) {
          if (item is! Map) continue;

          final String name =
              item['name']?.toString().trim() ?? '';
          final int held =
              int.tryParse(item['held']?.toString() ?? '0') ?? 0;
          final int present =
              int.tryParse(item['pr']?.toString() ?? '0') ?? 0;

          if (name.isEmpty ||
              held <= 0 ||
              present < 0 ||
              present > held) {
            continue;
          }

          extracted.add({
            'name': name,
            'held': held,
            'present': present,
          });
        }

        debugPrint(
          'SRAAP attendance attempt ${attempt + 1}: '
          '${extracted.length} subjects found',
        );

        if (extracted.isNotEmpty) {
          await SessionManager.saveAttendance(extracted);
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Attendance extraction error: $e');
      return false;
    }
  }

  // LOAD DATA
  // ==============================================================

  Future<void> _loadData() async {
    final List<Map<String, dynamic>> cachedAttendance =
        await SessionManager.getAttendance();

    final int savedTarget =
        await SessionManager.getTarget();

    final bool sessionActive =
        await SessionManager.isSraapLoggedIn();

    if (!mounted) return;

    setState(() {
      subjects = cachedAttendance;

      targetAttendance =
          savedTarget <= 0 ? 75 : savedTarget;

      _sraapSessionActive = sessionActive;

      isLoading = false;

      _progressAnimationKey++;
    });

    restartAnimation();
  }

  // TARGET
  // ==============================================================

  Future<void> _changeTarget(int direction) async {
    int currentIndex =
        targetOptions.indexOf(targetAttendance);

    if (currentIndex == -1) {
      currentIndex = 1;
    }

    final int newIndex =
        currentIndex + direction;

    if (newIndex >= 0 &&
        newIndex < targetOptions.length) {
      setState(() {
        targetAttendance =
            targetOptions[newIndex];

        _expandedSubjectIndex = null;

        // Force all progress bars to
        // animate again.
        _progressAnimationKey++;
      });

      await SessionManager.saveTarget(
        targetAttendance,
      );

      restartAnimation();
    }
  }

  // ==============================================================
  // EXPANSION
  // ==============================================================

  void _toggleSubjectExpansion(int index) {
    setState(() {
      if (_expandedSubjectIndex == index) {
        _expandedSubjectIndex = null;
      } else {
        _expandedSubjectIndex = index;
      }
    });
  }

  // ==============================================================
  // CALCULATIONS
  // ==============================================================

  int _calculateSkippable(
    int present,
    int held,
  ) {
    if (held <= 0) {
      return 0;
    }

    final double target =
        targetAttendance / 100.0;

    int skipCount = 0;

    while (
        (present /
                (held +
                    skipCount +
                    1)) >=
            target) {
      skipCount++;
    }

    return skipCount;
  }

  int _calculateNeeded(
    int present,
    int held,
  ) {
    if (held <= 0) {
      return 0;
    }

    final double target =
        targetAttendance / 100.0;

    if ((present / held) >= target) {
      return 0;
    }

    int needed = 0;

    while (
        ((present + needed) /
                (held + needed)) <
            target) {
      needed++;
    }

    return needed;
  }

  double _getOverallAttendance() {
    if (subjects.isEmpty) {
      return 0;
    }

    int totalPresent = 0;
    int totalHeld = 0;

    for (final subject in subjects) {
      totalPresent +=
          int.tryParse(
                subject['present']
                        ?.toString() ??
                    '0',
              ) ??
              0;

      totalHeld +=
          int.tryParse(
                subject['held']
                        ?.toString() ??
                    '0',
              ) ??
              0;
    }

    if (totalHeld == 0) {
      return 0;
    }

    return totalPresent /
            totalHeld *
        100;
  }

  Color _statusColor(double percentage) {
    if (percentage >= targetAttendance) {
      return _success;
    }

    if (percentage >= targetAttendance - 10) {
      return _warning;
    }

    return _danger;
  }

  // ==============================================================
  // PAGE ANIMATION
  // ==============================================================

  void restartAnimation() {
    if (!mounted) {
      return;
    }

    _animationController
      ..reset()
      ..forward();
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    final Color background =
        isDark ? _darkBackground : _lightBackground;

    final Color surface =
        isDark ? _darkSurface : _lightSurface;

    final Color surface2 =
        isDark ? _darkSurface2 : _lightSurface2;

    final Color text =
        isDark ? Colors.white : const Color(0xFF111111);

    final Color muted =
        isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          RefreshIndicator(
        color: _accent,
        onRefresh: () async {
          await _onSyncPressed();
        },
        child: isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 360),
                  Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 18,
                  20,
                  110,
                ),
                children: [
                  _buildAnimatedEntrance(
                    0,
                    _buildHeader(
                      isDark,
                      text,
                      muted,
                      surface2,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _buildAnimatedEntrance(
                    1,
                    _buildOverallCard(
                      isDark,
                      surface,
                      text,
                      muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildAnimatedEntrance(
                    2,
                    _buildSectionHeader(muted),
                  ),
                  const SizedBox(height: 12),
                  if (subjects.isEmpty)
                    _buildEmptyState(surface, muted)
                  else
                    ...subjects.asMap().entries.map(
                      (entry) => _buildSubjectCard(
                        entry.value,
                        entry.key,
                        isDark,
                        surface,
                        surface2,
                        text,
                        muted,
                      ),
                    ),
                ],
              ),
          ),

          // Persistent WebView. Hidden during normal syncs and shown only
          // for first login or when the SRAAP session has expired.
          Positioned.fill(
            child: Offstage(
              offstage: !_showSraapWebView,
              child: Material(
                color: background,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                _syncTimeoutTimer?.cancel();
                                setState(() {
                                  _showSraapWebView = false;
                                  _sraapSyncing = false;
                                });
                                _setSraapVisibility(false);
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: surface2,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: text,
                                  size: 19,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SRAAP',
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Sign in to sync attendance',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_sraapSyncing)
                              const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: WebViewWidget(
                          controller: _sraapController,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // HEADER
  // ==============================================================

  Widget _buildHeader(
    bool isDark,
    Color text,
    Color muted,
    Color surface2,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'ATTENDANCE',
                style: TextStyle(
                  color: muted,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Overview',
                style: TextStyle(
                  color: text,
                  fontSize: 29,
                  height: 1,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
            ],
          ),
        ),

        if (_sraapSessionActive)
          Container(
            width: 9,
            height: 9,
            decoration:
                const BoxDecoration(
              color: _success,
              shape: BoxShape.circle,
            ),
          )
        else
          GestureDetector(
            onTap: _onSyncPressed,
            child: const Text(
              'LOGIN',
              style: TextStyle(
                color: _accent,
                fontSize: 10,
                fontWeight:
                    FontWeight.w800,
                letterSpacing: .6,
              ),
            ),
          ),

        const SizedBox(width: 11),

        GestureDetector(
          onTap: _onSyncPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: surface2,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration:
                  const Duration(
                milliseconds: 220,
              ),
              child:
                  _sraapSyncing
                      ? const SizedBox(
                          key: ValueKey(
                            'loading',
                          ),
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accent,
                          ),
                        )
                      : _showSyncSuccess
                          ? const Icon(
                              key: ValueKey(
                                'success',
                              ),
                              Icons
                                  .check_rounded,
                              color:
                                  _success,
                              size: 19,
                            )
                          : Icon(
                              key: const ValueKey(
                                'sync',
                              ),
                              Icons
                                  .sync_rounded,
                              color: text,
                              size: 18,
                            ),
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // OVERALL CARD
  // ==============================================================

  Widget _buildOverallCard(
    bool isDark,
    Color surface,
    Color text,
    Color muted,
  ) {
    final double percentage =
        _getOverallAttendance();

    final double progress =
        (percentage / 100)
            .clamp(0.0, 1.0);

    int totalPresent = 0;
    int totalHeld = 0;

    for (final subject in subjects) {
      totalPresent +=
          int.tryParse(
                subject['present']
                        ?.toString() ??
                    '0',
              ) ??
              0;

      totalHeld +=
          int.tryParse(
                subject['held']
                        ?.toString() ??
                    '0',
              ) ??
              0;
    }

    final bool onTarget =
        percentage >= targetAttendance;

    final Color status =
        _statusColor(percentage);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        19,
        18,
        19,
        17,
      ),
      decoration:
          BoxDecoration(
        color: surface,
        borderRadius:
            BorderRadius.circular(25),
        border: Border.all(
          color: isDark
              ? Colors.white
                  .withOpacity(.055)
              : Colors.black
                  .withOpacity(.055),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'OVERALL',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '$totalPresent present · '
                      '$totalHeld held',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color: status
                      .withOpacity(.10),
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      onTarget
                          ? Icons
                              .check_rounded
                          : Icons
                              .arrow_downward_rounded,
                      size: 12,
                      color: status,
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      onTarget
                          ? 'ON TARGET'
                          : 'BELOW TARGET',
                      style: TextStyle(
                        color: status,
                        fontSize: 8,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: .45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --------------------------------------------------------
          // OVERALL NUMBER
          // --------------------------------------------------------

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              AnimatedBuilder(
                animation:
                    _animationController,
                builder:
                    (context, child) {
                  final double t =
                      Curves.easeOutCubic
                          .transform(
                    _animationController
                        .value,
                  );

                  return Text(
                    (percentage * t)
                        .toStringAsFixed(0),
                    style: TextStyle(
                      color: text,
                      fontSize: 68,
                      height: .82,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: -4,
                    ),
                  );
                },
              ),

              Padding(
                padding:
                    const EdgeInsets.only(
                  left: 4,
                  bottom: 6,
                ),
                child: Text(
                  '%',
                  style: TextStyle(
                    color: muted,
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),

              const Spacer(),

              Text(
                onTarget
                    ? '${(percentage - targetAttendance).abs().toStringAsFixed(0)}% above target'
                    : '${(targetAttendance - percentage).abs().toStringAsFixed(0)}% to target',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 19),

          // --------------------------------------------------------
          // ANIMATED OVERALL PROGRESS BAR
          // --------------------------------------------------------

          KeyedSubtree(
            key: ValueKey(
              'overall-progress-$_progressAnimationKey',
            ),
            child:
                TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.0,
                end: progress,
              ),
              duration:
                  const Duration(
                milliseconds: 1100,
              ),
              curve:
                  Curves.easeOutCubic,
              builder:
                  (context, value, _) {
                return ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    6,
                  ),
                  child:
                      LinearProgressIndicator(
                    minHeight: 6,
                    value: value,
                    backgroundColor:
                        isDark
                            ? Colors.white
                                .withOpacity(
                                .07,
                              )
                            : Colors.black
                                .withOpacity(
                                .06,
                              ),
                    valueColor:
                        AlwaysStoppedAnimation<
                            Color>(
                      status,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Text(
                'TARGET',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(width: 7),

              Text(
                '$targetAttendance%',
                style: TextStyle(
                  color: text,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const Spacer(),

              _smallIconButton(
                Icons.remove_rounded,
                () => _changeTarget(-1),
                isDark,
              ),

              const SizedBox(width: 5),

              _smallIconButton(
                Icons.add_rounded,
                () => _changeTarget(1),
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallIconButton(
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration:
            BoxDecoration(
          color: isDark
              ? Colors.white
                  .withOpacity(.065)
              : Colors.black
                  .withOpacity(.055),
          borderRadius:
              BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 15,
          color: isDark
              ? Colors.white
              : Colors.black87,
        ),
      ),
    );
  }

  // ==============================================================
  // SECTION HEADER
  // ==============================================================

  Widget _buildSectionHeader(
    Color muted,
  ) {
    return Row(
      children: [
        Text(
          'SUBJECTS',
          style: TextStyle(
            color: muted,
            fontSize: 10,
            fontWeight:
                FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        Text(
          '${subjects.length} TOTAL',
          style: TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight:
                FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // SUBJECT CARD
  // ==============================================================

  Widget _buildSubjectCard(
    Map<String, dynamic> subject,
    int index,
    bool isDark,
    Color surface,
    Color surface2,
    Color text,
    Color muted,
  ) {
    final int present =
        int.tryParse(
              subject['present']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    final int held =
        int.tryParse(
              subject['held']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    final double percentage =
        held == 0
            ? 0
            : present / held * 100;

    final int skippable =
        _calculateSkippable(
      present,
      held,
    );

    final int needed =
        _calculateNeeded(
      present,
      held,
    );

    final bool canSkip =
        skippable > 0;

    final bool expanded =
        _expandedSubjectIndex == index;

    final Color status =
        _statusColor(percentage);

    final double progress =
        (percentage / 100)
            .clamp(0.0, 1.0);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 11,
      ),
      decoration:
          BoxDecoration(
        color: surface,
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color: expanded
              ? _accent
                  .withOpacity(.32)
              : isDark
                  ? Colors.white
                      .withOpacity(.055)
                  : Colors.black
                      .withOpacity(.055),
        ),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(21),
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                14,
              ),
              child: Column(
                children: [
                  // =================================================
                  // SUBJECT NAME + PERCENTAGE
                  // SUBJECT NAME = MAX 60%
                  // =================================================

                  LayoutBuilder(
                    builder:
                        (context, constraints) {
                      final double nameWidth =
                          constraints.maxWidth *
                              0.60;

                      return Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .center,
                        children: [
                          SizedBox(
                            width: nameWidth,
                            child: Text(
                              subject['name']
                                      ?.toString() ??
                                  'Subject',
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: TextStyle(
                                color: text,
                                fontSize: 15,
                                height: 1.15,
                                fontWeight:
                                    FontWeight
                                        .w700,
                                letterSpacing:
                                    -.2,
                              ),
                            ),
                          ),

                          const Spacer(),

                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: text,
                              fontSize: 25,
                              height: .95,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              letterSpacing:
                                  -1.1,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // =================================================
                  // ANIMATED SUBJECT PROGRESS BAR
                  // =================================================

                  KeyedSubtree(
                    key: ValueKey(
                      'subject-progress-'
                      '$_progressAnimationKey-'
                      '$index-'
                      '${percentage.toStringAsFixed(2)}',
                    ),
                    child:
                        TweenAnimationBuilder<
                            double>(
                      tween: Tween<double>(
                        begin: 0.0,
                        end: progress,
                      ),
                      duration:
                          Duration(
                        milliseconds:
                            900 +
                                (index *
                                    80),
                      ),
                      curve:
                          Curves.easeOutCubic,
                      builder:
                          (context,
                              value,
                              _) {
                        return ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            5,
                          ),
                          child:
                              LinearProgressIndicator(
                            minHeight: 4,
                            value: value,
                            backgroundColor:
                                isDark
                                    ? Colors.white
                                        .withOpacity(
                                        .075,
                                      )
                                    : Colors.black
                                        .withOpacity(
                                        .06,
                                      ),
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                              status,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // =================================================
                  // PRESENT / HELD / ACTION
                  // =================================================

                  Row(
                    children: [
                      _statText(
                        'PRESENT',
                        '$present',
                        muted,
                        text,
                      ),

                      const SizedBox(
                        width: 20,
                      ),

                      _statText(
                        'HELD',
                        '$held',
                        muted,
                        text,
                      ),

                      const Spacer(),

                      GestureDetector(
                        onTap: () =>
                            _toggleSubjectExpansion(
                          index,
                        ),
                        child:
                            AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds:
                                220,
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration:
                              BoxDecoration(
                            color: status
                                .withOpacity(
                              expanded
                                  ? .16
                                  : .09,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              9,
                            ),
                            border:
                                Border.all(
                              color: status
                                  .withOpacity(
                                expanded
                                    ? .30
                                    : .0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              Text(
                                canSkip
                                    ? 'SKIP $skippable'
                                    : 'ATTEND $needed',
                                style:
                                    TextStyle(
                                  color:
                                      status,
                                  fontSize:
                                      9,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                  letterSpacing:
                                      .35,
                                ),
                              ),

                              const SizedBox(
                                width: 5,
                              ),

                              AnimatedRotation(
                                duration:
                                    const Duration(
                                  milliseconds:
                                      220,
                                ),
                                turns:
                                    expanded
                                        ? .5
                                        : 0,
                                child:
                                    Icon(
                                  Icons
                                      .keyboard_arrow_down_rounded,
                                  size: 15,
                                  color:
                                      status,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ======================================================
            // EXPANDED DETAILS
            // ======================================================

            AnimatedSize(
              duration:
                  const Duration(
                milliseconds: 280,
              ),
              curve:
                  Curves.easeOutCubic,
              alignment:
                  Alignment.topCenter,
              child: expanded
                  ? _buildExpandedDetails(
                      present,
                      held,
                      percentage,
                      skippable,
                      needed,
                      canSkip,
                      isDark,
                      surface2,
                      text,
                      muted,
                      status,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // STAT TEXT
  // ==============================================================

  Widget _statText(
    String label,
    String value,
    Color muted,
    Color text,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight:
                FontWeight.w800,
            letterSpacing: .55,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: text,
            fontSize: 11,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // EXPANDED DETAILS
  // ==============================================================

  Widget _buildExpandedDetails(
    int present,
    int held,
    double percentage,
    int skippable,
    int needed,
    bool canSkip,
    bool isDark,
    Color surface2,
    Color text,
    Color muted,
    Color status,
  ) {
    final List<_Projection>
        projections = canSkip
            ? _buildSkipProjections(
                present,
                held,
                skippable,
              )
            : _buildAttendProjections(
                present,
                held,
                needed,
              );

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: isDark
                ? Colors.white
                    .withOpacity(.07)
                : Colors.black
                    .withOpacity(.07),
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              Expanded(
                child: _detailMetric(
                  'CURRENT',
                  '${percentage.toStringAsFixed(1)}%',
                  text,
                  muted,
                  isDark,
                ),
              ),
              Expanded(
                child: _detailMetric(
                  'TARGET',
                  '$targetAttendance%',
                  text,
                  muted,
                  isDark,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(13),
            decoration:
                BoxDecoration(
              color: surface2,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration:
                      BoxDecoration(
                    color: status
                        .withOpacity(.10),
                    borderRadius:
                        BorderRadius
                            .circular(
                      9,
                    ),
                  ),
                  child: Icon(
                    canSkip
                        ? Icons
                            .event_available_rounded
                        : Icons
                            .event_note_rounded,
                    color: status,
                    size: 15,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        canSkip
                            ? 'You have some room to skip.'
                            : 'You need more attendance.',
                        style: TextStyle(
                          color: text,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        canSkip
                            ? 'You can skip the next $skippable '
                                '${skippable == 1 ? 'class' : 'classes'} '
                                'and still stay at or above your '
                                '$targetAttendance% target.'
                            : 'You need to attend the next $needed '
                                '${needed == 1 ? 'class' : 'classes'} '
                                'to reach your '
                                '$targetAttendance% target.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 9,
                          height: 1.45,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              Text(
                canSkip
                    ? 'SKIP PROJECTION'
                    : 'ATTENDANCE PROJECTION',
                style: TextStyle(
                  color: muted,
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                'TARGET $targetAttendance%',
                style: TextStyle(
                  color: muted,
                  fontSize: 8,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          ...projections.map(
            (projection) =>
                _buildProjectionRow(
              projection,
              canSkip,
              isDark,
              text,
              muted,
              status,
            ),
          ),

          const SizedBox(height: 3),

          Center(
            child: Text(
              'Tap to collapse',
              style: TextStyle(
                color: muted,
                fontSize: 8,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // SKIP PROJECTIONS
  // ==============================================================

  List<_Projection> _buildSkipProjections(
    int present,
    int held,
    int count,
  ) {
    final List<_Projection> result = [];

    for (int i = 1; i <= count; i++) {
      final double percentage =
          present /
                  (held + i) *
              100;

      result.add(
        _Projection(
          step: i,
          percentage: percentage,
        ),
      );
    }

    return result;
  }

  // ==============================================================
  // ATTEND PROJECTIONS
  // ==============================================================

  List<_Projection> _buildAttendProjections(
    int present,
    int held,
    int count,
  ) {
    final List<_Projection> result = [];

    for (int i = 1; i <= count; i++) {
      final double percentage =
          (present + i) /
                  (held + i) *
              100;

      result.add(
        _Projection(
          step: i,
          percentage: percentage,
        ),
      );
    }

    return result;
  }

  // ==============================================================
  // PROJECTION ROW
  // ==============================================================

  Widget _buildProjectionRow(
    _Projection projection,
    bool canSkip,
    bool isDark,
    Color text,
    Color muted,
    Color status,
  ) {
    final bool reachedTarget =
        projection.percentage >=
            targetAttendance;

    final Color rowColor =
        reachedTarget
            ? status
            : _danger;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 6,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color: isDark
            ? Colors.white
                .withOpacity(.035)
            : Colors.black
                .withOpacity(.025),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color: rowColor
                  .withOpacity(.09),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${projection.step}',
              style: TextStyle(
                color: rowColor,
                fontSize: 9,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Text(
            canSkip
                ? 'After ${projection.step} '
                    '${projection.step == 1 ? 'skip' : 'skips'}'
                : 'After ${projection.step} '
                    '${projection.step == 1 ? 'class' : 'classes'}',
            style: TextStyle(
              color: text,
              fontSize: 9,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const Spacer(),

          Text(
            '${projection.percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: rowColor,
              fontSize: 11,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          Icon(
            reachedTarget
                ? Icons.check_rounded
                : Icons
                    .arrow_downward_rounded,
            size: 13,
            color: rowColor,
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // DETAIL METRIC
  // ==============================================================

  Widget _detailMetric(
    String label,
    String value,
    Color text,
    Color muted,
    bool isDark,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        right: 7,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color: isDark
            ? Colors.white
                .withOpacity(.035)
            : Colors.black
                .withOpacity(.025),
        borderRadius:
            BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: muted,
              fontSize: 7,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: .9,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            value,
            style: TextStyle(
              color: text,
              fontSize: 15,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // EMPTY
  // ==============================================================

  Widget _buildEmptyState(
    Color surface,
    Color muted,
  ) {
    return Container(
      height: 130,
      decoration:
          BoxDecoration(
        color: surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .bar_chart_rounded,
              color: muted,
              size: 25,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'No attendance data',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 3,
            ),
            Text(
              'Sync with SRAAP to update',
              style: TextStyle(
                color:
                    muted.withOpacity(.7),
                fontSize: 9,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // ENTRANCE ANIMATION
  // ==============================================================

  Widget _buildAnimatedEntrance(
    int index,
    Widget child,
  ) {
    final double start =
        (index * .10)
            .clamp(0.0, .55);

    final double end =
        (start + .35)
            .clamp(
              start + .05,
              1.0,
            );

    final Animation<double>
        animation =
        CurvedAnimation(
      parent:
          _animationController,
      curve: Interval(
        start,
        end,
        curve:
            Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(
              0,
              (1 - animation.value) *
                  12,
            ),
            child: child,
          ),
        );
      },
    );
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _syncTimeoutTimer?.cancel();
    _syncSuccessTimer?.cancel();
    _setSraapVisibility(false);
    _animationController.dispose();

    super.dispose();
  }

}

// ==================================================================
// PROJECTION MODEL

class _Projection {
  final int step;
  final double percentage;

  const _Projection({
    required this.step,
    required this.percentage,
  });
}
