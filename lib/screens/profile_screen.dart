import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../session_manager.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final bool isDarkMode;

  const ProfileScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic> profileData = {};
  bool isLoading = true;
  int _devTapCount = 0;
  bool _showContactEmail = false;
  bool _notificationsEnabled = false;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initNotifications();
  }

  void _loadProfile() async {
    final data = await SessionManager.getProfile();
    final notifs = await SessionManager.getNotificationPreference();
    if (mounted) {
      setState(() {
        profileData = data.isNotEmpty ? data : {
          'name': 'Student',
          'rollNo': 'Hall Ticket: 2403aXXXXX',
          'email': 'student@sruniv.edu',
          'branch': 'Computer Science Engineering',
          'semester': '4th Semester',
        };
        _notificationsEnabled = notifs;
        isLoading = false;
      });
    }
  }

  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _requestPermissionAndToggle(bool val) async {
    if (val) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      // Requests the standard, native notification permission popup dialog
      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      
      if (granted != true) {
        return; // Keeps the toggle off if the user denies the permission
      }
    }

    setState(() {
      _notificationsEnabled = val;
    });
    await SessionManager.saveNotificationPreference(val);
  }

  void _logout() async {
    await SessionManager.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            onThemeChanged: widget.onThemeChanged,
            isDarkMode: widget.isDarkMode,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isDark = widget.isDarkMode;
    
    Color boxColor = isDark ? const Color(0xFF161618) : const Color(0xFFF2F2F7);
    Color borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);

    return Scaffold(
      appBar: AppBar(
        title: const Text('  Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, size: 32, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profileData['name']?.toString() ?? 'Student',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profileData['rollNo']?.toString() ?? 'Hall Ticket: 2403aXXXXX',
                                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Preferences',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.dark_mode_rounded, size: 22, color: Color(0xFFFF3B30)),
                                SizedBox(width: 14),
                                Text(
                                  'Dark Mode',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Switch(
                              value: isDark,
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFFFF3B30),
                              onChanged: (val) => widget.onThemeChanged(),
                            ),
                          ],
                        ),
                        Divider(height: 1, color: borderColor),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.notifications_active_rounded, size: 22, color: Color(0xFFFF3B30)),
                                SizedBox(width: 14),
                                Text(
                                  'Class Reminders',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Switch(
                              value: _notificationsEnabled,
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFFFF3B30),
                              onChanged: (val) => _requestPermissionAndToggle(val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'App Info',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Version',
                              style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const Text(
                              'Version 2',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _devTapCount++;
                              if (_devTapCount >= 16) {
                                _showContactEmail = true;
                              }
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Developer',
                                    style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  ),
                                  const Text(
                                    'ADP',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFFF3B30)),
                                  ),
                                ],
                              ),
                              if (_showContactEmail) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Contact',
                                      style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                    const Text(
                                      'adp.official.in@gmail.com',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF3B30)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF3B30),
                      side: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: Color(0xFFFF3B30)),
                        SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF3B30),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}