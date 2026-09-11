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
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _isPasswordStrong(String password) {
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    final hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final hasMinLength = password.length >= 8;

    return hasMinLength && hasUppercase && hasLowercase && hasDigit && hasSpecialChar;
  }

  void _handleLogin() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    final isValidName = RegExp(r'^[a-zA-Z\s]+$').hasMatch(name) && 
                        !RegExp(r'^\d').hasMatch(name) && 
                        !RegExp(r'\d$').hasMatch(name);

    if (!isValidName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid name (no leading/trailing numbers).')),
      );
      return;
    }

    if (!_isPasswordStrong(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please make your password stronger (at least 8 chars, include uppercase, lowercase, number, and special character).'),
        ),
      );
      return;
    }

    await SessionManager.saveProfile({
      'name': name,
      'rollNo': 'Secured Profile',
      'email': 'student@sruniv.edu',
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
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF3B30).withOpacity(0.15),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.school_rounded,
                            size: 40,
                            color: Color(0xFFFF3B30),
                          ),
                        ),
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
                    'Enter your name and a strong password to get started.',
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
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter a strong password',
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
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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