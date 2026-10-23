import 'dart:async';
import 'package:fdr/app_routes.dart';
import 'package:fdr/features/auth/data/models/user_role.dart';
import 'package:fdr/features/auth/login/login_bloc.dart';
import 'package:fdr/features/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_disposebag/flutter_disposebag.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/login_page';

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController loginButtonController;
  late final Animation<double> buttonSqueezeAnimation;

  final passwordFocusNode = FocusNode();
  final emailController = TextEditingController();
  final textController = TextEditingController();
  final passwordController = TextEditingController();
  bool rememberMe = false;
  final bool isLoginTab = true;

  @override
  void initState() {
    super.initState();

    loginButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    buttonSqueezeAnimation = Tween(begin: 320.0, end: 70.0).animate(
      CurvedAnimation(
        parent: loginButtonController,
        curve: const Interval(0.0, 0.250),
      ),
    );
  }

  @override
  void dispose() {
    passwordFocusNode.dispose();
    loginButtonController.dispose();
    textController.dispose();
    passwordController.dispose();
    super.dispose();
  }

void _handleLoginState(BuildContext context, LoginState state) {
  // Handle loading state
  if (state is LoginLoading) {
    loginButtonController
      ..reset()
      ..forward();
  } else {
    loginButtonController.reverse();
  }

  // Use WidgetsBinding to ensure we're in a valid frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    if (state is LoginSuccess) {
      _showSafeSnackBar(
        context,
        'Login successful!',
        duration: const Duration(milliseconds: 800),
        backgroundColor: Colors.green.shade600,
      );
      
      // Use a slightly longer delay to ensure snackbar is visible
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _navigateBasedOnRole(state.userRole);
        }
      });
    } else if (state is LoginError) {
      _showSafeSnackBar(
        context,
        state.message,
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 4),
      );
    }
  });
}

void _showSafeSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
  Color? backgroundColor,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (scaffoldMessenger.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: duration,
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to show snackbar: $e');
    }
  });
}

  void _navigateBasedOnRole(UserRole userRole) {
    if (!mounted) return;
    
    switch (userRole) {
      case UserRole.dispatcher:
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dispatcherDashboard,
          (route) => false,
        );
        break;
      case UserRole.rescuer:
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.rescuerHome,
          (route) => false,
        );
        break;
      case UserRole.user:
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
        break;
      case UserRole.unknown:
        throw UnimplementedError();
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWeb = size.width >= 900;

    return BlocListener<LoginBloc, LoginState>(
      listener: _handleLoginState,
      child: Scaffold(
        backgroundColor: isWeb ? Colors.grey.shade800 : Colors.white,
        body: SafeArea(
          child: isWeb ? _buildWebLayout(theme) : _buildMobileLayout(theme),
        ),
      ),
    );
  }

  Widget _buildWebLayout(ThemeData theme) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 700),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Welcome back panel
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flood Detection\n& Rescue',
                        style: theme.textTheme.headlineLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 48,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 80),
                      Text(
                        'For your Safety...',
                        style: theme.textTheme.headlineMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 60),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Login form
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 40,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'WELCOME BACK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Log in to your Account',
                          style: theme.textTheme.headlineSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildEmailTextField(theme),
                        const SizedBox(height: 20),
                        _buildPasswordTextField(theme),
                        const SizedBox(height: 20),
                        _buildLoginOptionsRow(theme),
                        const SizedBox(height: 32),
                        _buildWebLoginButton(theme),
                        const SizedBox(height: 32),
                        _buildNeedAnAccountLink(theme),
                      ],
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

  Widget _buildMobileLayout(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 64),
          _buildLogo(theme),
          const SizedBox(height: 48),
          _buildAuthToggle(context, theme),
          const SizedBox(height: 32),
          _buildEmailTextField(theme),
          const SizedBox(height: 16),
          _buildPasswordTextField(theme),
          const SizedBox(height: 16),
          _buildLoginOptionsRow(theme),
          const SizedBox(height: 32),
          _buildLoginButton(theme),
          const SizedBox(height: 32),
          _buildNeedAnAccountLink(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'FD',
              style: theme.textTheme.headlineLarge!.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black,
                fontSize: 48,
              ),
            ),
            TextSpan(
              text: 'R',
              style: theme.textTheme.headlineLarge!.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                fontSize: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthToggle(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.register);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !isLoginTab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isLoginTab
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Register',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: !isLoginTab
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isLoginTab ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isLoginTab
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isLoginTab ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTextField(ThemeData theme) {
    return TextField(
      controller: textController,
      autocorrect: false,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofocus: true,
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(passwordFocusNode);
      },
      decoration: InputDecoration(
        hintText: 'Email',
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: const TextStyle(fontSize: 16.0, color: Colors.black),
    );
  }

  Widget _buildPasswordTextField(ThemeData theme) {
    return TextField(
      controller: passwordController,
      focusNode: passwordFocusNode,
      obscureText: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
        _submitLogin();
      },
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        suffixIcon: Icon(
          Icons.visibility_off_outlined,
          color: Colors.grey.shade400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: const TextStyle(fontSize: 16.0, color: Colors.black),
    );
  }

  Widget _buildWebLoginButton(ThemeData theme) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        final isLoading = state is LoginLoading;

        return SizedBox(
          height: 54.0,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submitLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              disabledBackgroundColor: theme.colorScheme.primary.withOpacity(
                0.6,
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoginButton(ThemeData theme) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        final isLoading = state is LoginLoading;

        return AnimatedBuilder(
          animation: buttonSqueezeAnimation,
          builder: (context, child) {
            final value = buttonSqueezeAnimation.value;

            return SizedBox(
              width: value,
              height: 54.0,
              child: isLoading && value <= 75.0
                  ? Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: isLoading ? null : _submitLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoginOptionsRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              rememberMe = !rememberMe;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: rememberMe,
                  onChanged: (value) {
                    setState(() {
                      rememberMe = value ?? false;
                    });
                  },
                  activeColor: theme.colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Remember me',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(AppRoutes.resetPassword);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeedAnAccountLink(ThemeData theme) {
    return Center(
      child: Text.rich(
        TextSpan(
          text: "New User? ",
          style: const TextStyle(color: Colors.black87, fontSize: 15.0),
          children: [
            WidgetSpan(
              child: InkWell(
                onTap: () {
                  Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.register);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    'SIGN UP HERE',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitLogin() {
    FocusScope.of(context).unfocus();

    final name = textController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || password.isEmpty) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    context.read<LoginBloc>().add(
      LoginSubmitted(name: name, password: password),
    );
  }
}
