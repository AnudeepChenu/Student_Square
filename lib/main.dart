import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'session_manager.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final profile = await SessionManager.getProfile();
  final bool isLoggedIn = profile.isNotEmpty && profile['name'] != null;
  final bool savedDarkMode = await SessionManager.getDarkModePreference();

  runApp(StudentSquareApp(isLoggedIn: isLoggedIn, initialDarkMode: savedDarkMode));
}

class StudentSquareApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool initialDarkMode;
  const StudentSquareApp({super.key, required this.isLoggedIn, required this.initialDarkMode});

  @override
  State<StudentSquareApp> createState() => _StudentSquareAppState();
}

class _StudentSquareAppState extends State<StudentSquareApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  void toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await SessionManager.saveDarkModePreference(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Square',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFFFF3B30),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFF3B30),
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
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;

    final List<Widget> screens = [
      HomeScreen(
        key: ValueKey(isDark),
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
        onNavigate: _navigateToTab,
      ),
      const AttendanceScreen(),
      const TimetableScreen(),
      ProfileScreen(
        onThemeChanged: widget.onThemeChanged,
        isDarkMode: widget.isDarkMode,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(isDark ? 0.20 : 0.35),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_rounded),
                  _buildNavItem(1, Icons.bar_chart_rounded),
                  _buildNavItem(2, Icons.calendar_month_rounded),
                  _buildNavItem(3, Icons.person_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _navigateToTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF3B30).withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFFFF3B30) : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}