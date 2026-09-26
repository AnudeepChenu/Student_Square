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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  late final AnimationController _introController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isSubmitting = false;

  static const Color accent = Color(0xFF6376F5);

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, .045),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    _nameFocusNode.addListener(_onFocusChanged);

    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) _introController.forward();
    });
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.removeListener(_onFocusChanged);
    _nameFocusNode.dispose();
    _introController.dispose();
    super.dispose();
  }

  bool _isValidName(String name) {
    return name.isNotEmpty &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(name) &&
        !RegExp(r'^\d').hasMatch(name) &&
        !RegExp(r'\d$').hasMatch(name);
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;

    final name = _nameController.text.trim();

    if (!_isValidName(name)) {
      _nameFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a valid name using letters only.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    await SessionManager.saveProfile({
      'name': name,
      'rollNo': 'Secured Profile',
      'email': 'student@sruniv.edu',
      'branch': 'Computer Science Engineering',
      'semester': '4th Semester',
    });

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            MainNavigationWrapper(
          onThemeChanged: widget.onThemeChanged ?? () {},
          isDarkMode: widget.isDarkMode ??
              (Theme.of(context).brightness == Brightness.dark),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: .985, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode ??
        (Theme.of(context).brightness == Brightness.dark);

    final background =
        isDark ? const Color(0xFF090A0B) : const Color(0xFFF6F6F3);
    final surface = isDark ? const Color(0xFF111315) : Colors.white;
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final secondary =
        isDark ? const Color(0xFF92959A) : const Color(0xFF77797D);
    final muted =
        isDark ? Colors.white.withOpacity(.30) : Colors.black.withOpacity(.28);
    final border =
        isDark ? Colors.white.withOpacity(.055) : Colors.black.withOpacity(.055);
    final focused = _nameFocusNode.hasFocus;

    return FocusScope(
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -110,
                right: -100,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(isDark ? .035 : .025),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 26),
                          Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: .84, end: 1),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(21),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(.16),
                                      blurRadius: 26,
                                      offset: const Offset(0, 9),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  size: 29,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          Center(
                            child: Text(
                              'Student Square',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: primary,
                                fontSize: 29,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 11),
                          Center(
                            child: Text(
                              'Your student dashboard, simplified.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: secondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 54),
                          Text(
                            'WELCOME',
                            style: TextStyle(
                              color: secondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: focused
                                    ? accent.withOpacity(.55)
                                    : border,
                                width: 1,
                              ),
                              boxShadow: focused
                                  ? [
                                      BoxShadow(
                                        color: accent.withOpacity(.07),
                                        blurRadius: 20,
                                        offset: const Offset(0, 7),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: TextField(
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              style: TextStyle(
                                color: primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter your name',
                                hintStyle: TextStyle(
                                  color: muted,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 220),
                                  width: 48,
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                    color: focused ? accent : secondary,
                                  ),
                                ),
                                suffixIcon: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  child: _nameController.text.isNotEmpty
                                      ? Icon(
                                          Icons.check_rounded,
                                          key: const ValueKey('check'),
                                          size: 19,
                                          color: accent,
                                        )
                                      : const SizedBox(
                                          key: ValueKey('empty'),
                                          width: 19,
                                        ),
                                ),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 18,
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: _isSubmitting
                                    ? accent.withOpacity(.70)
                                    : accent,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(
                                      _isSubmitting ? .05 : .14,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap:
                                      _isSubmitting ? null : _handleLogin,
                                  splashColor:
                                      Colors.white.withOpacity(.10),
                                  highlightColor:
                                      Colors.white.withOpacity(.05),
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 240),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder:
                                          (child, animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: ScaleTransition(
                                            scale: Tween<double>(
                                              begin: .88,
                                              end: 1,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              key: ValueKey('loading'),
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Row(
                                              key: ValueKey('continue'),
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Continue',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 13,
                                  color: muted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Stored securely on this device',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
