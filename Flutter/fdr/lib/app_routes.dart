// lib/app/routes.dart

import 'package:fdr/features/auth/data/auth_state.dart';
import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:fdr/features/auth/dispatcher/dashboard.dart';
import 'package:fdr/features/auth/dispatcher/operations_page.dart';
import 'package:fdr/features/auth/login/login_page.dart';
import 'package:fdr/features/auth/register/register_bloc.dart';
import 'package:fdr/features/auth/register/register_page.dart';
import 'package:fdr/features/auth/rescuer/presentation/rescuer_home_page.dart';
import 'package:fdr/features/auth/user/presentation/profile/profile_page.dart';
import 'package:fdr/features/auth/user/presentation/report_flood/report_flood_page.dart';
import 'package:fdr/features/auth/user/presentation/home/home_page.dart';
import 'package:fdr/features/auth/auth_presentation/reset_password/reset_password_page.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:fdr/features/auth/user/presentation/home/home_bloc.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRoutes {
  // Auth routes
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Main app routes
  static const String home = '/home';
  static const String profile = '/profile';
  static const String reportFlood = '/report-flood';
  static const String reportDetails = '/report-details';

  // Dispatcher routes
  static const String dispatcherDashboard = '/dispatcher-dashboard';
  static const String operations = '/operations';

  // Rescuer routes
  static const String rescuerHome = '/rescuer_home_page';

  // feature routes
  static const String settings = '/settings';
  static const String changePassword = '/change-password';
  static const String about = '/about';

  static const String initialRoute = splash;

  static List<String> get allRoutes => [
    splash,
    login,
    register,
    forgotPassword,
    resetPassword,
    home,
    profile,
    reportFlood,
    reportDetails,
    dispatcherDashboard,
    operations,
    rescuerHome,
    settings,
    changePassword,
    about,
  ];
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _buildRoute(settings, const SplashPage());

      case AppRoutes.login:
        return _buildRoute(settings, const LoginPage());

      case AppRoutes.register:
        return _buildRoute(
          settings,
          BlocProvider<RegisterBloc>(
            initBloc: (context) =>
                RegisterBloc(apiService: ApiService()),
            child: const RegisterPage(),
          ),
        );

      case AppRoutes.resetPassword:
        return _buildRoute(settings, const ResetPasswordPage());

      case AppRoutes.forgotPassword:
        return _buildRoute(settings, const ForgotPasswordPage());

      case AppRoutes.home:
        return _buildRoute(
          settings,
          AuthWrapper(
            child: BlocProvider<HomeBloc>(
              initBloc: (context) =>
                  HomeBloc(ApiService(), const UnauthenticatedState()),
              child: const HomePage(),
            ),
          ),
        );

      case AppRoutes.profile:
        return _buildRoute(
          settings,
          AuthWrapper(
            child: BlocProvider<HomeBloc>(
              initBloc: (context) => BlocProvider.of<HomeBloc>(context),
              child: const ProfilePage(),
            ),
          ),
        );

      case AppRoutes.reportFlood:
        return _buildRoute(
          settings,
          const AuthWrapper(child: ReportFloodPage()),
        );

      case AppRoutes.dispatcherDashboard:
        return _buildRoute(
          settings,
          const AuthWrapper(child: DispatcherDashboard()),
        );

      case AppRoutes.operations:
        return _buildRoute(
          settings,
          const AuthWrapper(child: OperationsPage()),
        );
      case AppRoutes.rescuerHome:
        return _buildRoute(
          settings,
          const AuthWrapper(child: RescuerHomePage()),
        );

      case AppRoutes.reportDetails:
        final report = settings.arguments as ReportData?;
        return _buildRoute(
          settings,
          AuthWrapper(child: ReportDetailsPage(report: report)),
        );

      case AppRoutes.settings:
        return _buildRoute(settings, const AuthWrapper(child: SettingsPage()));

      case AppRoutes.changePassword:
        return _buildRoute(
          settings,
          const AuthWrapper(child: ChangePasswordPage()),
        );

      case AppRoutes.about:
        return _buildRoute(settings, const AboutPage());

      default:
        return _buildRoute(settings, const NotFoundPage());
    }
  }

  static MaterialPageRoute _buildRoute(RouteSettings settings, Widget page) {
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }
}

class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final isAuthenticated = await _checkSharedPreferencesAuth();

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkSharedPreferencesAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final token = prefs.getString(_keyAuthToken);
      final userId = prefs.getInt(_keyUserId);

      debugPrint('[AuthWrapper] SharedPreferences check:');
      debugPrint('  - isLoggedIn: $isLoggedIn');
      debugPrint('  - token: ${token != null ? 'present' : 'null'}');
      debugPrint('  - userId: $userId');

      return isLoggedIn && userId != null;
    } catch (e) {
      debugPrint('[AuthWrapper] Error checking SharedPreferences: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      });

      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final isAuthenticated = await _checkAuthStatus();
    final userRole = await _getUserRole();

    if (mounted) {
      if (isAuthenticated) {
        _navigateBasedOnRole(userRole);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  Future<bool> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final userId = prefs.getInt(_keyUserId);

      debugPrint(
        '[SplashPage] Auth check - isLoggedIn: $isLoggedIn, userId: $userId',
      );

      return isLoggedIn && userId != null;
    } catch (e) {
      debugPrint('[SplashPage] Error checking auth status: $e');
      return false;
    }
  }

  Future<String?> _getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserRole);
    } catch (e) {
      debugPrint('[SplashPage] Error getting user role: $e');
      return null;
    }
  }

  void _navigateBasedOnRole(String? userRole) {
    final role = userRole?.toLowerCase() ?? 'user';

    debugPrint('[SplashPage] Navigating based on role: $role');

    switch (role) {
      case 'dispatcher':
      case 'admin':
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.dispatcherDashboard);
        break;
      case 'rescuer':
        Navigator.of(context).pushReplacementNamed(AppRoutes.rescuerHome);
        break;
      case 'user':
      default:
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FlutterLogo(size: 100),
            const SizedBox(height: 20),
            const Text(
              'FDR App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: _getDebugInfo(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final info = snapshot.data!;
                  return Column(
                    children: [
                      Text(
                        'Checking authentication...',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        'User: ${info['userId'] ?? 'Not logged in'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'isLoggedIn': prefs.getBool(_keyIsLoggedIn) ?? false,
        'userId': prefs.getInt(_keyUserId),
        'userRole': prefs.getString(_keyUserRole),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Page Not Found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('The page you are looking for does not exist.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
              },
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationHelper {
  static void navigateToLogin(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  static void navigateToHome(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  static void navigateToProfile(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.profile);
  }

  static void navigateToReportFlood(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.reportFlood);
  }

  static void navigateToDispatcherDashboard(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.dispatcherDashboard);
  }

  static void navigateToRescuerHome(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.rescuerHome, (route) => false);
  }

  static void navigateToOperations(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.operations);
  }

  static void navigateToResetPassword(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.resetPassword);
  }

  static void navigateToForgotPassword(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
  }

  static void navigateToReportDetails(BuildContext context, ReportData report) {
    Navigator.of(context).pushNamed(AppRoutes.reportDetails, arguments: report);
  }


  static void navigateBack(BuildContext context) {
    Navigator.of(context).pop();
  }

  static Future<T?> navigateTo<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  static void navigateBasedOnRole(BuildContext context, String userRole) {
    switch (userRole.toLowerCase()) {
      case 'dispatcher':
        navigateToDispatcherDashboard(context);
        break;
      case 'admin':
        navigateToDispatcherDashboard(context);
        break;
      case 'rescuer':
        navigateToHome(context);
        break;
      default:
        navigateToHome(context);
    }
  }

  static Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final userId = prefs.getInt('user_id');
      return isLoggedIn && userId != null;
    } catch (e) {
      debugPrint('[NavigationHelper] Error checking login status: $e');
      return false;
    }
  }

  static Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_role');
    } catch (e) {
      debugPrint('[NavigationHelper] Error getting user role: $e');
      return null;
    }
  }
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: const Center(child: Text('Forgot Password Page')),
    );
  }
}

class ReportDetailsPage extends StatelessWidget {
  final ReportData? report;

  const ReportDetailsPage({super.key, this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: Center(
        child: Text('Report Details: ${report?.title ?? 'No report'}'),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings Page')),
    );
  }
}

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: const Center(child: Text('Change Password Page')),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Center(child: Text('About Page')),
    );
  }
}

extension RoleBasedAuth on AuthWrapper {
  static Future<bool> checkUserRole(String requiredRole) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');
      return userRole?.toLowerCase() == requiredRole.toLowerCase();
    } catch (e) {
      debugPrint('[RoleBasedAuth] Error checking role: $e');
      return false;
    }
  }
}

class RouteGuards {
  static Future<bool> isDispatcher(BuildContext context) async {
    return await RoleBasedAuth.checkUserRole('dispatcher');
  }

  static Future<bool> isAdmin(BuildContext context) async {
    return await RoleBasedAuth.checkUserRole('admin');
  }

  static Future<bool> isRescuer(BuildContext context) async {
    return await RoleBasedAuth.checkUserRole('rescuer');
  }

  static Future<bool> isUser(BuildContext context) async {
    return await RoleBasedAuth.checkUserRole('user');
  }

  static Future<bool> isAuthenticated() async {
    return await NavigationHelper.isUserLoggedIn();
  }
}
