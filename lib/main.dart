import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/timetable_screen.dart';
import 'session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if session exists to route directly to Home or Login
  final session = await SessionManager.getSession();
  bool isLoggedIn = session['hallTicket'] != null;

  runApp(StudentSquareApp(initialRoute: isLoggedIn ? '/home' : '/login'));
}

class StudentSquareApp extends StatelessWidget {
  final String initialRoute;
  const StudentSquareApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Square',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Preserving dark/light specification
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/attendance': (context) => const AttendanceScreen(),
        '/timetable': (context) => const TimetableScreen(),
      },
    );
  }
}