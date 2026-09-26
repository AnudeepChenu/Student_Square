import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'session_manager.dart';

class PortalSession {
  PortalSession._();

  static final PortalSession instance =
      PortalSession._();

  static const String loginUrl =
      'https://sraap.in/student_login.php';

  static const String homeUrl =
      'https://sraap.in';

  late final WebViewController controller;

  bool initialized = false;
  bool loggedIn = false;
  bool isBusy = false;

  // --------------------------------------------------------------
  // INITIALIZE
  // --------------------------------------------------------------

  Future<void> initialize() async {
    if (initialized) {
      return;
    }

    initialized = true;

    controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint(
              'SRAAP page started: $url',
            );
          },

          onPageFinished: (String url) {
            debugPrint(
              'SRAAP page finished: $url',
            );
          },

          onWebResourceError: (error) {
            debugPrint(
              'SRAAP WebView error: ${error.description}',
            );
          },
        ),
      );

    loggedIn =
        await SessionManager.isPortalLoggedIn();
  }

  // --------------------------------------------------------------
  // LOGIN PAGE
  // --------------------------------------------------------------

  Future<void> openLogin() async {
    await initialize();

    loggedIn = false;

    await SessionManager
        .clearPortalSession();

    await controller.loadRequest(
      Uri.parse(loginUrl),
    );
  }

  // --------------------------------------------------------------
  // LOGIN PAGE DETECTION
  // --------------------------------------------------------------

  bool isLoginUrl(String url) {
    final lower =
        url.toLowerCase();

    return lower.contains(
          'student_login.php',
        ) ||
        lower.contains('/login') ||
        lower.contains('signin') ||
        lower.contains('sign-in');
  }

  // --------------------------------------------------------------
  // CHECK CURRENT PAGE
  // --------------------------------------------------------------

  Future<bool> isCurrentlyLoggedIn() async {
    await initialize();

    try {
      final String? url =
          await controller.currentUrl();

      if (url == null ||
          isLoginUrl(url)) {
        return false;
      }

      return true;
    } catch (_) {
      return loggedIn;
    }
  }

  // --------------------------------------------------------------
  // ATTENDANCE JAVASCRIPT
  // --------------------------------------------------------------

  Future<List<Map<String, dynamic>>>
      extractAttendance() async {
    await initialize();

    const String script = '''
      (function() {
        const rows = document.querySelectorAll('tr');

        if (rows.length === 0) {
          return JSON.stringify([]);
        }

        let subjectList = [];

        rows.forEach(row => {
          const cells = row.children;

          if (cells.length >= 5) {
            const courseLink =
                cells[1].querySelector('a');

            /*
             * Keep the original attendance detection logic.
             * It looks at the attendance rows on the home page.
             */

            if (
              courseLink &&
              courseLink.href
                  .toLowerCase()
                  .includes('attendance')
            ) {
              const name =
                  courseLink.innerText.trim();

              const held =
                  parseInt(
                    cells[3].innerText.trim(),
                    10
                  ) || 0;

              const pr =
                  parseInt(
                    cells[4].innerText.trim(),
                    10
                  ) || 0;

              if (held > 0) {
                subjectList.push({
                  "name": name,
                  "held": held,
                  "present": pr
                });
              }
            }
          }
        });

        /*
         * If the page has no attendance links but
         * contains the attendance table directly,
         * use a broader fallback.
         */

        if (subjectList.length === 0) {
          const tables =
              document.querySelectorAll('table');

          tables.forEach(table => {
            const tableText =
                table.innerText
                    .trim()
                    .toLowerCase();

            if (
              tableText.includes('attendance') ||
              tableText.includes('present')
            ) {
              const tableRows =
                  table.querySelectorAll('tr');

              tableRows.forEach(row => {
                const cells =
                    row.querySelectorAll('td, th');

                if (cells.length >= 5) {
                  const texts = [];

                  cells.forEach(cell => {
                    texts.push(
                      cell.innerText.trim()
                    );
                  });

                  /*
                   * Same column positions as the
                   * original scraper.
                   */

                  const name =
                      texts[1] || '';

                  const held =
                      parseInt(
                        texts[3],
                        10
                      ) || 0;

                  const pr =
                      parseInt(
                        texts[4],
                        10
                      ) || 0;

                  if (
                    name.length > 0 &&
                    held > 0
                  ) {
                    subjectList.push({
                      "name": name,
                      "held": held,
                      "present": pr
                    });
                  }
                }
              });
            }
          });
        }

        return JSON.stringify(
          subjectList
        );
      })();
    ''';

    try {
      final result =
          await controller
              .runJavaScriptReturningResult(
        script,
      );

      if (result == null) {
        return [];
      }

      String rawJson =
          result.toString();

      if (rawJson.startsWith('"') &&
          rawJson.endsWith('"')) {
        rawJson = rawJson.substring(
          1,
          rawJson.length - 1,
        );

        rawJson = rawJson
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\');
      }

      final decoded =
          jsonDecode(rawJson);

      if (decoded is! List) {
        return [];
      }

      final List<Map<String, dynamic>>
          parsedSubjects = [];

      for (final item in decoded) {
        if (item is Map) {
          parsedSubjects.add({
            'name':
                item['name']?.toString() ??
                    'Subject',

            'present':
                int.tryParse(
                      item['present']
                              ?.toString() ??
                          '0',
                    ) ??
                    0,

            'held':
                int.tryParse(
                      item['held']
                              ?.toString() ??
                          '0',
                    ) ??
                    0,
          });
        }
      }

      return parsedSubjects;
    } catch (e) {
      debugPrint(
        'Attendance extraction error: $e',
      );

      return [];
    }
  }

  // --------------------------------------------------------------
  // SAVE ATTENDANCE
  // --------------------------------------------------------------

  Future<bool> saveCurrentAttendance() async {
    final data =
        await extractAttendance();

    if (data.isEmpty) {
      return false;
    }

    await SessionManager.saveAttendance(
      data,
    );

    loggedIn = true;

    await SessionManager.setPortalLoggedIn(
      true,
    );

    final currentUrl =
        await controller.currentUrl();

    if (currentUrl != null &&
        !isLoginUrl(currentUrl)) {
      await SessionManager.savePortalHomeUrl(
        currentUrl,
      );
    }

    return true;
  }

  // --------------------------------------------------------------
  // SILENT REFRESH
  // --------------------------------------------------------------

  Future<PortalRefreshResult>
      refreshAttendance() async {
    await initialize();

    if (isBusy) {
      return PortalRefreshResult.busy;
    }

    isBusy = true;

    try {
      /*
       * Always go to the SRAAP root/home page.
       *
       * Because this is the SAME WebView controller,
       * the existing SRAAP cookies/session are reused.
       */

      final completer =
          Completer<PortalRefreshResult>();

      late final NavigationDelegate delegate;

      delegate = NavigationDelegate(
        onPageStarted: (String url) {
          debugPrint(
            'Silent SRAAP load: $url',
          );

          if (isLoginUrl(url)) {
            if (!completer.isCompleted) {
              completer.complete(
                PortalRefreshResult
                    .sessionExpired,
              );
            }
          }
        },

        onPageFinished: (String url) async {
          debugPrint(
            'Silent SRAAP finished: $url',
          );

          if (isLoginUrl(url)) {
            if (!completer.isCompleted) {
              completer.complete(
                PortalRefreshResult
                    .sessionExpired,
              );
            }

            return;
          }

          /*
           * Give the page a moment to finish
           * rendering its attendance table.
           */

          await Future.delayed(
            const Duration(
              milliseconds: 500,
            ),
          );

          try {
            final data =
                await extractAttendance();

            if (data.isEmpty) {
              if (!completer.isCompleted) {
                completer.complete(
                  PortalRefreshResult
                      .noAttendance,
                );
              }

              return;
            }

            await SessionManager
                .saveAttendance(data);

            await SessionManager
                .setPortalLoggedIn(true);

            await SessionManager
                .savePortalHomeUrl(url);

            loggedIn = true;

            if (!completer.isCompleted) {
              completer.complete(
                PortalRefreshResult
                    .success,
              );
            }
          } catch (e) {
            debugPrint(
              'Silent extraction error: $e',
            );

            if (!completer.isCompleted) {
              completer.complete(
                PortalRefreshResult
                    .error,
              );
            }
          }
        },

        onWebResourceError: (error) {
          debugPrint(
            'Silent SRAAP error: '
            '${error.description}',
          );

          if (!completer.isCompleted) {
            completer.complete(
              PortalRefreshResult.error,
            );
          }
        },
      );

      controller.setNavigationDelegate(
        delegate,
      );

      /*
       * THIS IS THE IMPORTANT PART:
       *
       * Same controller.
       * Same WebView.
       * Same cookies.
       * No visible PortalWebViewScreen.
       */

      await controller.loadRequest(
        Uri.parse(homeUrl),
      );

      final result =
          await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            PortalRefreshResult.error,
      );

      return result;
    } catch (e) {
      debugPrint(
        'Portal refresh error: $e',
      );

      return PortalRefreshResult.error;
    } finally {
      isBusy = false;
    }
  }
}

enum PortalRefreshResult {
  success,
  sessionExpired,
  noAttendance,
  error,
  busy,
}