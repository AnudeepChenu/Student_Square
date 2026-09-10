import 'package:flutter/material.dart';
import '../session_manager.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  final bool? isDarkMode;

  const LoginScreen({
    super.key,
    this.onThemeChanged,
    this.isDarkMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _hallTicketController = TextEditingController();

  void _handleLogin() async {
    final name = _nameController.text.trim();
    final hallTicket = _hallTicketController.text.trim();

    // Name constraint: Must only contain letters/spaces and not start/end with numbers
    final isValidName = RegExp(r'^[a-zA-Z\s]+$').hasMatch(name) && 
                        !RegExp(r'^\d').hasMatch(name) && 
                        !RegExp(r'\d$').hasMatch(name);

    // Hall ticket constraints: Length 10, contains at least one letter, starts with 23, 24, 25, or 26
    final isValidHallTicket = RegExp(r'^(23|24|25|26)').hasMatch(hallTicket) &&
                              hallTicket.length == 10 &&
                              RegExp(r'[a-zA-Z]').hasMatch(hallTicket);

    if (!isValidName || !isValidHallTicket) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Name/Roll number'),
        ),
      );
      return;
    }

    await SessionManager.saveProfile({
      'name': name,
      'rollNo': 'Hall Ticket: $hallTicket',
      'email': '$hallTicket@sruniv.edu',
      'branch': 'Computer Science Engineering',
      'semester': '4th Semester',
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainNavigationWrapper(
            onThemeChanged: widget.onThemeChanged ?? () {},
            isDarkMode: widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    Color boxColor = isDark ? const Color(0xFF161618) : const Color(0xFFF2F2F7);
    Color borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 48,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 40,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Student Square',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your details to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter your name',
                      filled: true,
                      fillColor: boxColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: borderColor, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: borderColor, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hallTicketController,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Hall Ticket Number',
                      hintText: 'e.g. 2403aXXXXX',
                      filled: true,
                      fillColor: boxColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: borderColor, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: borderColor, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _handleLogin,
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}