// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:fdr/app_routes.dart';
import 'package:fdr/features/auth/register/register_bloc.dart';
import 'package:fdr/features/auth/register/register_event.dart';
import 'package:fdr/features/auth/register/register_state.dart';
import 'package:fdr/features/utils/snackbar.dart';
import 'package:fdr/features/widgets/password_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';

class RegisterPage extends StatefulWidget {
  static const routeName = '/register_page';

  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final nameFocusNode = FocusNode();
  final emailFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();

  late AnimationController registerButtonController;
  late Animation<double> buttonSqueezeAnimation;
  bool rememberMe = false;
  final bool isLoginTab = false;

  StreamSubscription<RegisterState>? _stateSubscription;

  @override
  void initState() {
    super.initState();

    registerButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    buttonSqueezeAnimation = Tween<double>(begin: 320, end: 70).animate(
      CurvedAnimation(
        parent: registerButtonController,
        curve: const Interval(0.0, 0.250),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToBloc();
  }

  void _subscribeToBloc() {
    final bloc = BlocProvider.of<RegisterBloc>(context);
    _stateSubscription?.cancel();
    _stateSubscription = bloc.state$.listen((state) {
      _handleRegisterState(state);
    });
  }

  void _handleRegisterState(RegisterState state) {
    if (state is RegisterLoading) {
      registerButtonController
        ..reset()
        ..forward();
    } else {
      registerButtonController.reverse();
    }

    if (state is RegisterSuccess) {
      context.showSnackBar('Registration successful!');
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        }
      });
    } else if (state is RegisterError) {
      context.showSnackBar(state.message);
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    registerButtonController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameFocusNode.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateName(String name) {
    if (name.isEmpty) return 'Name is required';
    if (name.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  void _onFormChanged() {
    final bloc = BlocProvider.of<RegisterBloc>(context);

    bloc.formChanged(
      RegisterFormChanged(
        name: nameController.text,
        email: emailController.text,
        password: passwordController.text,
      ),
    );
  }

  void _submitForm() {
    final bloc = BlocProvider.of<RegisterBloc>(context);

    bloc.submit(
      RegisterSubmitted(
        name: nameController.text,
        email: emailController.text,
        password: passwordController.text,
        role: "user",
        isRescuer: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWeb = size.width >= 900;

    return Scaffold(
      backgroundColor: isWeb ? Colors.grey.shade800 : Colors.white,
      body: SafeArea(
        child: isWeb ? _buildWebLayout(theme) : _buildMobileLayout(theme),
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
              // Welcome panel
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
                        'Join Flood Detection\n& Rescue',
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
                        'Create your account to access real-time flood detection alerts and emergency rescue services. Stay safe with our comprehensive monitoring system.',
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
              // Register form
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
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sign Up for Flood Detection & Rescue',
                          style: theme.textTheme.headlineSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildNameTextField(theme),
                        const SizedBox(height: 20),
                        _buildEmailTextField(theme),
                        const SizedBox(height: 20),
                        _buildPasswordTextField(theme),
                        const SizedBox(height: 20),
                        _buildTermsAndConditions(theme),
                        const SizedBox(height: 32),
                        _buildWebRegisterButton(theme),
                        const SizedBox(height: 32),
                        _buildHaveAnAccountLink(theme),
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
          _buildNameTextField(theme),
          const SizedBox(height: 16),
          _buildEmailTextField(theme),
          const SizedBox(height: 16),
          _buildPasswordTextField(theme),
          const SizedBox(height: 16),
          _buildTermsAndConditions(theme),
          const SizedBox(height: 32),
          _buildRegisterButton(theme),
          const SizedBox(height: 32),
          _buildHaveAnAccountLink(theme),
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
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
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
                  'Login',
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
                'Register',
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

  Widget _buildNameTextField(ThemeData theme) {
    return TextField(
      controller: nameController,
      focusNode: nameFocusNode,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      autofocus: true,
      onChanged: (_) => _onFormChanged(),
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(emailFocusNode);
      },
      decoration: InputDecoration(
        hintText: 'Full Name',
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
        errorText: _validateName(nameController.text),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: const TextStyle(fontSize: 16.0, color: Colors.black),
    );
  }

  Widget _buildEmailTextField(ThemeData theme) {
    return TextField(
      controller: emailController,
      focusNode: emailFocusNode,
      autocorrect: false,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onChanged: (_) => _onFormChanged(),
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(passwordFocusNode);
      },
      decoration: InputDecoration(
        hintText: 'Email Address',
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
        errorText: _validateEmail(emailController.text),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: const TextStyle(fontSize: 16.0, color: Colors.black),
    );
  }

  Widget _buildPasswordTextField(ThemeData theme) {
    return PasswordTextField(
      controller: passwordController,
      focusNode: passwordFocusNode,
      onChanged: (_) => _onFormChanged(),
      labelText: "Password",
      errorText: _validatePassword(passwordController.text),
      onSubmitted: _submitForm,
      textInputAction: TextInputAction.done,
      autofocus: false,
    );
  }

  Widget _buildWebRegisterButton(ThemeData theme) {
    final bloc = BlocProvider.of<RegisterBloc>(context);

    return StreamBuilder<RegisterState>(
      stream: bloc.state$,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isLoading = state is RegisterLoading;
        final isFormValid = state is RegisterFormValid;

        return SizedBox(
          height: 54.0,
          child: ElevatedButton(
            onPressed: (!isFormValid || isLoading) ? null : _submitForm,
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
                    'CREATE ACCOUNT',
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

  Widget _buildRegisterButton(ThemeData theme) {
    final bloc = BlocProvider.of<RegisterBloc>(context);

    return StreamBuilder<RegisterState>(
      stream: bloc.state$,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isLoading = state is RegisterLoading;
        final isFormValid = state is RegisterFormValid;

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
                      onPressed: (!isFormValid || isLoading)
                          ? null
                          : _submitForm,
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
                              'Sign Up',
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

  Widget _buildTermsAndConditions(ThemeData theme) {
    return Row(
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
              Text(
                'I agree to the',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Terms & Conditions',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHaveAnAccountLink(ThemeData theme) {
    return Center(
      child: Text.rich(
        TextSpan(
          text: "Already have an account? ",
          style: const TextStyle(color: Colors.black87, fontSize: 15.0),
          children: [
            WidgetSpan(
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    'SIGN IN HERE',
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
}
