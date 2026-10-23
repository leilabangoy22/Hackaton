import 'dart:async';

import 'package:fdr/app_routes.dart';
import 'package:fdr/features/auth/auth_presentation/change_password/change_password_bloc.dart';
import 'package:fdr/features/auth/auth_presentation/change_password/change_password_bottomsheet.dart';
import 'package:fdr/features/auth/user/presentation/home/home_bloc.dart';
import 'package:fdr/features/auth/user/presentation/home/home_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:flutter_disposebag/flutter_disposebag.dart';
import 'package:flutter_provider/flutter_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  static const routeName = '/profile_page';

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with DisposeBagMixin {
  StreamSubscription<dynamic>? _messageSubscription;

  String userName = 'Juan Dela Cruz';
  String userEmail = 'juan.delacruz@example.com';

  static const String _aboutAppDescription =
      'This application allows users to view a map that shows which areas are flooded and its severity. It comes with a feature where users can send in reports of what areas are flooded, in which the app will send a warning to dispatchers.';

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserMobile = 'user_mobile';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _messageSubscription ??=
        BlocProvider.of<HomeBloc>(context).message$.listen(_handleHomeMessage);
  }

  void _handleHomeMessage(dynamic message) {
    debugPrint('[ProfilePage] Received message: $message');

    if (message is LogoutSuccessMessage) {
      _navigateToLogin();
    } else if (message is LogoutErrorMessage) {
      _showLogoutError(message.message);
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  void _showLogoutError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logout failed: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final storedName = prefs.getString(_keyUserName);
      final storedEmail = prefs.getString(_keyUserEmail);

      if (!mounted) return;

      setState(() {
        userName = storedName ?? 'Juan Dela Cruz';
        userEmail = storedEmail ?? 'juan.delacruz@example.com';
      });
    } catch (e) {
      debugPrint('[ProfilePage] Error loading user data: $e');
    }
  }

  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserRole);
      await prefs.remove(_keyUserMobile);
    } catch (e) {
      debugPrint('[ProfilePage] Error clearing user data: $e');
      rethrow;
    }
  }

  Future<void> _performLogoutWithCleanup(HomeBloc homeBloc) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Logging out...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      await _clearUserData();
    } catch (e) {
      debugPrint('[ProfilePage] Error during logout cleanup: $e');
    }

    if (!mounted) return;

    homeBloc.logout();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    HomeBloc homeBloc;

    try {
      homeBloc = context.bloc<HomeBloc>();
    } catch (e) {
      debugPrint('[FATAL BLoC Error] HomeBloc not found: $e');

      return Scaffold(
        appBar: AppBar(title: const Text('Profile (Error)')),
        body: const Center(
          child: Text(
            'Error: HomeBloc not provided. Cannot display profile functionality.',
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFF1B5E20),
                      child: Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            _buildProfileTile(
              context,
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () => _showChangePasswordSheet(context),
            ),
            const SizedBox(height: 20),
            Text(
              'General',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            _buildProfileTile(
              context,
              icon: Icons.info_outline,
              title: 'About App',
              onTap: _openAboutApp,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                _showLogoutConfirmationDialog(context, homeBloc);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: theme.colorScheme.error,
                    width: 1,
                  ),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAboutApp() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AboutAppEasterEggDialog(
        description: _aboutAppDescription,
      ),
    );
  }

  Widget _buildProfileTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet<void>(
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      context: context,
      builder: (context) {
        return BlocProvider<ChangePasswordBloc>(
          initBloc: (context) => ChangePasswordBloc(context.get()),
          child: const ChangePasswordBottomSheet(),
        );
      },
      backgroundColor: Theme.of(context).canvasColor,
    );
  }

  void _showLogoutConfirmationDialog(
    BuildContext context,
    HomeBloc homeBloc,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogoutWithCleanup(homeBloc);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

class AboutAppEasterEggDialog extends StatefulWidget {
  final String description;

  const AboutAppEasterEggDialog({
    super.key,
    required this.description,
  });

  @override
  State<AboutAppEasterEggDialog> createState() =>
      _AboutAppEasterEggDialogState();
}

class _AboutAppEasterEggDialogState extends State<AboutAppEasterEggDialog>
    with TickerProviderStateMixin {
  int _tapCount = 0;
  int _stage = -1;
  bool _showCloseButton = false;

  late final AnimationController _eggController;
  late final Animation<double> _eggAnimation;

  late final AnimationController _tapController;
  late final Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();

    _eggController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _eggAnimation = CurvedAnimation(
      parent: _eggController,
      curve: Curves.elasticOut,
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _tapScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.92).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.05).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 30,
      ),
    ]).animate(_tapController);
  }

  void _handleAboutTap() {
    if (_stage >= 0) return;

    _tapController.forward(from: 0);

    setState(() {
      _tapCount++;
    });

    if (_tapCount >= 7) {
      setState(() {
        _stage = 0;
      });

      _eggController.forward();
      _startAnimationStages();
    }
  }

  Future<void> _startAnimationStages() async {
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;
    setState(() => _stage = 1);

    await Future<void>.delayed(const Duration(milliseconds: 4000));

    if (!mounted) return;
    setState(() => _stage = 2);

    await Future<void>.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;
    setState(() => _showCloseButton = true);
  }

  @override
  void dispose() {
    _tapController.dispose();
    _eggController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showEasterEgg = _stage >= 0;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool smallScreen = screenHeight < 600;

    return Dialog(
      backgroundColor:
          showEasterEgg ? const Color(0xFF071B2B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenHeight * 0.92,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(smallScreen ? 12 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleAboutTap,
                child: ScaleTransition(
                  scale: _tapScale,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              showEasterEgg
                                  ? Icons.lock_open
                                  : Icons.info_outline,
                              color: showEasterEgg
                                  ? const Color(0xFFFFD54F)
                                  : const Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                showEasterEgg
                                    ? 'FLOOD CONTROL: ESTER EGG'
                                    : 'About App',
                                style: TextStyle(
                                  color: showEasterEgg
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: smallScreen ? 16 : 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!showEasterEgg) ...[
                          const SizedBox(height: 18),
                          Text(
                            widget.description,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (showEasterEgg) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: smallScreen ? 150 : 220,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _stage == 0
                        ? ScaleTransition(
                            key: const ValueKey('egg'),
                            scale: _eggAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '🥚',
                                  style: TextStyle(
                                    fontSize: smallScreen ? 65 : 90,
                                  ),
                                ),
                                const Text(
                                  'A mysterious egg appeared...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        : _stage == 1
                            ? FloodWaveScene(
                                key: const ValueKey('flood'),
                                compact: smallScreen,
                              )
                            : Column(
                                key: const ValueKey('congratulations'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🎉🐊🎉',
                                    style: TextStyle(
                                      fontSize: smallScreen ? 36 : 48,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'CONGRATULATIONS!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFFFFD54F),
                                      fontSize: smallScreen ? 19 : 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'You Have Lost 107.4 Billion Peso due to the Crocodiles!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                  ),
                ),
                if (_showCloseButton) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FloodWaveScene extends StatefulWidget {
  final bool compact;

  const FloodWaveScene({
    super.key,
    this.compact = false,
  });

  @override
  State<FloodWaveScene> createState() => _FloodWaveSceneState();
}

class _FloodWaveSceneState extends State<FloodWaveScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double crocodileSize = widget.compact ? 38 : 52;
    final double waveSize = widget.compact ? 15 : 20;
    final double labelSize = widget.compact ? 12 : 14;
    final double budgetSize = widget.compact ? 17 : 21;

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final double bob = _waveController.value * 6;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, bob - 3),
              child: Text(
                '🐊',
                style: TextStyle(fontSize: crocodileSize),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '🌊🌊🌊🌊🌊🌊🌊',
              style: TextStyle(fontSize: waveSize),
            ),
            SizedBox(height: widget.compact ? 3 : 4),
            Text(
              'NOM NOM!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: labelSize,
              ),
            ),
            SizedBox(height: widget.compact ? 2 : 3),
            Text(
              '₱107.4 BILLION',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFF6E6E),
                fontWeight: FontWeight.w900,
                fontSize: budgetSize,
                decoration: TextDecoration.lineThrough,
                decorationThickness: 3,
              ),
            ),
            Text(
              'Where did the budget go? 🫧',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: widget.compact ? 9 : 11,
              ),
            ),
          ],
        );
      },
    );
  }
}