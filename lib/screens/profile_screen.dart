import 'package:flutter/material.dart';
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

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic> profileData = {};
  bool isLoading = true;

  // StudentSquare unified theme
  static const Color accent = Color(0xFF6376F5);
  static const Color healthy = Color(0xFF55C98A);
  static const Color danger = Color(0xFFE86B6B);

  static const Color darkBackground = Color(0xFF090A0B);
  static const Color darkSurface = Color(0xFF111315);
  static const Color darkSecondary = Color(0xFF181A1D);

  static const Color lightBackground = Color(0xFFF6F6F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSecondary = Color(0xFFEEEEEA);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await SessionManager.getProfile();

    if (!mounted) return;

    setState(() {
      profileData = data.isNotEmpty
          ? data
          : {
              'name': 'Student',
              'rollNo': 'Hall Ticket: 2403aXXXXX',
              'email': 'student@sruniv.edu',
              'branch': 'Computer Science Engineering',
              'semester': '4th Semester',
            };

      isLoading = false;
    });
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onThemeChanged: widget.onThemeChanged,
          isDarkMode: widget.isDarkMode,
        ),
      ),
      (_) => false,
    );
  }

  void _toggleTheme() {
    widget.onThemeChanged();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bool isDark = widget.isDarkMode;

    final Color background =
        isDark ? darkBackground : lightBackground;

    final Color surface =
        isDark ? darkSurface : lightSurface;

    final Color secondarySurface =
        isDark ? darkSecondary : lightSecondary;

    final Color primary =
        isDark ? Colors.white : const Color(0xFF111111);

    final Color secondary =
        isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);

    final Color divider = isDark
        ? Colors.white.withOpacity(0.055)
        : Colors.black.withOpacity(0.055);

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROFILE',
              style: TextStyle(
                color: secondary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Profile',
              style: TextStyle(
                color: primary,
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ],
        ),

        actions: [
          _themeButton(
            isDark: isDark,
            surface: secondarySurface,
            primary: primary,
          ),
          const SizedBox(width: 16),
        ],

        toolbarHeight: 72,
      ),

      body: isLoading
          ? Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent,
                ),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                18,
                4,
                18,
                120,
              ),
              children: [
                _buildProfileCard(
                  isDark: isDark,
                  surface: surface,
                  primary: primary,
                  secondary: secondary,
                  divider: divider,
                ),

                const SizedBox(height: 28),

                _sectionLabel(
                  'PROFILE DETAILS',
                  secondary,
                ),

                const SizedBox(height: 10),

                _buildDetailsCard(
                  isDark: isDark,
                  surface: surface,
                  primary: primary,
                  secondary: secondary,
                  divider: divider,
                ),

                const SizedBox(height: 28),

                _sectionLabel(
                  'ABOUT',
                  secondary,
                ),

                const SizedBox(height: 10),

                _buildAboutCard(
                  isDark: isDark,
                  surface: surface,
                  primary: primary,
                  secondary: secondary,
                  divider: divider,
                ),

                const SizedBox(height: 28),

                _buildLogoutButton(
                  isDark: isDark,
                ),
              ],
            ),
    );
  }

  // ============================================================
  // THEME BUTTON
  // ============================================================

  Widget _themeButton({
    required bool isDark,
    required Color surface,
    required Color primary,
  }) {
    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: GestureDetector(
        onTap: _toggleTheme,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.055)
                  : Colors.black.withOpacity(0.055),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: Tween<double>(
                  begin: 0.85,
                  end: 1,
                ).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Icon(
              isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              size: 19,
              color: isDark ? Colors.white : primary,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE CARD
  // ============================================================

  Widget _buildProfileCard({
    required bool isDark,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color divider,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: divider,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profileData['name']?.toString() ?? 'Student',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  profileData['rollNo']?.toString() ??
                      'Secured Profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION LABEL
  // ============================================================

  Widget _sectionLabel(
    String text,
    Color color,
  ) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }

  // ============================================================
  // PROFILE DETAILS
  // ============================================================

  Widget _buildDetailsCard({
    required bool isDark,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color divider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: divider,
        ),
      ),
      child: Column(
        children: [
          _infoTile(
            Icons.school_outlined,
            'Branch',
            profileData['branch']?.toString() ??
                'Computer Science Engineering',
            primary,
            secondary,
          ),

          Divider(
            height: 1,
            indent: 58,
            endIndent: 18,
            color: divider,
          ),

          _infoTile(
            Icons.layers_outlined,
            'Semester',
            profileData['semester']?.toString() ??
                '4th Semester',
            primary,
            secondary,
          ),

          Divider(
            height: 1,
            indent: 58,
            endIndent: 18,
            color: divider,
          ),

          _infoTile(
            Icons.email_outlined,
            'Email',
            profileData['email']?.toString() ??
                'student@sruniv.edu',
            primary,
            secondary,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ABOUT
  // ============================================================

  Widget _buildAboutCard({
    required bool isDark,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color divider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: divider,
        ),
      ),
      child: Column(
        children: [
          _infoTile(
            Icons.apps_rounded,
            'App Version',
            'v3',
            primary,
            secondary,
          ),

          Divider(
            height: 1,
            indent: 58,
            endIndent: 18,
            color: divider,
          ),

          _infoTile(
            Icons.code_rounded,
            'Developer',
            'ADP',
            primary,
            secondary,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Widget _buildLogoutButton({
    required bool isDark,
  }) {
    final Color logoutColor = danger;

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _logout,
        style: OutlinedButton.styleFrom(
          foregroundColor: logoutColor,
          side: BorderSide(
            color: logoutColor.withOpacity(0.35),
          ),
          backgroundColor: logoutColor.withOpacity(0.035),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              size: 18,
              color: logoutColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: TextStyle(
                color: logoutColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO TILE
  // ============================================================

  Widget _infoTile(
    IconData icon,
    String label,
    String value,
    Color primary,
    Color secondary,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        15,
        18,
        15,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: accent,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontSize: 13.5,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}