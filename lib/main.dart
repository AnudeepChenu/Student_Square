import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final profile = await SessionManager.getProfile();
  final bool isLoggedIn =
      profile.isNotEmpty && profile['name'] != null;
  final bool savedDarkMode =
      await SessionManager.getDarkModePreference();

  runApp(
    StudentSquareApp(
      isLoggedIn: isLoggedIn,
      initialDarkMode: savedDarkMode,
    ),
  );
}

class StudentSquareApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool initialDarkMode;

  const StudentSquareApp({
    super.key,
    required this.isLoggedIn,
    required this.initialDarkMode,
  });

  @override
  State<StudentSquareApp> createState() =>
      _StudentSquareAppState();
}

class _StudentSquareAppState extends State<StudentSquareApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  Future<void> toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });

    await SessionManager.saveDarkModePreference(
      _isDarkMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6376F5);

    return MaterialApp(
      title: 'Student Square',
      debugShowCheckedModeBanner: false,
      themeMode:
          _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor:
            const Color(0xFFF6F6F3),
        primaryColor: accent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            const Color(0xFF090A0B),
        primaryColor: accent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: widget.isLoggedIn
          ? MainNavigationWrapper(
              onThemeChanged: toggleTheme,
              isDarkMode: _isDarkMode,
            )
          : LoginScreen(
              onThemeChanged: toggleTheme,
              isDarkMode: _isDarkMode,
            ),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final bool isDarkMode;

  const MainNavigationWrapper({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<MainNavigationWrapper> createState() =>
      _MainNavigationWrapperState();
}

class _MainNavigationWrapperState
    extends State<MainNavigationWrapper>
    with SingleTickerProviderStateMixin {
  static const Color accent =
      Color(0xFF6376F5);

  int _currentIndex = 0;
  bool _hideNavigationBar = false;

  late final AnimationController
      _navigationController;

  final List<IconData> _icons = const [
    Icons.home_rounded,
    Icons.bar_chart_rounded,
    Icons.calendar_month_rounded,
    Icons.event_note_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();

    _navigationController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 460),
    );
  }

  @override
  void dispose() {
    _navigationController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });

    _navigationController.forward(from: 0);
  }

  void _setSraapVisibility(bool visible) {
    if (!mounted) return;

    if (_hideNavigationBar == visible) {
      return;
    }

    setState(() {
      _hideNavigationBar = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;

    final List<Widget> screens = [
      HomeScreen(
        key: ValueKey(isDark),
        onThemeChanged:
            widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
        onNavigate: _navigateToTab,
      ),

      AttendanceScreen(
        onSraapVisibilityChanged:
            _setSraapVisibility,
      ),

      const TimetableScreen(),

      const CalendarScreen(),

      ProfileScreen(
        onThemeChanged:
            widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar:
          _hideNavigationBar
              ? null
              : _buildNavigationBar(isDark),
    );
  }

  // ==============================================================
  // FLOATING NAVIGATION
  //
  // Reference style:
  // - black/dark floating island
  // - active tab becomes a wider pill
  // - active pill contains icon + label
  // - inactive tabs show icon only
  // - no permanent labels
  // ==============================================================

  Widget _buildNavigationBar(bool isDark) {
    final Color surface =
        isDark ? const Color(0xFF111315) : Colors.white;

    final Color activeSurface =
        isDark ? const Color(0xFF292C31) : const Color(0xFFE9E9E5);

    final Color border =
        isDark
            ? Colors.white.withOpacity(.055)
            : Colors.black.withOpacity(.05);

    final Color inactive =
        isDark ? const Color(0xFF858990) : const Color(0xFF8A8C90);

    final Color selectedColor =
        isDark ? Colors.white : const Color(0xFF17181A);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: surface.withOpacity(.985),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  isDark ? .26 : .065,
                ),
                blurRadius: 22,
                offset: const Offset(0, 7),
                spreadRadius: -9,
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double slotWidth =
                  constraints.maxWidth / _icons.length;

              return Stack(
                children: [
                  // The active surface glides between navigation slots.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    left: slotWidth * _currentIndex +
                        (slotWidth - 44) / 2,
                    top: 1,
                    child: IgnorePointer(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        scale: 1.0,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: activeSurface,
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Row(
                    children: List.generate(
                      _icons.length,
                      (index) => SizedBox(
                        width: slotWidth,
                        child: _buildNavItem(
                          index,
                          _icons[index],
                          inactive,
                          selectedColor,
                          activeSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _navigationPulse(double t) {
    if (t < .5) {
      return Curves.easeOutCubic.transform(t * 2);
    }

    return Curves.easeInCubic.transform((1 - t) * 2);
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    Color inactive,
    Color selectedColor,
    Color activeSurface,
  ) {
    final bool selected = _currentIndex == index;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Navigation item ${index + 1}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _navigateToTab(index),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );

                return FadeTransition(
                  opacity: curved,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: .78,
                      end: 1,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: Icon(
                icon,
                key: ValueKey('${index}_$selected'),
                size: selected ? 20 : 21,
                color: selected ? selectedColor : inactive,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
