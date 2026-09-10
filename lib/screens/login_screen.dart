import 'package:flutter/material.dart';
import '../validator.dart';
import '../session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _hallTicketController = TextEditingController();
  String? _errorMessage;

  void _handleLogin() async {
    String name = _nameController.text;
    String hallTicket = _hallTicketController.text;

    if (!Validators.validateName(name)) {
      setState(() {
        _errorMessage = 'Please enter a valid name (letters only, min 3 chars).';
      });
      return;
    }

    if (!Validators.validateHallTicket(hallTicket)) {
      setState(() {
        _errorMessage = 'Invalid Hall Ticket. Must start with 23, 24, 25, 26, or 27.';
      });
      return;
    }

    // Save locally via SharedPreferences (Zero backend required)
    await SessionManager.saveSession(name, hallTicket);

    // Navigate to Home Screen (to be created next)
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Student Square',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your Classes. Your Control.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _hallTicketController,
              decoration: const InputDecoration(
                labelText: 'Hall Ticket (e.g., 2403a52377)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 14),
              ),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleLogin,
                child: const Text('Proceed →', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}